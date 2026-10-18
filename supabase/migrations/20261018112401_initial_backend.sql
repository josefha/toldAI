create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
create table public.listening_sessions (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null,
  created_at timestamptz not null default now()
);
create index sessions_owner on public.listening_sessions(user_id, created_at desc);
create table public.answers (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  story_id text not null,
  data jsonb not null,
  created_at timestamptz not null default now()
);
create index answers_owner on public.answers(user_id, story_id, created_at);
create table public.jobs (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('daily','podcast','question')),
  input jsonb not null,
  status text not null default 'queued' check (status in ('queued','running','completed','failed','cancelled')),
  result jsonb,
  error text,
  worker_id uuid,
  attempts integer not null default 0,
  lease_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index jobs_owner on public.jobs(user_id, created_at desc);
create index jobs_queue on public.jobs(status, created_at) where status in ('queued','running');
create table public.content_cache (
  key text primary key,
  data jsonb,
  owner uuid,
  lease_until timestamptz,
  expires_at timestamptz not null
);
create table public.usage_windows (
  user_id uuid not null references auth.users(id) on delete cascade,
  bucket text not null,
  window_start timestamptz not null,
  count integer not null default 1,
  primary key(user_id,bucket,window_start)
);

alter table public.profiles enable row level security;
alter table public.listening_sessions enable row level security;
alter table public.answers enable row level security;
alter table public.jobs enable row level security;
alter table public.content_cache enable row level security;
alter table public.usage_windows enable row level security;
revoke all on public.profiles, public.listening_sessions, public.answers, public.jobs, public.content_cache, public.usage_windows from anon, authenticated;
grant select on public.profiles, public.listening_sessions, public.answers, public.jobs to authenticated;
grant all on public.profiles, public.listening_sessions, public.answers, public.jobs, public.content_cache, public.usage_windows to service_role;
create policy own_profile on public.profiles for select to authenticated using ((select auth.uid()) = user_id);
create policy own_sessions on public.listening_sessions for select to authenticated using ((select auth.uid()) = user_id);
create policy own_answers on public.answers for select to authenticated using ((select auth.uid()) = user_id);
create policy own_jobs on public.jobs for select to authenticated using ((select auth.uid()) = user_id);

-- Invoker functions are service-role-only. No public SECURITY DEFINER bypass.
create function public.claim_job(worker uuid) returns setof public.jobs
language sql security invoker set search_path = '' as $$
  update public.jobs set status='running', worker_id=worker, attempts=attempts+1,
    lease_until=now()+interval '2 minutes', updated_at=now()
  where id = (select id from public.jobs where
    (status='queued' or (status='running' and lease_until < now())) and attempts < 3
    order by created_at for update skip locked limit 1)
  returning *;
$$;
create function public.consume_usage(owner_id uuid, bucket_name text, maximum integer) returns boolean
language plpgsql security invoker set search_path = '' as $$
declare used integer;
begin
  insert into public.usage_windows(user_id,bucket,window_start) values(owner_id,bucket_name,date_trunc('day',now()))
  on conflict(user_id,bucket,window_start) do update set count=public.usage_windows.count+1
  returning count into used;
  return used <= maximum;
end;
$$;
create function public.claim_cache(cache_key text, worker uuid) returns boolean
language plpgsql security invoker set search_path = '' as $$
declare claimed text;
begin
  insert into public.content_cache(key,owner,lease_until,expires_at) values(cache_key,worker,now()+interval '15 minutes',now())
  on conflict(key) do update set owner=worker,lease_until=now()+interval '15 minutes'
  where public.content_cache.expires_at <= now() and (public.content_cache.lease_until is null or public.content_cache.lease_until < now())
  returning key into claimed;
  return claimed is not null;
end;
$$;
revoke all on function public.claim_job(uuid), public.consume_usage(uuid,text,integer), public.claim_cache(text,uuid) from public,anon,authenticated;
grant execute on function public.claim_job(uuid), public.consume_usage(uuid,text,integer), public.claim_cache(text,uuid) to service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('told-audio','told-audio',false,26214400,array['audio/mpeg']) on conflict(id) do nothing;
