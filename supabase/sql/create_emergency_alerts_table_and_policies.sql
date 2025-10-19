-- Create emergency_alerts table and RLS policies
-- This table manages emergency alerts from assisted users to guardians

-- Create the emergency_alerts table
create table if not exists public.emergency_alerts (
  id uuid default gen_random_uuid() primary key,
  assisted_id uuid not null references auth.users(id) on delete cascade,
  guardian_id uuid not null references auth.users(id) on delete cascade,
  message text,
  created_at timestamptz not null default now(),
  unique(assisted_id, guardian_id, created_at)
);

-- Enable Row Level Security
alter table public.emergency_alerts enable row level security;

-- Drop existing policies if they exist
drop policy if exists emergency_alerts_select_own on public.emergency_alerts;
drop policy if exists emergency_alerts_insert_own on public.emergency_alerts;

-- Policy: Guardians can view emergency alerts directed to them
create policy emergency_alerts_select_own
  on public.emergency_alerts
  for select
  to authenticated
  using (auth.uid() = guardian_id);

-- Policy: Assisted users can create emergency alerts
create policy emergency_alerts_insert_own
  on public.emergency_alerts
  for insert
  to authenticated
  with check (auth.uid() = assisted_id);

-- Create indexes for better performance
create index if not exists idx_emergency_alerts_assisted_id on public.emergency_alerts(assisted_id);
create index if not exists idx_emergency_alerts_guardian_id on public.emergency_alerts(guardian_id);
create index if not exists idx_emergency_alerts_created_at on public.emergency_alerts(created_at);