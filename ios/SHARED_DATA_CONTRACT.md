# Shared Data Contract (Android + iOS)

Both clients should use the same Supabase project and the same table contracts.

## Auth

- `POST auth/v1/token?grant_type=password`
- `POST auth/v1/token?grant_type=refresh_token`
- `GET auth/v1/user`

## Core tables

1. `users`
- Fields used now:
  - `id`
  - `auth_user_id`
  - `email`
  - `name`
  - `role`
  - `is_online`
  - `last_seen_at`
  - `phone`
  - `avatar_url`
  - `notification_enabled`
  - `created_at`
  - `updated_at`

2. `projects`
- Fields used now:
  - `id`
  - `name`
  - `description`
  - `status`
  - `created_by`
  - `short_id`
  - `is_archived`
  - `created_at`
  - `updated_at`

3. `tasks`
- Fields used now:
  - `id`
  - `project_id`
  - `title`
  - `description`
  - `assignee_id`
  - `status`
  - `due_date`
  - `short_id`
  - `is_archived`
  - `created_by`
  - `created_at`
  - `updated_at`

4. `chats`
- Fields used now:
  - `id`
  - `type`
  - `name`
  - `created_by`
  - `created_at`
  - `updated_at`
  - `is_deleted`

5. `installations`
- Fields used now:
  - `id`
  - `project_id`
  - `title`
  - `description`
  - `assignee_id`
  - `status`
  - `scheduled_at`
  - `deadline`
  - `address`
  - `is_archived`
  - `short_id`
  - `actual_completion_date`
  - `id_ploshadki`
  - `servisnyy_id`
  - `rayon`
  - `created_by`
  - `created_at`
  - `updated_at`

6. `messages`
- Fields used now:
  - `id`
  - `chat_id`
  - `user_id`
  - `content`
  - `type`
  - `job_id`
  - `is_read`
  - `is_deleted`
  - `created_at`

7. `purchase_requests`
- Fields used now:
  - `id`
  - `status`
  - `installation_id`
  - `task_id`
  - `task_avr_id`
  - `project_id`
  - `created_by`
  - `approved_by`
  - `total_amount`
  - `comment`
  - `receipt_address`
  - `received_at`
  - `short_id`
  - `created_at`
  - `updated_at`

8. `user_locations`
- Fields used now:
  - `id`
  - `user_id`
  - `date` / `recorded_at`
  - `distance` / `distance_km`
  - `route`
  - `purpose`
  - `latitude`
  - `longitude`
  - `accuracy`
  - `created_at`

9. `warehouse`, `warehouse_issues`
- Fields used now:
  - `*` (generic row rendering)

10. Additional section tables (read + list rendering)
- `tasks_avr`
- `quarter_2026`
- `atss_q1_2026`
- `jobs`

11. Functions used
- `functions/v1/push-register`
  - payload:
    - `user_id`
    - `fcm_token`

12. Realtime-ish chat support tables
- `chat_typing`
  - fields used:
    - `chat_id`
    - `user_id`
    - `is_typing`
    - `updated_at`

## Rules

- Keep snake_case column names in payloads for both platforms.
- Any schema migration must be backward-compatible for both Android and iOS clients.
- Before adding a new required column, update both app models in one release cycle.
