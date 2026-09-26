-- Row Level Security: every row belongs to exactly one user.
alter table public.profiles enable row level security;
alter table public.user_preferences enable row level security;
alter table public.moments enable row level security;
alter table public.creations enable row level security;
alter table public.inspirations enable row level security;
alter table public.prompts enable row level security;
alter table public.answers enable row level security;
alter table public.media enable row level security;
alter table public.tags enable row level security;
alter table public.moment_tags enable row level security;

-- helper: does the moment belong to the caller?
create or replace function public.owns_moment(mid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.moments m where m.id = mid and m.user_id = auth.uid());
$$;
revoke all on function public.owns_moment(uuid) from public, anon;
grant execute on function public.owns_moment(uuid) to authenticated;

-- profiles
create policy profiles_select on public.profiles for select to authenticated using (id = auth.uid());
create policy profiles_insert on public.profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_update on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- preferences
create policy prefs_select on public.user_preferences for select to authenticated using (user_id = auth.uid());
create policy prefs_insert on public.user_preferences for insert to authenticated with check (user_id = auth.uid());
create policy prefs_update on public.user_preferences for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- moments
create policy moments_select on public.moments for select to authenticated using (user_id = auth.uid());
create policy moments_insert on public.moments for insert to authenticated with check (user_id = auth.uid());
create policy moments_update on public.moments for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy moments_delete on public.moments for delete to authenticated using (user_id = auth.uid());

-- children of moments
create policy creations_all on public.creations for all to authenticated
  using (public.owns_moment(moment_id)) with check (public.owns_moment(moment_id));
create policy inspirations_all on public.inspirations for all to authenticated
  using (public.owns_moment(moment_id)) with check (public.owns_moment(moment_id));
create policy prompts_all on public.prompts for all to authenticated
  using (public.owns_moment(moment_id)) with check (public.owns_moment(moment_id));
create policy media_all on public.media for all to authenticated
  using (public.owns_moment(moment_id)) with check (public.owns_moment(moment_id));
create policy answers_all on public.answers for all to authenticated
  using (exists (select 1 from public.prompts p where p.id = prompt_id and public.owns_moment(p.moment_id)))
  with check (exists (select 1 from public.prompts p where p.id = prompt_id and public.owns_moment(p.moment_id)));

-- tags
create policy tags_all on public.tags for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy moment_tags_all on public.moment_tags for all to authenticated
  using (public.owns_moment(moment_id)
         and exists (select 1 from public.tags t where t.id = tag_id and t.user_id = auth.uid()))
  with check (public.owns_moment(moment_id)
         and exists (select 1 from public.tags t where t.id = tag_id and t.user_id = auth.uid()));

-- Account deletion: client removes storage files first (Storage API), then calls this.
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from auth.users where id = auth.uid();
end $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
