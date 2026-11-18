create or replace function public.seed_demo_data() returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_uid uuid:=auth.uid(); v_tenant uuid; v_unit uuid; v_bar uuid; v_wh uuid; v_cat uuid; v_item uuid; v_lot uuid; v_expired uuid; v_supplier uuid; r record;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select tenant_id into v_tenant from memberships where user_id=v_uid and status='active' and role in('owner','manager') limit 1;
  if v_tenant is null then raise exception 'fixture_seed_requires_manager'; end if;
  select id into v_unit from units where tenant_id=v_tenant and code='U01' limit 1;
  if v_unit is null then insert into units(tenant_id,name,code) values(v_tenant,'Unidade principal','U01') returning id into v_unit; end if;
  select id into v_bar from locations where tenant_id=v_tenant and name='Bar principal' limit 1;
  if v_bar is null then insert into locations(tenant_id,unit_id,name,type) values(v_tenant,v_unit,'Bar principal','bar') returning id into v_bar; end if;
  select id into v_wh from locations where tenant_id=v_tenant and name='Depósito central' limit 1;
  if v_wh is null then insert into locations(tenant_id,unit_id,name,type) values(v_tenant,v_unit,'Depósito central','warehouse') returning id into v_wh; end if;
  insert into suppliers(tenant_id,name,email) select v_tenant,'Fornecedor sintético principal','compras@example.invalid' where not exists(select 1 from suppliers where tenant_id=v_tenant and name='Fornecedor sintético principal') returning id into v_supplier;
  if v_supplier is null then select id into v_supplier from suppliers where tenant_id=v_tenant and name='Fornecedor sintético principal' limit 1; end if;
  for r in select * from (values
    ('BEV-001','Água sem gás 500 ml','bebida','consumable','ml'),('FOO-001','Gelo em cubos','alimento','consumable','g'),('SUP-001','Xarope de açúcar','insumo','consumable','ml'),('DIS-001','Copo biodegradável 300 ml','descartavel','consumable','un'),('EQU-001','Caixa térmica','equipamento','asset','un'),('UTL-001','Pinça de bar','utensilio','returnable','un'),('EVT-001','Lona de evento','evento','returnable','m'),('APO-001','Etiqueta de identificação','apoio','consumable','un')
  ) as t(sku,item_name,family,nature,base_uom) loop
    insert into categories(tenant_id,name,family) values(v_tenant,initcap(r.family),r.family) on conflict(tenant_id,name) do update set family=excluded.family returning id into v_cat;
    insert into items(tenant_id,category_id,sku,name,nature,family,base_uom) values(v_tenant,v_cat,r.sku,r.item_name,r.nature,r.family,r.base_uom) on conflict(tenant_id,sku) do update set status='active',category_id=excluded.category_id returning id into v_item;
    if not exists(select 1 from item_packages where tenant_id=v_tenant and item_id=v_item and name='Unidade padrão') then insert into item_packages(tenant_id,item_id,name,factor) values(v_tenant,v_item,'Unidade padrão',1); end if;
    insert into item_location_policies(tenant_id,item_id,location_id,min_q,max_q,reorder_q) values(v_tenant,v_item,v_bar,10,100,30),(v_tenant,v_item,v_wh,20,200,60) on conflict(tenant_id,item_id,location_id) do nothing;
    insert into lots(tenant_id,item_id,lot_code,expires_on,condition) values(v_tenant,v_item,'DEMO-VALID-'||r.sku,current_date+90,'usable') on conflict(tenant_id,item_id,lot_code) do nothing returning id into v_lot;
    if v_lot is null then select id into v_lot from lots where tenant_id=v_tenant and item_id=v_item and lot_code='DEMO-VALID-'||r.sku; end if;
    insert into stock_positions(tenant_id,item_id,location_id,lot_id,on_hand_q) values(v_tenant,v_item,v_bar,v_lot,100) on conflict(tenant_id,item_id,location_id,lot_id,condition) do nothing;
    insert into stock_positions(tenant_id,item_id,location_id,lot_id,on_hand_q) values(v_tenant,v_item,v_wh,v_lot,200) on conflict(tenant_id,item_id,location_id,lot_id,condition) do nothing;
    if r.sku in('BEV-001','FOO-001') then
      insert into lots(tenant_id,item_id,lot_code,expires_on,condition) values(v_tenant,v_item,'DEMO-EXPIRED-'||r.sku,current_date-5,'expired') on conflict(tenant_id,item_id,lot_code) do nothing returning id into v_expired;
      if v_expired is null then select id into v_expired from lots where tenant_id=v_tenant and item_id=v_item and lot_code='DEMO-EXPIRED-'||r.sku; end if;
      insert into stock_positions(tenant_id,item_id,location_id,lot_id,condition,on_hand_q) values(v_tenant,v_item,v_wh,v_expired,'expired',25) on conflict(tenant_id,item_id,location_id,lot_id,condition) do nothing;
    end if;
    insert into supplier_items(tenant_id,supplier_id,item_id,last_unit_cost) values(v_tenant,v_supplier,v_item,1) on conflict(tenant_id,supplier_id,item_id) do nothing;
  end loop;
  insert into events(tenant_id,name,code,venue,starts_at,ends_at,status,created_by) values(v_tenant,'Evento sintético planejado','DEMO-PLAN','Centro de eventos',now()+interval '5 days',now()+interval '5 days 8 hours','planned',v_uid) on conflict(tenant_id,code) do nothing;
  insert into events(tenant_id,name,code,venue,starts_at,ends_at,status,created_by) values(v_tenant,'Evento sintético em operação','DEMO-OPS','Galpão temporário',now()-interval '2 hours',now()+interval '4 hours','operating',v_uid) on conflict(tenant_id,code) do nothing;
  return v_tenant;
end; $$;
revoke all on function public.seed_demo_data() from public,anon;
grant execute on function public.seed_demo_data() to authenticated;
