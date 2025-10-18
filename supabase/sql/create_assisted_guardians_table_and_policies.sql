-- Create assisted_guardians table and RLS policies
-- This table manages the relationship between guardians and assisted users

-- Create the assisted_guardians table
create table if not exists public.assisted_guardians (
  id uuid default gen_random_uuid() primary key,
  assisted_id uuid not null references auth.users(id) on delete cascade,
  guardian_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(assisted_id, guardian_id)
);

-- Enable Row Level Security
alter table public.assisted_guardians enable row level security;

-- Drop existing policies if they exist
drop policy if exists assisted_guardians_select_own_requests on public.assisted_guardians;
drop policy if exists assisted_guardians_select_guardian_requests on public.assisted_guardians;
drop policy if exists assisted_guardians_insert_own_requests on public.assisted_guardians;
drop policy if exists assisted_guardians_update_guardian_responses on public.assisted_guardians;
drop policy if exists assisted_guardians_update_assisted_cancellation on public.assisted_guardians;

-- Policy: Assisted users can view their own guardian requests
create policy assisted_guardians_select_own_requests
  on public.assisted_guardians
  for select
  to authenticated
  using (auth.uid() = assisted_id);

-- Policy: Guardians can view requests directed to them
create policy assisted_guardians_select_guardian_requests
  on public.assisted_guardians
  for select
  to authenticated
  using (auth.uid() = guardian_id);

-- Policy: Assisted users can create requests to guardians
create policy assisted_guardians_insert_own_requests
  on public.assisted_guardians
  for insert
  to authenticated
  with check (auth.uid() = assisted_id and status = 'pending');

-- Policy: Guardians can update the status of requests directed to them
create policy assisted_guardians_update_guardian_responses
  on public.assisted_guardians
  for update
  to authenticated
  using (auth.uid() = guardian_id)
  with check (auth.uid() = guardian_id and status in ('accepted', 'rejected'));

-- Policy: Assisted users can cancel their own pending requests
create policy assisted_guardians_update_assisted_cancellation
  on public.assisted_guardians
  for update
  to authenticated
  using (auth.uid() = assisted_id and status = 'pending')
  with check (auth.uid() = assisted_id and status in ('rejected'));

-- Create indexes for better performance
create index if not exists idx_assisted_guardians_assisted_id on public.assisted_guardians(assisted_id);
create index if not exists idx_assisted_guardians_guardian_id on public.assisted_guardians(guardian_id);
create index if not exists idx_assisted_guardians_status on public.assisted_guardians(status);
create index if not exists idx_assisted_guardians_created_at on public.assisted_guardians(created_at);

-- Create trigger to update updated_at timestamp
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists update_assisted_guardians_updated_at on public.assisted_guardians;
create trigger update_assisted_guardians_updated_at
  before update on public.assisted_guardians
  for each row execute function update_updated_at_column();