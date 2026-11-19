-- O status comercial do pedido acompanha a quantidade aceita, não a rejeitada.
create or replace function private.sync_purchase_order_status()
returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  update public.purchase_orders
  set status=case when new.received_q>=new.ordered_q then 'received' else 'partial' end
  where tenant_id=new.tenant_id and id=new.order_id;
  return new;
end; $$;

drop trigger if exists purchase_order_status_from_acceptance on public.purchase_order_lines;
create trigger purchase_order_status_from_acceptance
after update of received_q,delivered_q on public.purchase_order_lines
for each row execute function private.sync_purchase_order_status();
