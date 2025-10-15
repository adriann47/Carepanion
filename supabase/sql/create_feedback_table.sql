-- Create feedback table and RLS policy
create table if not exists public.feedback (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id),
  role text,
  subject text,
  message text not null,
  stars int,
  attachments jsonb,
  app_version text,
  platform text,
  created_at timestamptz default now()
);

alter table public.feedback enable row level security;

create policy insert_feedback_authenticated
  on public.feedback
  for insert
  to authenticated
  with check (auth.uid() = user_id);
