# Database Policy Fix for Task Management

## Problem
Regular users (guardians) cannot edit or delete tasks for their assisted users due to restrictive Row Level Security (RLS) policies in Supabase. The error message was:
```
Task not updated. It may not exist or you may not have permission.
```

## Root Cause
The `tasks` table RLS policies only allowed users to access tasks where `user_id = auth.uid()`. However, when guardians manage tasks for assisted users, the task's `user_id` is the assisted user's ID, not the guardian's ID.

## Solution
Updated RLS policies to allow guardians to access tasks for their accepted assisted users through the `assisted_guardians` relationship table.

## Files to Apply

### 1. Tasks Table Policies
**File:** `supabase/sql/create_tasks_table_and_policies.sql`

This creates/updates the `tasks` table with proper RLS policies that allow:
- Users to manage their own tasks
- Guardians to manage tasks for their accepted assisted users

### 2. Assisted Guardians Table Policies
**File:** `supabase/sql/create_assisted_guardians_table_and_policies.sql`

This ensures the `assisted_guardians` table has proper RLS policies for managing guardian-assisted relationships.

## How to Apply

1. **Open Supabase Dashboard**
   - Go to your Supabase project dashboard
   - Navigate to the SQL Editor

2. **Run the Assisted Guardians SQL First**
   ```sql
   -- Copy and paste the contents of create_assisted_guardians_table_and_policies.sql
   ```

3. **Run the Tasks SQL Second**
   ```sql
   -- Copy and paste the contents of create_tasks_table_and_policies.sql
   ```

4. **Verify the Fix**
   - Test that regular users can now edit/delete tasks for their assisted users
   - Check that assisted users can still only manage their own tasks
   - Ensure proper security is maintained

## Policy Details

### Tasks Table Policies
- **tasks_select_own**: Users can view their own tasks
- **tasks_select_assisted**: Guardians can view tasks for accepted assisted users
- **tasks_insert_own**: Users can create their own tasks
- **tasks_insert_assisted**: Guardians can create tasks for accepted assisted users
- **tasks_update_own**: Users can update their own tasks
- **tasks_update_assisted**: Guardians can update tasks for accepted assisted users
- **tasks_delete_own**: Users can delete their own tasks
- **tasks_delete_assisted**: Guardians can delete tasks for accepted assisted users

### Assisted Guardians Table Policies
- **assisted_guardians_select_own_requests**: Assisted users can view their own requests
- **assisted_guardians_select_guardian_requests**: Guardians can view requests to them
- **assisted_guardians_insert_own_requests**: Assisted users can create requests
- **assisted_guardians_update_guardian_responses**: Guardians can accept/reject requests
- **assisted_guardians_update_assisted_cancellation**: Assisted users can cancel pending requests

## Security Considerations
- All policies require authentication (`to authenticated`)
- Relationships are validated through the `assisted_guardians` table
- Only accepted relationships allow task management
- Users cannot access tasks for rejected or pending relationships