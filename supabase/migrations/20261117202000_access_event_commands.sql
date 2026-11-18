create table if not exists public.invitations(
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  email text not null,
  role text not null check(role in('access_admin','manager','operator','purchasing','finance','auditor')),
  token_hash text not null,
  expires_at timestamptz not null,
  invited_by uuid not null references auth.users(id),
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  unique(tenant_id,token_hash)
);
alter table public.invitations enable row level security;
create index if not exists idx_invitations_tenant on public.invitations(tenant_id,created_at desc);
drop policy if exists tenant_select on public.invitations;
create policy tenant_select on public.invitations for select to authenticated using(private.is_member(tenant_id));
grant select on public.invitations to authenticated;

create or replace function public.create_invitation(p_email text,p_role text,p_expires_at timestamptz default now()+interval '7 days') returns jsonb language plpgsql security definer set search_path=public,pgcrypto,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_token text; v_id uuid;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','access_admin') limit 1;
 if v_tenant is null then raise exception 'access_admin_required'; end if;
 if p_expires_at<=now() then raise exception 'expiration_must_be_future'; end if;
 if p_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'invalid_email'; end if;
 v_token:=encode(gen_random_bytes(24),'hex');
 insert into invitations(tenant_id,email,role,token_hash,expires_at,invited_by) values(v_tenant,lower(trim(p_email)),p_role,encode(digest(v_token,'sha256'),'hex'),p_expires_at,v_uid) returning id into v_id;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'access.invite','invitation',v_id,jsonb_build_object('email',lower(trim(p_email)),'role',p_role,'expires_at',p_expires_at));
 return jsonb_build_object('id',v_id,'token',v_token,'expires_at',p_expires_at);
end; $$;

create or replace function public.revoke_invitation(p_invitation_id uuid) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_changed boolean; v_count integer;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','access_admin') limit 1;
 if v_tenant is null then raise exception 'access_admin_required'; end if;
 update invitations set revoked_at=now() where id=p_invitation_id and tenant_id=v_tenant and revoked_at is null and accepted_at is null;
 get diagnostics v_count = row_count; v_changed := v_count > 0;
 if v_changed then insert into audit_events(tenant_id,actor_id,action,entity,entity_id) values(v_tenant,v_uid,'access.revoke_invitation','invitation',p_invitation_id); end if;
 return v_changed;
end; $$;

create or replace function public.reserve_event_material(p_event_id uuid,p_item_id uuid,p_location_id uuid,p_quantity numeric,p_lot_id uuid default null) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_lot uuid; v_available numeric; v_res uuid; v_alloc numeric:=p_quantity;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if p_quantity is null or p_quantity<=0 then raise exception 'quantity_must_be_positive'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' limit 1;
 if v_tenant is null then raise exception 'membership_required'; end if;
 if not exists(select 1 from events where id=p_event_id and tenant_id=v_tenant and status in('planned','separating')) then raise exception 'event_not_reservable'; end if;
 if p_lot_id is null then
   select sp.lot_id into v_lot from stock_positions sp join lots l on l.tenant_id=sp.tenant_id and l.id=sp.lot_id where sp.tenant_id=v_tenant and sp.item_id=p_item_id and sp.location_id=p_location_id and sp.condition='usable' and l.condition='usable' and (l.expires_on is null or l.expires_on>=current_date) and sp.on_hand_q-sp.reserved_q>=p_quantity order by l.expires_on nulls last,sp.id limit 1 for update;
 else
   select lot_id into v_lot from stock_positions where tenant_id=v_tenant and item_id=p_item_id and location_id=p_location_id and lot_id=p_lot_id and condition='usable' and on_hand_q-reserved_q>=p_quantity for update;
 end if;
 if v_lot is null then raise exception 'insufficient_reservable_stock'; end if;
 update stock_positions set reserved_q=reserved_q+p_quantity,updated_at=now() where tenant_id=v_tenant and item_id=p_item_id and location_id=p_location_id and lot_id=v_lot and condition='usable' and on_hand_q-reserved_q>=p_quantity;
 if not found then raise exception 'reservation_conflict'; end if;
 insert into reservations(tenant_id,event_id,item_id,location_id,quantity,status) values(v_tenant,p_event_id,p_item_id,p_location_id,p_quantity,'firm') returning id into v_res;
 insert into reservation_allocations(tenant_id,reservation_id,lot_id,quantity) values(v_tenant,v_res,v_lot,p_quantity);
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.reserve','reservation',v_res,jsonb_build_object('event_id',p_event_id,'lot_id',v_lot,'quantity',p_quantity));
 return v_res;
end; $$;

create or replace function public.release_event_reservation(p_reservation_id uuid) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_item uuid; v_location uuid; v_changed boolean; v_count integer;
begin
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' limit 1;
 if v_tenant is null then raise exception 'membership_required'; end if;
 select item_id,location_id into v_item,v_location from reservations where id=p_reservation_id and tenant_id=v_tenant and status='firm';
 if v_item is null then return false; end if;
 update stock_positions sp set reserved_q=sp.reserved_q-a.quantity,updated_at=now() from reservation_allocations a where a.tenant_id=v_tenant and a.reservation_id=p_reservation_id and sp.tenant_id=a.tenant_id and sp.lot_id=a.lot_id and sp.item_id=v_item and sp.location_id=v_location and sp.condition='usable';
 update reservations set status='released' where id=p_reservation_id and tenant_id=v_tenant and status='firm';
 get diagnostics v_count = row_count; v_changed := v_count > 0;
 if v_changed then insert into audit_events(tenant_id,actor_id,action,entity,entity_id) values(v_tenant,v_uid,'event.release_reservation','reservation',p_reservation_id); end if;
 return v_changed;
end; $$;

create or replace function public.close_event(p_event_id uuid,p_reason text) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_open numeric; v_changed boolean; v_count integer;
begin
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager') limit 1;
 if v_tenant is null then raise exception 'manager_required'; end if;
 select count(*) into v_open from reservations where tenant_id=v_tenant and event_id=p_event_id and status in('firm','draft');
 if v_open>0 then raise exception 'open_reservations_block_close'; end if;
 update events set status='closed' where tenant_id=v_tenant and id=p_event_id and status in('settling','operating');
 get diagnostics v_count = row_count; v_changed := v_count > 0;
 if not v_changed then raise exception 'event_not_closable'; end if;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.close','event',p_event_id,jsonb_build_object('reason',p_reason));
 return true;
end; $$;

revoke all on function public.create_invitation(text,text,timestamptz) from public,anon; grant execute on function public.create_invitation(text,text,timestamptz) to authenticated;
revoke all on function public.revoke_invitation(uuid) from public,anon; grant execute on function public.revoke_invitation(uuid) to authenticated;
revoke all on function public.reserve_event_material(uuid,uuid,uuid,numeric,uuid) from public,anon; grant execute on function public.reserve_event_material(uuid,uuid,uuid,numeric,uuid) to authenticated;
revoke all on function public.release_event_reservation(uuid) from public,anon; grant execute on function public.release_event_reservation(uuid) to authenticated;
revoke all on function public.close_event(uuid,text) from public,anon; grant execute on function public.close_event(uuid,text) to authenticated;
