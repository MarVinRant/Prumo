create or replace function public.create_event(p_name text,p_code text,p_venue text,p_starts_at timestamptz,p_ends_at timestamptz) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_id uuid;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' limit 1;
 if v_tenant is null then raise exception 'membership_required'; end if;
 insert into events(tenant_id,name,code,venue,starts_at,ends_at,created_by) values(v_tenant,trim(p_name),trim(p_code),nullif(trim(p_venue),''),p_starts_at,p_ends_at,v_uid) returning id into v_id;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'event.create','event',v_id,jsonb_build_object('code',p_code));
 return v_id;
end; $$;

create or replace function public.create_purchase_request(p_item_id uuid,p_location_id uuid,p_quantity numeric,p_needed_by date,p_reason text) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_id uuid;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if p_quantity is null or p_quantity<=0 then raise exception 'quantity_must_be_positive'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' limit 1;
 if v_tenant is null then raise exception 'membership_required'; end if;
 if not exists(select 1 from items where tenant_id=v_tenant and id=p_item_id and status='active') then raise exception 'item_not_found'; end if;
 if not exists(select 1 from locations where tenant_id=v_tenant and id=p_location_id and status='active') then raise exception 'location_not_found'; end if;
 insert into purchase_requests(tenant_id,requested_by,needed_by,reason) values(v_tenant,v_uid,p_needed_by,nullif(trim(p_reason),'')) returning id into v_id;
 insert into purchase_request_lines(tenant_id,request_id,item_id,location_id,quantity) values(v_tenant,v_id,p_item_id,p_location_id,p_quantity);
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'purchase.request','purchase_request',v_id,jsonb_build_object('quantity',p_quantity,'item_id',p_item_id));
 return v_id;
end; $$;

revoke all on function public.create_event(text,text,text,timestamptz,timestamptz) from public,anon;
grant execute on function public.create_event(text,text,text,timestamptz,timestamptz) to authenticated;
revoke all on function public.create_purchase_request(uuid,uuid,numeric,date,text) from public,anon;
grant execute on function public.create_purchase_request(uuid,uuid,numeric,date,text) to authenticated;
