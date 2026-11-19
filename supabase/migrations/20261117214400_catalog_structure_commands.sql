create or replace function public.create_unit(p_name text,p_code text) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager') limit 1;
  if v_tenant is null then raise exception 'structure_admin_required'; end if;
  if nullif(trim(p_name),'') is null or nullif(trim(p_code),'') is null then raise exception 'unit_fields_required'; end if;
  insert into units(tenant_id,name,code) values(v_tenant,trim(p_name),upper(trim(p_code))) returning id into v_id;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'structure.unit.create','unit',v_id,jsonb_build_object('code',upper(trim(p_code))));
  return v_id;
end; $$;

create or replace function public.create_location(p_unit_id uuid,p_name text,p_type text default 'warehouse',p_is_stockable boolean default true) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager') limit 1;
  if v_tenant is null then raise exception 'structure_admin_required'; end if;
  if nullif(trim(p_name),'') is null then raise exception 'location_name_required'; end if;
  if not exists(select 1 from units where tenant_id=v_tenant and id=p_unit_id and status='active') then raise exception 'unit_not_found'; end if;
  if p_type not in('warehouse','bar','kitchen','event','vehicle','quarantine','other') then raise exception 'invalid_location_type'; end if;
  insert into locations(tenant_id,unit_id,name,type,is_stockable) values(v_tenant,p_unit_id,trim(p_name),p_type,p_is_stockable) returning id into v_id;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'structure.location.create','location',v_id,jsonb_build_object('type',p_type,'is_stockable',p_is_stockable));
  return v_id;
end; $$;

create or replace function public.create_item(p_sku text,p_name text,p_family text,p_nature text,p_base_uom text,p_category_name text default null) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_category uuid; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager','purchasing') limit 1;
  if v_tenant is null then raise exception 'catalog_admin_required'; end if;
  if nullif(trim(p_sku),'') is null or nullif(trim(p_name),'') is null then raise exception 'item_fields_required'; end if;
  if p_family not in('bebida','alimento','insumo','descartavel','equipamento','utensilio','evento','apoio') then raise exception 'invalid_item_family'; end if;
  if p_nature not in('consumable','returnable','asset','service') then raise exception 'invalid_item_nature'; end if;
  if p_base_uom not in('g','ml','un','m') then raise exception 'invalid_base_uom'; end if;
  if nullif(trim(p_category_name),'') is not null then
    insert into categories(tenant_id,name,family) values(v_tenant,trim(p_category_name),p_family) on conflict(tenant_id,name) do update set family=excluded.family returning id into v_category;
  end if;
  insert into items(tenant_id,category_id,sku,name,nature,family,base_uom) values(v_tenant,v_category,upper(trim(p_sku)),trim(p_name),p_nature,p_family,p_base_uom) returning id into v_id;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'catalog.item.create','item',v_id,jsonb_build_object('sku',upper(trim(p_sku)),'base_uom',p_base_uom));
  return v_id;
end; $$;

create or replace function public.create_item_package(p_item_id uuid,p_name text,p_factor numeric,p_barcode text default null) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_factor is null or p_factor<=0 then raise exception 'package_factor_positive'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager','purchasing') limit 1;
  if v_tenant is null then raise exception 'catalog_admin_required'; end if;
  if not exists(select 1 from items where tenant_id=v_tenant and id=p_item_id and status='active') then raise exception 'item_not_found'; end if;
  insert into item_packages(tenant_id,item_id,name,factor,barcode) values(v_tenant,p_item_id,trim(p_name),p_factor,nullif(trim(p_barcode),'')) returning id into v_id;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'catalog.package.create','item_package',v_id,jsonb_build_object('item_id',p_item_id,'factor',p_factor));
  return v_id;
end; $$;

