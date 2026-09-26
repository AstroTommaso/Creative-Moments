-- Creative Moments: core schema
create extension if not exists pgcrypto;

create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- profiles ------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 80),
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- user_preferences ----------------------------------------------------
create table public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  environments text[] not null default '{}',
  environment text not null default 'moon',
  atmosphere text not null default 'dreamy',
  time_style text not null default 'auto'
    check (time_style in ('auto','dawn','day','sunset','night')),
  visual_density text not null default 'balanced'
    check (visual_density in ('subtle','balanced','immersive')),
  preferred_inspirations text[] not null default '{}',
  dark_mode boolean not null default true,
  reduce_motion boolean not null default false,
  location_enabled boolean not null default false,
  weather_enabled boolean not null default false,
  onboarded boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- moments -------------------------------------------------------------
create table public.moments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '' check (char_length(title) <= 200),
  creation_type text not null default 'freeform'
    check (creation_type in ('writing','drawing','story','letter','photo','idea','voice','freeform')),
  mood text,
  atmosphere text,
  time_of_day text check (time_of_day in ('dawn','day','sunset','night')),
  location_name text,
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  music_title text,
  music_artist text,
  music_album text,
  music_artwork_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index moments_user_created_idx on public.moments (user_id, created_at desc);

-- creations -----------------------------------------------------------
create table public.creations (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.moments(id) on delete cascade,
  type text not null check (type in ('text','drawing','image','audio')),
  text_content text,
  drawing_data jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index creations_moment_idx on public.creations (moment_id);

-- inspirations --------------------------------------------------------
create table public.inspirations (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.moments(id) on delete cascade,
  type text not null,
  name text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (moment_id, type, name)
);
create index inspirations_moment_idx on public.inspirations (moment_id);

-- prompts / answers ---------------------------------------------------
create table public.prompts (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.moments(id) on delete cascade,
  question text not null,
  created_at timestamptz not null default now()
);
create index prompts_moment_idx on public.prompts (moment_id);

create table public.answers (
  id uuid primary key default gen_random_uuid(),
  prompt_id uuid not null references public.prompts(id) on delete cascade,
  answer text not null,
  created_at timestamptz not null default now()
);
create index answers_prompt_idx on public.answers (prompt_id);

-- media ---------------------------------------------------------------
create table public.media (
  id uuid primary key default gen_random_uuid(),
  moment_id uuid not null references public.moments(id) on delete cascade,
  type text not null check (type in ('image','drawing','audio')),
  storage_path text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index media_moment_idx on public.media (moment_id);

-- tags ----------------------------------------------------------------
create table public.tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  unique (user_id, name)
);
create table public.moment_tags (
  moment_id uuid not null references public.moments(id) on delete cascade,
  tag_id uuid not null references public.tags(id) on delete cascade,
  primary key (moment_id, tag_id)
);

-- triggers ------------------------------------------------------------
create trigger profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger prefs_updated before update on public.user_preferences
  for each row execute function public.set_updated_at();
create trigger moments_updated before update on public.moments
  for each row execute function public.set_updated_at();
create trigger creations_updated before update on public.creations
  for each row execute function public.set_updated_at();

-- create profile + preferences on signup
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', ''));
  insert into public.user_preferences (user_id) values (new.id);
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
