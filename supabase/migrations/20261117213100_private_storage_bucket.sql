insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('prumo-private','prumo-private',false,10485760,array['image/*','application/pdf','text/plain'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
