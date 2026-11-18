create table if not exists public.stock_counts(
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.organizations(id) on delete cascade,
  item_id uuid not null,
  location_id uuid not null,
  lot_id uuid not null,
  expected_q numeric(20,6) not null check(expected_q>=0),
  counted_q numeric(20,6) not null check(counted_q>=0),
  status text not null default 'pending' check(status in('pending','approved','rejected')),
  reason text,
  created_by uuid not null references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  unique(tenant_id,id),
  foreign key(tenant_id,item_id) references public.items(tenant_id,id),
  foreign key(tenant_id,location_id) references public.locations(tenant_id,id),
  foreign key(tenant_id,lot_id) references public.lots(tenant_id,id)
);
alter table public.stock_counts enable row level security;
drop policy if exists tenant_select on public.stock_counts;
create policy tenant_select on public.stock_counts for select to authenticated using(private.is_member(tenant_id));
grant select on public.stock_counts to authenticated;

create or replace function public.record_stock_count(p_item_id uuid,p_location_id uuid,p_lot_id uuid,p_counted_q numeric,p_reason text default null) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_expected numeric; v_id uuid;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 if p_counted_q is null or p_counted_q<0 then raise exception 'count_must_be_nonnegative'; end if;
 select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' limit 1;
 if v_tenant is null then raise exception 'membership_required'; end if;
 select on_hand_q into v_expected from stock_positions where tenant_id=v_tenant and item_id=p_item_id and location_id=p_location_id and lot_id=p_lot_id and condition='usable' for update;
 if v_expected is null then raise exception 'stock_position_not_found'; end if;
 insert into stock_counts(tenant_id,item_id,location_id,lot_id,expected_q,counted_q,reason,created_by) values(v_tenant,p_item_id,p_location_id,p_lot_id,v_expected,p_counted_q,nullif(trim(p_reason),''),v_uid) returning id into v_id;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'stock.count.record','stock_count',v_id,jsonb_build_object('item_id',p_item_id,'location_id',p_location_id,'lot_id',p_lot_id,'counted_q',p_counted_q));
 return v_id;
end; $$;

create or replace function public.approve_stock_count(p_count_id uuid) returns jsonb language plpgsql security definer set search_path=public,finance,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_item uuid; v_location uuid; v_lot uuid; v_expected numeric; v_counted numeric; v_delta numeric; v_current numeric; v_reserved numeric; v_pos uuid; v_doc uuid; v_line uuid; v_no text; v_uom text; v_count_status text;
begin
 if v_uid is null then raise exception 'not_authenticated'; end if;
 select tenant_id,item_id,location_id,lot_id,expected_q,counted_q,status into v_tenant,v_item,v_location,v_lot,v_expected,v_counted,v_count_status from stock_counts where id=p_count_id for update;
 if v_tenant is null then raise exception 'count_not_found'; end if;
 if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager')) then raise exception 'count_approval_required'; end if;
 if v_count_status<>'pending' then return jsonb_build_object('status',v_count_status); end if;
 select base_uom into v_uom from items where tenant_id=v_tenant and id=v_item and status='active';
 select id,on_hand_q,reserved_q into v_pos,v_current,v_reserved from stock_positions where tenant_id=v_tenant and item_id=v_item and location_id=v_location and lot_id=v_lot and condition='usable' for update;
 if v_pos is null then raise exception 'stock_position_not_found'; end if;
 if v_current<>v_expected then raise exception 'count_conflict'; end if;
 v_delta:=v_counted-v_expected;
 if v_delta=0 then update stock_counts set status='approved',approved_by=v_uid,approved_at=now() where id=p_count_id; insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'stock.count.approve','stock_count',p_count_id,jsonb_build_object('delta',0)); return jsonb_build_object('status','approved','delta',0); end if;
 if v_delta<0 and v_current-v_reserved<abs(v_delta) then raise exception 'count_below_reserved_stock'; end if;
 v_no:='CNT-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6);
 insert into stock_documents(tenant_id,document_no,type,reason,idempotency_key,actor_id) values(v_tenant,v_no,'adjustment','Ajuste de contagem '||p_count_id,'count:'||p_count_id::text,v_uid) returning id into v_doc;
 insert into stock_document_lines(tenant_id,document_id,item_id,location_id,lot_id,quantity,input_uom,signed_quantity) values(v_tenant,v_doc,v_item,v_location,v_lot,abs(v_delta),v_uom,v_delta) returning id into v_line;
 update stock_positions set on_hand_q=on_hand_q+v_delta,updated_at=now() where id=v_pos;
 insert into stock_entries(tenant_id,document_id,document_line_id,item_id,location_id,lot_id,quantity,direction) values(v_tenant,v_doc,v_line,v_item,v_location,v_lot,abs(v_delta),case when v_delta>0 then 'in' else 'out' end);
 update stock_counts set status='approved',approved_by=v_uid,approved_at=now() where id=p_count_id;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'stock.count.approve','stock_count',p_count_id,jsonb_build_object('delta',v_delta,'document_id',v_doc));
 return jsonb_build_object('status','approved','delta',v_delta,'document_id',v_doc,'document_no',v_no);
end; $$;

revoke all on function public.record_stock_count(uuid,uuid,uuid,numeric,text),public.approve_stock_count(uuid) from public,anon;
grant execute on function public.record_stock_count(uuid,uuid,uuid,numeric,text),public.approve_stock_count(uuid) to authenticated;
