create or replace function public.set_unit_status(p_unit_id uuid,p_status text) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_old text;
begin
 perform private.require_aal2();
 if p_status not in('active','inactive') then raise exception 'invalid_status'; end if;
 select m.tenant_id into v_tenant from memberships m where m.user_id=v_uid and m.status='active' and m.role in('owner','manager') and (m.expires_at is null or m.expires_at>now()) order by m.created_at limit 1;
 if v_tenant is null then raise exception 'structure_admin_required'; end if;
 select status into v_old from units where tenant_id=v_tenant and id=p_unit_id for update;
 if v_old is null then raise exception 'unit_not_found'; end if;
 if p_status='inactive' and exists(select 1 from locations where tenant_id=v_tenant and unit_id=p_unit_id and status='active') then raise exception 'unit_has_active_locations'; end if;
 update units set status=p_status where tenant_id=v_tenant and id=p_unit_id;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'structure.unit.status','unit',p_unit_id,jsonb_build_object('from',v_old,'to',p_status));
 return true;
end; $$;

create or replace function public.set_location_status(p_location_id uuid,p_status text) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_old text;
begin
 perform private.require_aal2();
 if p_status not in('active','inactive') then raise exception 'invalid_status'; end if;
 select m.tenant_id into v_tenant from memberships m where m.user_id=v_uid and m.status='active' and m.role in('owner','manager') and (m.expires_at is null or m.expires_at>now()) order by m.created_at limit 1;
 if v_tenant is null then raise exception 'structure_admin_required'; end if;
 select status into v_old from locations where tenant_id=v_tenant and id=p_location_id for update;
 if v_old is null then raise exception 'location_not_found'; end if;
 if p_status='inactive' and exists(select 1 from stock_positions where tenant_id=v_tenant and location_id=p_location_id and (on_hand_q>0 or reserved_q>0)) then raise exception 'location_has_stock'; end if;
 if p_status='inactive' and exists(select 1 from reservations where tenant_id=v_tenant and location_id=p_location_id and status='firm') then raise exception 'location_has_reservations'; end if;
 if p_status='inactive' and exists(select 1 from asset_custodies where tenant_id=v_tenant and location_id=p_location_id and closed_at is null) then raise exception 'location_has_open_custody'; end if;
 update locations set status=p_status where tenant_id=v_tenant and id=p_location_id;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'structure.location.status','location',p_location_id,jsonb_build_object('from',v_old,'to',p_status));
 return true;
end; $$;

create or replace function public.set_item_status(p_item_id uuid,p_status text) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_old text;
begin
 perform private.require_aal2();
 if p_status not in('active','inactive') then raise exception 'invalid_status'; end if;
 select m.tenant_id into v_tenant from memberships m where m.user_id=v_uid and m.status='active' and m.role in('owner','manager','purchasing') and (m.expires_at is null or m.expires_at>now()) order by m.created_at limit 1;
 if v_tenant is null then raise exception 'catalog_admin_required'; end if;
 select status into v_old from items where tenant_id=v_tenant and id=p_item_id for update;
 if v_old is null then raise exception 'item_not_found'; end if;
 if p_status='inactive' and exists(select 1 from stock_positions where tenant_id=v_tenant and item_id=p_item_id and (on_hand_q>0 or reserved_q>0)) then raise exception 'item_has_stock'; end if;
 if p_status='inactive' and exists(select 1 from reservations where tenant_id=v_tenant and item_id=p_item_id and status='firm') then raise exception 'item_has_reservations'; end if;
 update items set status=p_status where tenant_id=v_tenant and id=p_item_id;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'catalog.item.status','item',p_item_id,jsonb_build_object('from',v_old,'to',p_status));
 return true;
end; $$;

create or replace function public.set_supplier_status(p_supplier_id uuid,p_status text) returns boolean
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_old text;
begin
 perform private.require_aal2();
 if p_status not in('active','inactive') then raise exception 'invalid_status'; end if;
 select m.tenant_id into v_tenant from memberships m where m.user_id=v_uid and m.status='active' and m.role in('owner','manager','purchasing') and (m.expires_at is null or m.expires_at>now()) order by m.created_at limit 1;
 if v_tenant is null then raise exception 'purchasing_required'; end if;
 select status into v_old from suppliers where tenant_id=v_tenant and id=p_supplier_id for update;
 if v_old is null then raise exception 'supplier_not_found'; end if;
 if p_status='inactive' and exists(select 1 from purchase_orders where tenant_id=v_tenant and supplier_id=p_supplier_id and status in('draft','sent','partial')) then raise exception 'supplier_has_open_orders'; end if;
 update suppliers set status=p_status where tenant_id=v_tenant and id=p_supplier_id;
 insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'catalog.supplier.status','supplier',p_supplier_id,jsonb_build_object('from',v_old,'to',p_status));
 return true;
end; $$;

revoke all on function public.set_unit_status(uuid,text),public.set_location_status(uuid,text),public.set_item_status(uuid,text),public.set_supplier_status(uuid,text) from public,anon;
grant execute on function public.set_unit_status(uuid,text),public.set_location_status(uuid,text),public.set_item_status(uuid,text),public.set_supplier_status(uuid,text) to authenticated;
