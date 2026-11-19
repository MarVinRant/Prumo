-- Edição de catálogo com campos imutáveis depois do primeiro uso físico.
create or replace function public.update_item(
  p_item_id uuid,
  p_sku text,
  p_name text,
  p_family text,
  p_nature text,
  p_base_uom text,
  p_category_name text default null
) returns uuid
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare
  v_uid uuid:=auth.uid(); v_tenant uuid; v_old record; v_category uuid; v_id uuid;
  v_used boolean:=false;
begin
  perform private.require_aal2();
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select m.tenant_id into v_tenant
    from memberships m
   where m.user_id=v_uid and m.status='active'
     and m.role in('owner','manager','purchasing')
     and (m.expires_at is null or m.expires_at>now())
   order by m.created_at limit 1;
  if v_tenant is null then raise exception 'catalog_admin_required'; end if;
  select * into v_old from items where tenant_id=v_tenant and id=p_item_id for update;
  if v_old.id is null then raise exception 'item_not_found'; end if;
  if nullif(trim(p_sku),'') is null or nullif(trim(p_name),'') is null then raise exception 'item_fields_required'; end if;
  if p_family not in('bebida','alimento','insumo','descartavel','equipamento','utensilio','evento','apoio') then raise exception 'invalid_item_family'; end if;
  if p_nature not in('consumable','returnable','asset','service') then raise exception 'invalid_item_nature'; end if;
  if p_base_uom not in('g','ml','un','m') then raise exception 'invalid_base_uom'; end if;
  if exists(select 1 from items where tenant_id=v_tenant and sku=upper(trim(p_sku)) and id<>p_item_id) then raise exception 'sku_already_exists'; end if;
  v_used:=exists(select 1 from stock_positions where tenant_id=v_tenant and item_id=p_item_id)
       or exists(select 1 from stock_document_lines where tenant_id=v_tenant and item_id=p_item_id)
       or exists(select 1 from assets where tenant_id=v_tenant and item_id=p_item_id);
  if v_used and p_base_uom<>v_old.base_uom then raise exception 'base_uom_locked_after_use'; end if;
  if v_used and p_nature<>v_old.nature then raise exception 'nature_locked_after_use'; end if;
  if nullif(trim(p_category_name),'') is not null then
    insert into categories(tenant_id,name,family) values(v_tenant,trim(p_category_name),p_family)
      on conflict(tenant_id,name) do update set family=excluded.family returning id into v_category;
  else
    v_category:=v_old.category_id;
  end if;
  update items set sku=upper(trim(p_sku)),name=trim(p_name),family=p_family,nature=p_nature,base_uom=p_base_uom,category_id=v_category
   where tenant_id=v_tenant and id=p_item_id returning id into v_id;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload)
    values(v_tenant,v_uid,'catalog.item.update','item',v_id,jsonb_build_object('sku',upper(trim(p_sku)),'family',p_family,'nature',p_nature,'base_uom',p_base_uom));
  return v_id;
end; $$;

revoke all on function public.update_item(uuid,text,text,text,text,text,text) from public,anon;
grant execute on function public.update_item(uuid,text,text,text,text,text,text) to authenticated;
