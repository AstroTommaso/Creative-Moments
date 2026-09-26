-- Private buckets. Object path convention: <user_id>/<moment_id or 'avatar'>/<file>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('moment-media', 'moment-media', false, 10485760,
   array['image/png','image/jpeg','image/webp','audio/mpeg','audio/mp4','audio/aac','audio/wav']),
  ('avatars', 'avatars', false, 3145728, array['image/png','image/jpeg','image/webp'])
on conflict (id) do update set public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "own media select" on storage.objects for select to authenticated
  using (bucket_id in ('moment-media','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own media insert" on storage.objects for insert to authenticated
  with check (bucket_id in ('moment-media','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own media update" on storage.objects for update to authenticated
  using (bucket_id in ('moment-media','avatars') and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id in ('moment-media','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own media delete" on storage.objects for delete to authenticated
  using (bucket_id in ('moment-media','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
