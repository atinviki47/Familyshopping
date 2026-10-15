-- Run ONCE in the Supabase project's SQL Editor.
-- Private one-family-per-user design; rows protected by RLS.
create extension if not exists pgcrypto;

create table if not exists public.families (
 id uuid primary key default gen_random_uuid(),
 name text not null check (char_length(name) between 1 and 80),
 invite_code text not null unique default upper(encode(gen_random_bytes(9),'hex')),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.family_members (
 user_id uuid primary key references auth.users(id) on delete cascade,
 family_id uuid not null references public.families(id) on delete cascade,
 joined_at timestamptz not null default now()
);
create table if not exists public.family_lists (
 family_id uuid primary key references public.families(id) on delete cascade,
 items jsonb not null default '[]'::jsonb check(jsonb_typeof(items)='array'),
 updated_at timestamptz not null default now()
);

alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.family_lists enable row level security;

-- Security-definer avoids policies recursively selecting family_members.
create or replace function public.is_family_member(fid uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.family_members m where m.family_id=fid and m.user_id=(select auth.uid())); $$;
revoke all on function public.is_family_member(uuid) from public;
grant execute on function public.is_family_member(uuid) to authenticated;

create policy "Family members read their family" on public.families for select to authenticated using (public.is_family_member(id));
create policy "Users read own membership" on public.family_members for select to authenticated using (user_id=(select auth.uid()));
create policy "Members read their list" on public.family_lists for select to authenticated using (public.is_family_member(family_id));
create policy "Members update their list" on public.family_lists for update to authenticated using (public.is_family_member(family_id)) with check (public.is_family_member(family_id));

create or replace function public.create_family(family_name text)
returns uuid language plpgsql security definer set search_path=public
as $$
declare f uuid; u uuid := auth.uid();
begin
 if u is null then raise exception 'Please sign in'; end if;
 if family_name is null or char_length(trim(family_name)) not between 1 and 80 then raise exception 'Invalid family name'; end if;
 if exists(select 1 from public.family_members where user_id=u) then raise exception 'Already in a family'; end if;
 insert into public.families(name,created_by) values(trim(family_name),u) returning id into f;
 insert into public.family_members(user_id,family_id) values(u,f);
 insert into public.family_lists(family_id) values(f);
 return f;
end $$;
revoke all on function public.create_family(text) from public;
grant execute on function public.create_family(text) to authenticated;

create or replace function public.join_family(code text)
returns uuid language plpgsql security definer set search_path=public
as $$
declare f uuid; u uuid := auth.uid();
begin
 if u is null then raise exception 'Please sign in'; end if;
 if exists(select 1 from public.family_members where user_id=u) then raise exception 'Already in a family'; end if;
 select id into f from public.families where invite_code=upper(trim(code));
 if f is null then raise exception 'Invitation code not recognized'; end if;
 insert into public.family_members(user_id,family_id) values(u,f);
 return f;
end $$;
revoke all on function public.join_family(text) from public;
grant execute on function public.join_family(text) to authenticated;

-- Trigger controls timestamps (never trust the client's clock).
create or replace function public.touch_family_list()
returns trigger language plpgsql set search_path=public as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists touch_family_list on public.family_lists;
create trigger touch_family_list before update on public.family_lists for each row execute function public.touch_family_list();