create or replace function public.upsert_item_location_policy(p_item_id uuid,p_location_id uuid,p_min_q numeric,p_reorder_q numeric,p_max_q numeric) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager') limit 1;
  if v_tenant is null then raise exception 'policy_admin_required'; end if;
  if p_min_q is null or p_reorder_q is null or p_max_q is null or p_min_q<0 or p_min_q>p_reorder_q or p_reorder_q>p_max_q then raise exception 'invalid_replenishment_policy'; end if;
  if not exists(select 1 from items where tenant_id=v_tenant and id=p_item_id and status='active') then raise exception 'item_not_found'; end if;
  if not exists(select 1 from locations where tenant_id=v_tenant and id=p_location_id and status='active' and is_stockable) then raise exception 'stockable_location_required'; end if;
  insert into item_location_policies(tenant_id,item_id,location_id,min_q,reorder_q,max_q) values(v_tenant,p_item_id,p_location_id,p_min_q,p_reorder_q,p_max_q)
    on conflict(tenant_id,item_id,location_id) do update set min_q=excluded.min_q,reorder_q=excluded.reorder_q,max_q=excluded.max_q returning id into v_id;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'catalog.policy.upsert','item_location_policy',v_id,jsonb_build_object('item_id',p_item_id,'location_id',p_location_id));
  return v_id;
end; $$;

create or replace function public.create_supplier(p_name text,p_tax_id text default null,p_email text default null,p_phone text default null) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager','purchasing') limit 1;
  if v_tenant is null then raise exception 'purchasing_required'; end if;
  if nullif(trim(p_name),'') is null then raise exception 'supplier_name_required'; end if;
  insert into suppliers(tenant_id,name,tax_id,email,phone) values(v_tenant,trim(p_name),nullif(trim(p_tax_id),''),nullif(trim(p_email),''),nullif(trim(p_phone),'')) returning id into v_id;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'catalog.supplier.create','supplier',v_id,jsonb_build_object('name',trim(p_name)));
  return v_id;
end; $$;

create or replace function public.link_supplier_item(p_supplier_id uuid,p_item_id uuid,p_lead_time_days integer default 0,p_supplier_sku text default null,p_last_unit_cost numeric default null) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_id uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager','purchasing') limit 1;
  if v_tenant is null then raise exception 'purchasing_required'; end if;
  if p_lead_time_days is null or p_lead_time_days<0 or (p_last_unit_cost is not null and p_last_unit_cost<0) then raise exception 'supplier_item_values_invalid'; end if;
  if not exists(select 1 from suppliers where tenant_id=v_tenant and id=p_supplier_id and status='active') then raise exception 'supplier_not_found'; end if;
  if not exists(select 1 from items where tenant_id=v_tenant and id=p_item_id and status='active') then raise exception 'item_not_found'; end if;
  insert into supplier_items(tenant_id,supplier_id,item_id,supplier_sku,lead_time_days,last_unit_cost) values(v_tenant,p_supplier_id,p_item_id,nullif(trim(p_supplier_sku),''),p_lead_time_days,p_last_unit_cost)
    on conflict(tenant_id,supplier_id,item_id) do update set supplier_sku=excluded.supplier_sku,lead_time_days=excluded.lead_time_days,last_unit_cost=excluded.last_unit_cost returning id into v_id;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'catalog.supplier_item.upsert','supplier_item',v_id,jsonb_build_object('supplier_id',p_supplier_id,'item_id',p_item_id));
  return v_id;
end; $$;

revoke all on function public.create_unit(text,text),public.create_location(uuid,text,text,boolean),public.create_item(text,text,text,text,text,text),public.create_item_package(uuid,text,numeric,text),public.upsert_item_location_policy(uuid,uuid,numeric,numeric,numeric),public.create_supplier(text,text,text,text),public.link_supplier_item(uuid,uuid,integer,text,numeric) from public,anon;
grant execute on function public.create_unit(text,text),public.create_location(uuid,text,text,boolean),public.create_item(text,text,text,text,text,text),public.create_item_package(uuid,text,numeric,text),public.upsert_item_location_policy(uuid,uuid,numeric,numeric,numeric),public.create_supplier(text,text,text,text),public.link_supplier_item(uuid,uuid,integer,text,numeric) to authenticated;
