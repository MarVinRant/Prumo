alter table public.receipt_lines add column if not exists returned_q numeric(20,6) not null default 0;
alter table public.receipt_lines drop constraint if exists receipt_lines_returned_q_check;
alter table public.receipt_lines add constraint receipt_lines_returned_q_check check(returned_q>=0 and returned_q<=accepted_q);

create or replace function public.return_supplier_material(p_receipt_id uuid,p_quantity numeric,p_reason text,p_idempotency_key text default null) returns jsonb
language plpgsql security definer set search_path=public,private,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_tenant uuid; v_receipt uuid; v_line uuid; v_item uuid; v_location uuid; v_lot uuid; v_accepted numeric; v_returned numeric; v_uom text; v_pos uuid; v_on numeric; v_reserved numeric; v_doc uuid; v_doc_line uuid; v_no text; v_key text; v_existing jsonb;
begin
  perform private.require_aal2();
  if p_quantity is null or p_quantity<=0 then raise exception 'quantity_must_be_positive'; end if;
  if nullif(trim(p_reason),'') is null then raise exception 'return_reason_required'; end if;
  select r.tenant_id,r.id,rl.id,pol.item_id,r.location_id,rl.lot_id,rl.accepted_q,rl.returned_q,i.base_uom into v_tenant,v_receipt,v_line,v_item,v_location,v_lot,v_accepted,v_returned,v_uom from receipts r join receipt_lines rl on rl.tenant_id=r.tenant_id and rl.receipt_id=r.id join purchase_order_lines pol on pol.tenant_id=rl.tenant_id and pol.id=rl.order_line_id join items i on i.tenant_id=pol.tenant_id and i.id=pol.item_id where r.id=p_receipt_id and r.status='posted' for update;
  if v_tenant is null then raise exception 'receipt_not_found'; end if;
  if not exists(select 1 from memberships where tenant_id=v_tenant and user_id=v_uid and status='active' and role in('owner','manager','purchasing')) then raise exception 'purchasing_required'; end if;
  if p_quantity>v_accepted-v_returned then raise exception 'return_exceeds_accepted_quantity'; end if;
  v_key:=coalesce(p_idempotency_key,'supplier-return:'||p_receipt_id::text||':'||p_quantity::text||':'||md5(trim(p_reason)));
  select jsonb_build_object('document_id',id,'document_no',document_no) into v_existing from stock_documents where tenant_id=v_tenant and idempotency_key=v_key;
  if v_existing is not null then return v_existing; end if;
  select id,on_hand_q,reserved_q into v_pos,v_on,v_reserved from stock_positions where tenant_id=v_tenant and item_id=v_item and location_id=v_location and lot_id=v_lot and condition='usable' for update;
  if v_pos is null or v_on-v_reserved<p_quantity then raise exception 'insufficient_available_stock'; end if;
  v_no:='RET-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6);
  insert into stock_documents(tenant_id,document_no,type,reason,idempotency_key,actor_id) values(v_tenant,v_no,'return',trim(p_reason),v_key,v_uid) returning id into v_doc;
  insert into stock_document_lines(tenant_id,document_id,item_id,location_id,lot_id,quantity,input_uom,signed_quantity) values(v_tenant,v_doc,v_item,v_location,v_lot,p_quantity,v_uom,-p_quantity) returning id into v_doc_line;
  update stock_positions set on_hand_q=on_hand_q-p_quantity,updated_at=now() where tenant_id=v_tenant and id=v_pos;
  insert into stock_entries(tenant_id,document_id,document_line_id,item_id,location_id,lot_id,quantity,direction) values(v_tenant,v_doc,v_doc_line,v_item,v_location,v_lot,p_quantity,'out');
  update receipt_lines set returned_q=returned_q+p_quantity where tenant_id=v_tenant and id=v_line;
  insert into audit_events(tenant_id,actor_id,action,entity,entity_id,payload) values(v_tenant,v_uid,'purchase.supplier_return','receipt',v_receipt,jsonb_build_object('quantity',p_quantity,'lot_id',v_lot,'document_id',v_doc));
  return jsonb_build_object('document_id',v_doc,'document_no',v_no,'quantity',p_quantity);
end; $$;
revoke all on function public.return_supplier_material(uuid,numeric,text,text) from public,anon;
grant execute on function public.return_supplier_material(uuid,numeric,text,text) to authenticated;
