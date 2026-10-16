-- FamilieKurv v0.9 migration. Run in Supabase SQL editor after v0.6 setup.
-- Existing family/list rows retained. Enable Anonymous Sign-Ins under Authentication > Providers.
create extension if not exists pgcrypto;
create table if not exists public.family_invitations (
 id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
 token_hash text not null unique, created_by uuid not null references auth.users(id),
 expires_at timestamptz not null, used_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.family_requests (
 id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 display_name text not null check(char_length(display_name) between 1 and 50),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 requested_at timestamptz not null default now(), resolved_at timestamptz,
 unique(family_id,user_id)
);
alter table public.family_invitations enable row level security;
alter table public.family_requests enable row level security;
-- Only approved members see lists; helper is security-definer in v0.6 setup.
create or replace function public.is_family_admin(fid uuid)
returns boolean language sql stable security definer set search_path=public
as $$select exists(select 1 from public.families where id=fid and created_by=auth.uid())$$;
revoke all on function public.is_family_admin(uuid) from public;
grant execute on function public.is_family_admin(uuid) to authenticated;
-- Remove old immediate-join capability, including the old family invite code.
revoke execute on function public.join_family(text) from public, anon, authenticated;
-- Stop old clients from revealing permanent invite codes (new client doesn't display these).
-- RLS keeps member data private; admins may review membership.
drop policy if exists "Admins read family members" on public.family_members;
create policy "Admins read family members" on public.family_members
for select to authenticated using(public.is_family_admin(family_id));
-- RPC returns a one-time, ten-minute token (only its hash is stored).
create or replace function public.make_family_invite(fid uuid)
returns text language plpgsql security definer set search_path=public as $$
declare tok text;
begin
 if auth.uid() is null or not public.is_family_admin(fid) then raise exception 'Admin approval required'; end if;
 tok := encode(gen_random_bytes(24),'hex');
 insert into public.family_invitations(family_id,token_hash,created_by,expires_at)
 values(fid,encode(digest(tok,'sha256'),'hex'),auth.uid(),now()+interval '10 minutes');
 return tok;
end $$;
revoke all on function public.make_family_invite(uuid) from public, anon;
grant execute on function public.make_family_invite(uuid) to authenticated;
-- A scanned invitation creates a pending request, not membership.
create or replace function public.request_family_join(tok text, member_name text)
returns text language plpgsql security definer set search_path=public as $$
declare f uuid; u uuid:=auth.uid();
begin
 if u is null then raise exception 'Open a device session first'; end if;
 if char_length(trim(coalesce(member_name,''))) not between 1 and 50 then raise exception 'Enter a name (1–50 characters)'; end if;
 if exists(select 1 from public.family_members where user_id=u) then raise exception 'Already a family member'; end if;
 -- lock invitation so concurrent requests cannot both use it
 select family_id into f from public.family_invitations
 where token_hash=encode(digest(coalesce(tok,''),'sha256'),'hex') and used_at is null and expires_at>now()
 for update;
 if f is null then raise exception 'This invitation has expired or was already used'; end if;
 update public.family_invitations set used_at=now() where token_hash=encode(digest(tok,'sha256'),'hex');
 insert into public.family_requests(family_id,user_id,display_name,status,requested_at,resolved_at)
 values(f,u,trim(member_name),'pending',now(),null)
 on conflict(family_id,user_id) do update set display_name=excluded.display_name,status='pending',requested_at=now(),resolved_at=null;
 return 'pending';
end $$;
revoke all on function public.request_family_join(text,text) from public, anon;
grant execute on function public.request_family_join(text,text) to authenticated;
create or replace function public.list_family_requests(fid uuid)
returns table(id uuid,display_name text,requested_at timestamptz)
language plpgsql security definer set search_path=public as $$
begin
 if not public.is_family_admin(fid) then raise exception 'Admin only'; end if;
 return query select r.id,r.display_name,r.requested_at from public.family_requests r where r.family_id=fid and r.status='pending' order by r.requested_at;
end $$;
revoke all on function public.list_family_requests(uuid) from public, anon;
grant execute on function public.list_family_requests(uuid) to authenticated;
create or replace function public.list_family_members(fid uuid)
returns table(user_id uuid,display_name text,is_admin boolean)
language plpgsql security definer set search_path=public as $$
begin
 if not public.is_family_admin(fid) then raise exception 'Admin only'; end if;
 return query select m.user_id,coalesce((select r.display_name from public.family_requests r where r.family_id=fid and r.user_id=m.user_id and r.status='approved' limit 1),case when m.user_id=(select created_by from public.families where id=fid) then 'You (admin)' else 'Existing member' end),m.user_id=(select created_by from public.families where id=fid)
 from public.family_members m where m.family_id=fid order by 3 desc,2;
end $$;
revoke all on function public.list_family_members(uuid) from public, anon;
grant execute on function public.list_family_members(uuid) to authenticated;
create or replace function public.resolve_family_request(request_id uuid, allow_join boolean)
returns void language plpgsql security definer set search_path=public as $$
declare r public.family_requests%rowtype;
begin
 select * into r from public.family_requests where id=request_id and status='pending' for update;
 if not found or not public.is_family_admin(r.family_id) then raise exception 'Pending request not found or not authorized'; end if;
 if allow_join then
  if exists(select 1 from public.family_members where user_id=r.user_id) then raise exception 'This device belongs to another family'; end if;
  insert into public.family_members(user_id,family_id) values(r.user_id,r.family_id);
 end if;
 update public.family_requests set status=case when allow_join then 'approved' else 'rejected' end,resolved_at=now() where id=request_id;
end $$;
revoke all on function public.resolve_family_request(uuid,boolean) from public, anon;
grant execute on function public.resolve_family_request(uuid,boolean) to authenticated;
create or replace function public.remove_family_member(fid uuid, member_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_family_admin(fid) then raise exception 'Admin only'; end if;
 if member_id=(select created_by from public.families where id=fid) then raise exception 'Cannot remove family admin'; end if;
 delete from public.family_members where family_id=fid and user_id=member_id;
 update public.family_requests set status='rejected',resolved_at=now() where family_id=fid and user_id=member_id;
end $$;
revoke all on function public.remove_family_member(uuid,uuid) from public, anon;
grant execute on function public.remove_family_member(uuid,uuid) to authenticated;
