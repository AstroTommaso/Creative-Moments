-- Atomically replace a moment's inspirations and prompts/answers.
-- SECURITY INVOKER: RLS applies, so only the owner can call this successfully.
create or replace function public.save_moment_details(
  p_moment_id uuid,
  p_inspirations jsonb,
  p_prompts jsonb
) returns void
language plpgsql security invoker set search_path = public as $$
declare
  item jsonb;
begin
  if not public.owns_moment(p_moment_id) then
    raise exception 'moment not found';
  end if;

  delete from public.inspirations where moment_id = p_moment_id;
  delete from public.prompts where moment_id = p_moment_id;

  for item in select * from jsonb_array_elements(coalesce(p_inspirations, '[]'::jsonb)) loop
    insert into public.inspirations (moment_id, type, name, metadata)
    values (p_moment_id, item->>'type', item->>'name', coalesce(item->'metadata', '{}'::jsonb))
    on conflict (moment_id, type, name) do nothing;
  end loop;

  for item in select * from jsonb_array_elements(coalesce(p_prompts, '[]'::jsonb)) loop
    insert into public.prompts (id, moment_id, question)
    values ((item->>'id')::uuid, p_moment_id, item->>'question');
    if nullif(btrim(coalesce(item->>'answer', '')), '') is not null then
      insert into public.answers (prompt_id, answer)
      values ((item->>'id')::uuid, item->>'answer');
    end if;
  end loop;
end $$;
revoke all on function public.save_moment_details(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.save_moment_details(uuid, jsonb, jsonb) to authenticated;
