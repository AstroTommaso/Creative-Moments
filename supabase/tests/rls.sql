-- Row Level Security regression test. Runs in one transaction and rolls back.
--   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls.sql
-- (local: `supabase start`, then use the DB URL printed by `supabase status`)
begin;

insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('aaaaaaaa-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alice@test.local', '{"display_name":"Alice"}', now(), now()),
  ('bbbbbbbb-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bob@test.local', '{"display_name":"Bob"}', now(), now());

create or replace function pg_temp.act_as(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', uid::text, true);
  execute 'set local role authenticated';
end $$;

create or replace function pg_temp.expect_fail(sql text, label text) returns void language plpgsql as $$
begin
  begin
    execute sql;
  exception when others then
    return;
  end;
  raise exception 'EXPECTED FAILURE BUT SUCCEEDED: %', label;
end $$;

create or replace function pg_temp.expect_count(sql text, expected bigint, label text) returns void language plpgsql as $$
declare n bigint;
begin
  execute 'select count(*) from (' || sql || ') q' into n;
  if n <> expected then raise exception 'COUNT MISMATCH for %: expected %, got %', label, expected, n; end if;
end $$;

-- signup trigger created profile + preferences
select pg_temp.expect_count($q$select 1 from public.profiles where id in ('aaaaaaaa-0000-0000-0000-00000000000a','bbbbbbbb-0000-0000-0000-00000000000b')$q$, 2, 'profiles created');
select pg_temp.expect_count($q$select 1 from public.user_preferences$q$, 2, 'preferences created');

-- alice writes her data
select pg_temp.act_as('aaaaaaaa-0000-0000-0000-00000000000a');
insert into public.moments (id, user_id, title, creation_type) values ('11111111-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-00000000000a', 'Alice moment', 'writing');
insert into public.creations (moment_id, type, text_content) values ('11111111-0000-0000-0000-000000000001', 'text', 'secret');
insert into public.media (moment_id, type, storage_path) values ('11111111-0000-0000-0000-000000000001', 'image', 'aaaaaaaa-0000-0000-0000-00000000000a/11111111-0000-0000-0000-000000000001/a.jpg');
select public.save_moment_details('11111111-0000-0000-0000-000000000001', '[{"type":"moon","name":"Moon"}]', '[{"id":"22222222-0000-0000-0000-000000000001","question":"Q?","answer":"A"}]');
select pg_temp.expect_count($q$select 1 from public.moments$q$, 1, 'alice sees her moment');
select pg_temp.expect_count($q$select 1 from public.answers$q$, 1, 'alice sees her answer');
insert into storage.objects (bucket_id, name, owner) values ('moment-media', 'aaaaaaaa-0000-0000-0000-00000000000a/11111111-0000-0000-0000-000000000001/a.jpg', 'aaaaaaaa-0000-0000-0000-00000000000a');
select pg_temp.expect_fail($q$insert into public.moments (user_id, title) values ('bbbbbbbb-0000-0000-0000-00000000000b', 'forged')$q$, 'alice cannot create a moment as bob');
select pg_temp.expect_fail($q$insert into storage.objects (bucket_id, name) values ('moment-media', 'bbbbbbbb-0000-0000-0000-00000000000b/x.jpg')$q$, 'alice cannot upload into bob folder');

-- bob sees nothing of alice's, and cannot touch it
reset role;
select pg_temp.act_as('bbbbbbbb-0000-0000-0000-00000000000b');
select pg_temp.expect_count($q$select 1 from public.moments$q$, 0, 'bob sees no moments');
select pg_temp.expect_count($q$select 1 from public.creations$q$, 0, 'bob sees no creations');
select pg_temp.expect_count($q$select 1 from public.inspirations$q$, 0, 'bob sees no inspirations');
select pg_temp.expect_count($q$select 1 from public.prompts$q$, 0, 'bob sees no prompts');
select pg_temp.expect_count($q$select 1 from public.answers$q$, 0, 'bob sees no answers');
select pg_temp.expect_count($q$select 1 from public.media$q$, 0, 'bob sees no media rows');
select pg_temp.expect_count($q$select 1 from public.profiles where id = 'aaaaaaaa-0000-0000-0000-00000000000a'$q$, 0, 'bob cannot read alice profile');
select pg_temp.expect_count($q$select 1 from public.user_preferences where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a'$q$, 0, 'bob cannot read alice preferences');
select pg_temp.expect_count($q$select 1 from storage.objects where bucket_id = 'moment-media'$q$, 0, 'bob cannot list alice files');
select pg_temp.expect_fail($q$insert into public.creations (moment_id, type, text_content) values ('11111111-0000-0000-0000-000000000001', 'text', 'injected')$q$, 'bob cannot add to alice moment');
select pg_temp.expect_fail($q$select public.save_moment_details('11111111-0000-0000-0000-000000000001', '[]', '[]')$q$, 'bob cannot rewrite alice details');

-- updates/deletes by bob affect zero rows
do $$
declare n int;
begin
  update public.moments set title = 'hacked' where id = '11111111-0000-0000-0000-000000000001';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'bob updated alice moment'; end if;
  delete from public.moments where id = '11111111-0000-0000-0000-000000000001';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'bob deleted alice moment'; end if;
  update public.user_preferences set atmosphere = 'dark' where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'bob updated alice preferences'; end if;
  delete from storage.objects where bucket_id = 'moment-media';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'bob deleted alice files'; end if;
end $$;

-- anonymous users get nothing
reset role;
set local role anon;
select pg_temp.expect_count($q$select 1 from public.moments$q$, 0, 'anon sees no moments');
select pg_temp.expect_fail($q$select public.delete_my_account()$q$, 'anon cannot delete accounts');
reset role;

-- alice can still see and delete her own data, cascading to children
select pg_temp.act_as('aaaaaaaa-0000-0000-0000-00000000000a');
select pg_temp.expect_count($q$select 1 from public.moments$q$, 1, 'alice still has her moment');
delete from public.moments where id = '11111111-0000-0000-0000-000000000001';
select pg_temp.expect_count($q$select 1 from public.creations$q$, 0, 'creations cascade');
select pg_temp.expect_count($q$select 1 from public.answers$q$, 0, 'answers cascade');
update public.user_preferences set atmosphere = 'calm' where user_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
select pg_temp.expect_count($q$select 1 from public.user_preferences where atmosphere = 'calm'$q$, 1, 'alice edits her preferences');

-- buckets are private
reset role;
select pg_temp.expect_count($q$select 1 from storage.buckets where id in ('moment-media','avatars') and public = false$q$, 2, 'buckets are private');

select 'RLS OK' as result;
rollback;
