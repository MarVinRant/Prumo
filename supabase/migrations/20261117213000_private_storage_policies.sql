create or replace function private.is_member_path(p_tenant text) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_tenant is null or p_tenant !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then return false; end if;
  return private.is_member(p_tenant::uuid);
end; $$;

drop policy if exists prumo_private_select on storage.objects;
create policy prumo_private_select on storage.objects for select to authenticated using(bucket_id='prumo-private' and private.is_member_path(split_part(name,'/',1)));
drop policy if exists prumo_private_insert on storage.objects;
create policy prumo_private_insert on storage.objects for insert to authenticated with check(bucket_id='prumo-private' and private.is_member_path(split_part(name,'/',1)));
drop policy if exists prumo_private_update on storage.objects;
create policy prumo_private_update on storage.objects for update to authenticated using(bucket_id='prumo-private' and private.is_member_path(split_part(name,'/',1))) with check(bucket_id='prumo-private' and private.is_member_path(split_part(name,'/',1)));
drop policy if exists prumo_private_delete on storage.objects;
create policy prumo_private_delete on storage.objects for delete to authenticated using(bucket_id='prumo-private' and private.is_member_path(split_part(name,'/',1)));
