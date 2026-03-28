-- ============================================================
-- ПОЛНЫЙ ДАМП БАЗЫ ДАННЫХ: Планировщик (ООО Корнео)
-- Дата: 27.03.2026 | Supabase Project: jmxjbdnqnzkzxgsfywha
-- Таблиц: 29 | Колонок: 415 | FK: 54 | Индексов: 106
-- ============================================================

-- ==========================
-- 0. РАСШИРЕНИЯ
-- ==========================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==========================
-- 1. ТАБЛИЦЫ (без FK — сначала независимые)
-- ==========================

-- ---- users ----
CREATE TABLE IF NOT EXISTS public.users (
  id          uuid                     NOT NULL DEFAULT uuid_generate_v4(),
  auth_user_id uuid,
  email       text                     NOT NULL,
  name        text                     NOT NULL,
  role        text                     NOT NULL,
  created_at  timestamptz              DEFAULT now(),
  updated_at  timestamptz              DEFAULT now(),
  notification_enabled boolean         DEFAULT false,
  is_online   boolean                  DEFAULT false,
  last_seen_at timestamptz,
  fcm_token   text,
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_email_key UNIQUE (email)
);

-- ---- projects ----
CREATE TABLE IF NOT EXISTS public.projects (
  id          uuid        NOT NULL DEFAULT uuid_generate_v4(),
  name        text        NOT NULL,
  description text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  short_id    text,
  CONSTRAINT projects_pkey PRIMARY KEY (id)
);

-- ---- chats ----
CREATE TABLE IF NOT EXISTS public.chats (
  id          uuid        NOT NULL DEFAULT uuid_generate_v4(),
  name        text,
  type        text        DEFAULT 'private'::text,
  created_at  timestamptz DEFAULT now(),
  created_by  uuid,
  CONSTRAINT chats_pkey PRIMARY KEY (id)
);

-- ---- tasks ----
CREATE TABLE IF NOT EXISTS public.tasks (
  id          uuid        NOT NULL DEFAULT uuid_generate_v4(),
  project_id  uuid,
  title       text        NOT NULL,
  description text,
  assignee_id uuid,
  status      text        DEFAULT 'new'::text,
  due_date    date,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  created_by  uuid,
  is_archived boolean     DEFAULT false,
  short_id    integer,
  CONSTRAINT tasks_pkey PRIMARY KEY (id)
);

-- ---- tasks_avr ----
CREATE TABLE IF NOT EXISTS public.tasks_avr (
  id          uuid        NOT NULL DEFAULT uuid_generate_v4(),
  project_id  uuid,
  title       text        NOT NULL,
  description text,
  assignee_id uuid,
  status      text        DEFAULT 'new'::text,
  due_date    date,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  created_by  uuid,
  is_archived boolean     DEFAULT false,
  short_id    integer,
  address     text,
  CONSTRAINT tasks_avr_pkey PRIMARY KEY (id)
);

-- ---- installations ----
CREATE TABLE IF NOT EXISTS public.installations (
  id                      uuid        NOT NULL DEFAULT uuid_generate_v4(),
  project_id              uuid,
  title                   text        NOT NULL,
  description             text,
  assignee_id             uuid,
  status                  text        DEFAULT 'new'::text,
  scheduled_at            timestamptz,
  address                 text,
  created_at              timestamptz DEFAULT now(),
  updated_at              timestamptz DEFAULT now(),
  created_by              uuid,
  deadline                timestamptz,
  id_ploshadki            text,
  servisnyy_id            text,
  rayon                   text,
  id_sk                   bigint,
  naimenovanie_sk         text,
  status_oborudovaniya    text,
  tip_sk_po_dogovoru      text,
  planovaya_data_1_kv_2026 integer,
  id_sk1                  text,
  naimenovanie_sk1        text,
  status_oborudovaniya1   text,
  tip_sk_po_dogovoru1     text,
  id_sk2                  text,
  naimenovanie_sk2        text,
  status_oborudovaniya2   text,
  tip_sk_po_dogovoru2     text,
  id_sk3                  text,
  naimenovanie_sk3        text,
  status_oborudovaniya3   text,
  tip_sk_po_dogovoru3     text,
  id_sk4                  text,
  naimenovanie_sk4        text,
  status_oborudovaniya4   text,
  tip_sk_po_dogovoru4     text,
  id_sk5                  text,
  naimenovanie_sk5        text,
  status_oborudovaniya5   text,
  tip_sk_po_dogovoru5     text,
  id_sk6                  text,
  naimenovanie_sk6        text,
  status_oborudovaniya6   text,
  tip_sk_po_dogovoru6     text,
  is_archived             boolean     DEFAULT false,
  short_id                integer,
  actual_completion_date  timestamptz,
  CONSTRAINT installations_pkey PRIMARY KEY (id)
);

-- ---- jobs ----
CREATE TABLE IF NOT EXISTS public.jobs (
  id               uuid        NOT NULL DEFAULT uuid_generate_v4(),
  title            text,
  description      text,
  status           text        DEFAULT 'pending'::text,
  engineer_id      uuid,
  chat_id          uuid,
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now(),
  planned_duration interval,
  address          text,
  CONSTRAINT jobs_pkey PRIMARY KEY (id)
);

-- ---- chat_members ----
CREATE TABLE IF NOT EXISTS public.chat_members (
  chat_id   uuid        NOT NULL,
  user_id   uuid        NOT NULL,
  joined_at timestamptz DEFAULT now(),
  role      text        DEFAULT 'member'::text,
  CONSTRAINT chat_members_pkey PRIMARY KEY (chat_id, user_id)
);

-- ---- messages ----
CREATE TABLE IF NOT EXISTS public.messages (
  id          uuid        NOT NULL DEFAULT uuid_generate_v4(),
  chat_id     uuid,
  sender_id   uuid,
  content     text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  is_deleted  boolean     DEFAULT false,
  reply_to_id uuid,
  attachments jsonb       DEFAULT '[]'::jsonb,
  CONSTRAINT messages_pkey PRIMARY KEY (id)
);

-- ---- message_read_receipts ----
CREATE TABLE IF NOT EXISTS public.message_read_receipts (
  message_id uuid        NOT NULL,
  user_id    uuid        NOT NULL,
  read_at    timestamptz DEFAULT now(),
  CONSTRAINT message_read_receipts_pkey PRIMARY KEY (message_id, user_id)
);

-- ---- comments ----
CREATE TABLE IF NOT EXISTS public.comments (
  id                uuid        NOT NULL DEFAULT uuid_generate_v4(),
  entity_type       text        NOT NULL,
  entity_id         uuid        NOT NULL,
  user_id           uuid,
  content           text,
  created_at        timestamptz DEFAULT now(),
  updated_at        timestamptz DEFAULT now(),
  parent_comment_id uuid,
  is_deleted        boolean     DEFAULT false,
  attachments       jsonb       DEFAULT '[]'::jsonb,
  mentions          uuid[]      DEFAULT '{}'::uuid[],
  CONSTRAINT comments_pkey PRIMARY KEY (id)
);

-- ---- equipment_changes ----
CREATE TABLE IF NOT EXISTS public.equipment_changes (
  id             uuid        NOT NULL DEFAULT uuid_generate_v4(),
  task_id        uuid,
  changed_by     uuid,
  change_type    text,
  old_value      jsonb,
  new_value      jsonb,
  changed_at     timestamptz DEFAULT now(),
  field_name     text,
  comment        text,
  before_status  text,
  after_status   text,
  serial_number  text,
  equipment_type text,
  CONSTRAINT equipment_changes_pkey PRIMARY KEY (id)
);

-- ---- notification_queue ----
CREATE TABLE IF NOT EXISTS public.notification_queue (
  id             uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id        uuid,
  title          text,
  body           text,
  data           jsonb       DEFAULT '{}'::jsonb,
  created_at     timestamptz DEFAULT now(),
  sent           boolean     DEFAULT false,
  sent_at        timestamptz,
  reference_id   uuid,
  reference_type text,
  CONSTRAINT notification_queue_pkey PRIMARY KEY (id)
);

-- ---- user_push_subs ----
CREATE TABLE IF NOT EXISTS public.user_push_subs (
  id         uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id    uuid,
  endpoint   text        NOT NULL,
  p256dh     text,
  auth       text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT user_push_subs_pkey PRIMARY KEY (id),
  CONSTRAINT user_push_subs_endpoint_key UNIQUE (endpoint)
);

-- ---- user_locations ----
CREATE TABLE IF NOT EXISTS public.user_locations (
  id          uuid             NOT NULL DEFAULT gen_random_uuid(),
  user_id     uuid,
  latitude    double precision,
  longitude   double precision,
  accuracy    double precision,
  recorded_at timestamptz      DEFAULT now(),
  CONSTRAINT user_locations_pkey PRIMARY KEY (id)
);

-- ---- materials ----
CREATE TABLE IF NOT EXISTS public.materials (
  id           uuid          NOT NULL DEFAULT gen_random_uuid(),
  name         text          NOT NULL,
  unit         text          DEFAULT 'шт'::text,
  quantity     numeric(12,3) DEFAULT 0,
  min_quantity numeric(12,3) DEFAULT 0,
  description  text,
  category     text,
  created_at   timestamptz   DEFAULT now(),
  updated_at   timestamptz   DEFAULT now(),
  CONSTRAINT materials_pkey PRIMARY KEY (id),
  CONSTRAINT materials_name_key UNIQUE (name)
);

-- ---- warehouse ----
CREATE TABLE IF NOT EXISTS public.warehouse (
  id          uuid          NOT NULL DEFAULT gen_random_uuid(),
  material_id uuid,
  quantity    numeric(12,3) DEFAULT 0,
  location    text,
  updated_at  timestamptz   DEFAULT now(),
  CONSTRAINT warehouse_pkey PRIMARY KEY (id)
);

-- ---- materials_requests ----
CREATE TABLE IF NOT EXISTS public.materials_requests (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  requester_id uuid,
  status       text        DEFAULT 'pending'::text,
  created_at   timestamptz DEFAULT now(),
  updated_at   timestamptz DEFAULT now(),
  comment      text,
  short_id     text,
  CONSTRAINT materials_requests_pkey PRIMARY KEY (id)
);

-- ---- materials_request_items ----
CREATE TABLE IF NOT EXISTS public.materials_request_items (
  id          uuid          NOT NULL DEFAULT gen_random_uuid(),
  request_id  uuid,
  material_id uuid,
  quantity    numeric(12,3),
  unit        text,
  name        text,
  CONSTRAINT materials_request_items_pkey PRIMARY KEY (id)
);

-- ---- materials_usage ----
CREATE TABLE IF NOT EXISTS public.materials_usage (
  id          uuid          NOT NULL DEFAULT gen_random_uuid(),
  material_id uuid,
  task_id     uuid,
  user_id     uuid,
  quantity    numeric(12,3),
  used_at     timestamptz   DEFAULT now(),
  note        text,
  CONSTRAINT materials_usage_pkey PRIMARY KEY (id)
);

-- ---- purchase_requests ----
CREATE TABLE IF NOT EXISTS public.purchase_requests (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  requester_id uuid,
  status       text        DEFAULT 'pending'::text,
  created_at   timestamptz DEFAULT now(),
  updated_at   timestamptz DEFAULT now(),
  comment      text,
  short_id     text,
  approved_by  uuid,
  approved_at  timestamptz,
  CONSTRAINT purchase_requests_pkey PRIMARY KEY (id)
);

-- ---- purchase_request_items ----
CREATE TABLE IF NOT EXISTS public.purchase_request_items (
  id          uuid          NOT NULL DEFAULT gen_random_uuid(),
  request_id  uuid,
  material_id uuid,
  quantity    numeric(12,3),
  unit        text,
  name        text,
  price       numeric(12,2),
  CONSTRAINT purchase_request_items_pkey PRIMARY KEY (id)
);

-- ---- id_counters ----
CREATE TABLE IF NOT EXISTS public.id_counters (
  entity_type text   NOT NULL,
  last_id     bigint DEFAULT 0,
  CONSTRAINT id_counters_pkey PRIMARY KEY (entity_type)
);

-- ---- manual_addresses ----
CREATE TABLE IF NOT EXISTS public.manual_addresses (
  id         uuid        NOT NULL DEFAULT gen_random_uuid(),
  address    text,
  rayon      text,
  created_at timestamptz DEFAULT now(),
  created_by uuid,
  CONSTRAINT manual_addresses_pkey PRIMARY KEY (id)
);

-- ---- archive ----
CREATE TABLE IF NOT EXISTS public.archive (
  id            uuid        NOT NULL DEFAULT gen_random_uuid(),
  original_type text        NOT NULL,
  original_id   uuid        NOT NULL,
  original_data jsonb       NOT NULL,
  archived_at   timestamptz DEFAULT now(),
  archived_by   uuid,
  reason        text        DEFAULT 'auto_archive_24h'::text,
  CONSTRAINT archive_pkey PRIMARY KEY (id),
  CONSTRAINT archive_original_type_original_id_key UNIQUE (original_type, original_id)
);

-- ---- kasip_azm_q1_2026 ----
CREATE TABLE IF NOT EXISTS public.kasip_azm_q1_2026 (
  id             uuid        NOT NULL DEFAULT gen_random_uuid(),
  equipment_name text,
  plan_count     integer     DEFAULT 0,
  fact_count     integer     DEFAULT 0,
  q1_2026_plan   integer     DEFAULT 0,
  q1_2026_fact   integer     DEFAULT 0,
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now(),
  CONSTRAINT kasip_azm_q1_2026_pkey PRIMARY KEY (id)
);

-- ==========================
-- 2. ВНЕШНИЕ КЛЮЧИ (Foreign Keys)
-- ==========================

-- Users ↔ Auth
ALTER TABLE public.users
  ADD CONSTRAINT users_auth_user_id_fkey
  FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Tasks ↔ Projects
ALTER TABLE public.tasks
  ADD CONSTRAINT tasks_project_id_fkey
  FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;

-- Tasks ↔ Users (assignee)
ALTER TABLE public.tasks
  ADD CONSTRAINT tasks_assignee_id_fkey
  FOREIGN KEY (assignee_id) REFERENCES public.users(id) ON DELETE SET NULL;

-- Tasks ↔ Users (created_by)
ALTER TABLE public.tasks
  ADD CONSTRAINT tasks_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;

-- Tasks AVR ↔ Projects
ALTER TABLE public.tasks_avr
  ADD CONSTRAINT tasks_avr_project_id_fkey
  FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;

-- Tasks AVR ↔ Users
ALTER TABLE public.tasks_avr
  ADD CONSTRAINT tasks_avr_assignee_id_fkey
  FOREIGN KEY (assignee_id) REFERENCES public.users(id) ON DELETE SET NULL;

-- Tasks AVR ↔ Users (created_by)
ALTER TABLE public.tasks_avr
  ADD CONSTRAINT tasks_avr_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;

-- Installations ↔ Projects
ALTER TABLE public.installations
  ADD CONSTRAINT installations_project_id_fkey
  FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE SET NULL;

-- Installations ↔ Users
ALTER TABLE public.installations
  ADD CONSTRAINT installations_assignee_id_fkey
  FOREIGN KEY (assignee_id) REFERENCES public.users(id) ON DELETE SET NULL;

-- Installations ↔ Users (created_by)
ALTER TABLE public.installations
  ADD CONSTRAINT installations_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;

-- Jobs ↔ Users
ALTER TABLE public.jobs
  ADD CONSTRAINT jobs_engineer_id_fkey
  FOREIGN KEY (engineer_id) REFERENCES public.users(id) ON DELETE SET NULL;

-- Jobs ↔ Chats
ALTER TABLE public.jobs
  ADD CONSTRAINT jobs_chat_id_fkey
  FOREIGN KEY (chat_id) REFERENCES public.chats(id) ON DELETE SET NULL;

-- Chat Members ↔ Chats
ALTER TABLE public.chat_members
  ADD CONSTRAINT chat_members_chat_id_fkey
  FOREIGN KEY (chat_id) REFERENCES public.chats(id) ON DELETE CASCADE;

-- Chat Members ↔ Users
ALTER TABLE public.chat_members
  ADD CONSTRAINT chat_members_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Messages ↔ Chats
ALTER TABLE public.messages
  ADD CONSTRAINT messages_chat_id_fkey
  FOREIGN KEY (chat_id) REFERENCES public.chats(id) ON DELETE CASCADE;

-- Messages ↔ Users
ALTER TABLE public.messages
  ADD CONSTRAINT messages_sender_id_fkey
  FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE SET NULL;

-- Messages ↔ Messages (reply)
ALTER TABLE public.messages
  ADD CONSTRAINT messages_reply_to_id_fkey
  FOREIGN KEY (reply_to_id) REFERENCES public.messages(id) ON DELETE SET NULL;

-- Message Read Receipts ↔ Messages
ALTER TABLE public.message_read_receipts
  ADD CONSTRAINT message_read_receipts_message_id_fkey
  FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;

-- Message Read Receipts ↔ Users
ALTER TABLE public.message_read_receipts
  ADD CONSTRAINT message_read_receipts_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Comments ↔ Users
ALTER TABLE public.comments
  ADD CONSTRAINT comments_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;

-- Comments ↔ Comments (parent)
ALTER TABLE public.comments
  ADD CONSTRAINT comments_parent_comment_id_fkey
  FOREIGN KEY (parent_comment_id) REFERENCES public.comments(id) ON DELETE CASCADE;

-- Equipment Changes ↔ Tasks AVR
ALTER TABLE public.equipment_changes
  ADD CONSTRAINT equipment_changes_task_id_fkey
  FOREIGN KEY (task_id) REFERENCES public.tasks_avr(id) ON DELETE CASCADE;

-- Equipment Changes ↔ Users
ALTER TABLE public.equipment_changes
  ADD CONSTRAINT equipment_changes_changed_by_fkey
  FOREIGN KEY (changed_by) REFERENCES public.users(id) ON DELETE SET NULL;

-- Notification Queue ↔ Users
ALTER TABLE public.notification_queue
  ADD CONSTRAINT notification_queue_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- User Push Subs ↔ Users
ALTER TABLE public.user_push_subs
  ADD CONSTRAINT user_push_subs_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- User Locations ↔ Users
ALTER TABLE public.user_locations
  ADD CONSTRAINT user_locations_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Warehouse ↔ Materials
ALTER TABLE public.warehouse
  ADD CONSTRAINT warehouse_material_id_fkey
  FOREIGN KEY (material_id) REFERENCES public.materials(id) ON DELETE CASCADE;

-- Materials Request Items ↔ Requests
ALTER TABLE public.materials_request_items
  ADD CONSTRAINT materials_request_items_request_id_fkey
  FOREIGN KEY (request_id) REFERENCES public.materials_requests(id) ON DELETE CASCADE;

-- Materials Request Items ↔ Materials
ALTER TABLE public.materials_request_items
  ADD CONSTRAINT materials_request_items_material_id_fkey
  FOREIGN KEY (material_id) REFERENCES public.materials(id) ON DELETE SET NULL;

-- Materials Usage ↔ Materials
ALTER TABLE public.materials_usage
  ADD CONSTRAINT materials_usage_material_id_fkey
  FOREIGN KEY (material_id) REFERENCES public.materials(id) ON DELETE CASCADE;

-- Materials Usage ↔ Tasks
ALTER TABLE public.materials_usage
  ADD CONSTRAINT materials_usage_task_id_fkey
  FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE SET NULL;

-- Materials Usage ↔ Users
ALTER TABLE public.materials_usage
  ADD CONSTRAINT materials_usage_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;

-- Purchase Request Items ↔ Requests
ALTER TABLE public.purchase_request_items
  ADD CONSTRAINT purchase_request_items_request_id_fkey
  FOREIGN KEY (request_id) REFERENCES public.purchase_requests(id) ON DELETE CASCADE;

-- Purchase Request Items ↔ Materials
ALTER TABLE public.purchase_request_items
  ADD CONSTRAINT purchase_request_items_material_id_fkey
  FOREIGN KEY (material_id) REFERENCES public.materials(id) ON DELETE SET NULL;

-- Purchase Requests ↔ Users (requester)
ALTER TABLE public.purchase_requests
  ADD CONSTRAINT purchase_requests_requester_id_fkey
  FOREIGN KEY (requester_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Purchase Requests ↔ Users (approved_by)
ALTER TABLE public.purchase_requests
  ADD CONSTRAINT purchase_requests_approved_by_fkey
  FOREIGN KEY (approved_by) REFERENCES public.users(id) ON DELETE SET NULL;

-- Manual Addresses ↔ Users
ALTER TABLE public.manual_addresses
  ADD CONSTRAINT manual_addresses_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;

-- Archive ↔ Users
ALTER TABLE public.archive
  ADD CONSTRAINT archive_archived_by_fkey
  FOREIGN KEY (archived_by) REFERENCES public.users(id) ON DELETE SET NULL;

-- ==========================
-- 3. ИНДЕКСЫ (Основные)
-- ==========================

-- Users
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON public.users(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_is_online ON public.users(is_online);

-- Tasks
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON public.tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee_id ON public.tasks(assignee_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON public.tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_is_archived ON public.tasks(is_archived);
CREATE INDEX IF NOT EXISTS idx_tasks_short_id ON public.tasks(short_id);

-- Tasks AVR
CREATE INDEX IF NOT EXISTS idx_tasks_avr_project_id ON public.tasks_avr(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_avr_assignee_id ON public.tasks_avr(assignee_id);
CREATE INDEX IF NOT EXISTS idx_tasks_avr_status ON public.tasks_avr(status);
CREATE INDEX IF NOT EXISTS idx_tasks_avr_short_id ON public.tasks_avr(short_id);

-- Installations
CREATE INDEX IF NOT EXISTS idx_installations_project_id ON public.installations(project_id);
CREATE INDEX IF NOT EXISTS idx_installations_assignee_id ON public.installations(assignee_id);
CREATE INDEX IF NOT EXISTS idx_installations_status ON public.installations(status);
CREATE INDEX IF NOT EXISTS idx_installations_short_id ON public.installations(short_id);

-- Jobs
CREATE INDEX IF NOT EXISTS idx_jobs_engineer_id ON public.jobs(engineer_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON public.jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_chat_id ON public.jobs(chat_id);

-- Messages
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON public.messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);

-- Chat Members
CREATE INDEX IF NOT EXISTS idx_chat_members_user_id ON public.chat_members(user_id);

-- Comments
CREATE INDEX IF NOT EXISTS idx_comments_entity ON public.comments(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON public.comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON public.comments(parent_comment_id);

-- Materials Requests
CREATE INDEX IF NOT EXISTS idx_materials_requests_requester_id ON public.materials_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_materials_requests_status ON public.materials_requests(status);
CREATE INDEX IF NOT EXISTS idx_materials_requests_short_id ON public.materials_requests(short_id);

-- Materials Request Items
CREATE INDEX IF NOT EXISTS idx_materials_request_items_request_id ON public.materials_request_items(request_id);
CREATE INDEX IF NOT EXISTS idx_materials_request_items_material_id ON public.materials_request_items(material_id);

-- Purchase Requests
CREATE INDEX IF NOT EXISTS idx_purchase_requests_requester_id ON public.purchase_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_purchase_requests_status ON public.purchase_requests(status);

-- Purchase Request Items
CREATE INDEX IF NOT EXISTS idx_purchase_request_items_request_id ON public.purchase_request_items(request_id);

-- Warehouse
CREATE INDEX IF NOT EXISTS idx_warehouse_material_id ON public.warehouse(material_id);

-- Notifications
CREATE INDEX IF NOT EXISTS idx_notification_queue_user_id ON public.notification_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_queue_sent ON public.notification_queue(sent);

-- User Push Subs
CREATE INDEX IF NOT EXISTS idx_user_push_subs_user_id ON public.user_push_subs(user_id);

-- User Locations
CREATE INDEX IF NOT EXISTS idx_user_locations_user_id ON public.user_locations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_locations_recorded_at ON public.user_locations(recorded_at DESC);

-- Equipment Changes
CREATE INDEX IF NOT EXISTS idx_equipment_changes_task_id ON public.equipment_changes(task_id);
CREATE INDEX IF NOT EXISTS idx_equipment_changes_changed_at ON public.equipment_changes(changed_at DESC);

-- Archive
CREATE INDEX IF NOT EXISTS idx_archive_original_type ON public.archive(original_type);
CREATE INDEX IF NOT EXISTS idx_archive_archived_at ON public.archive(archived_at DESC);

-- ==========================
-- 4. RLS ПОЛИТИКИ (Row Level Security)
-- ==========================

-- Включаем RLS для всех таблиц
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks_avr ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.installations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_read_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_subs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.manual_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.archive ENABLE ROW LEVEL SECURITY;

-- ---- USERS RLS ----
-- Чтение все авторизованные
CREATE POLICY "Users readable by authenticated" ON public.users
  FOR SELECT TO authenticated
  USING (true);

-- Вставка себе при регистрации
CREATE POLICY "Users insert for registration" ON public.users
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

-- Обновление своего профиля
CREATE POLICY "Users update own profile" ON public.users
  FOR UPDATE TO authenticated
  USING (auth.uid() = id);

-- ---- PROJECTS RLS ----
-- Чтение все авторизованные
CREATE POLICY "Projects readable by authenticated" ON public.projects
  FOR SELECT TO authenticated
  USING (true);

-- Вставка/Обновление только manager, deputy_head, admin, engineer
CREATE POLICY "Projects modify by roles" ON public.projects
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin', 'engineer')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin', 'engineer')
    )
  );

-- ---- CHATS RLS ----
-- Чтение чатов (участник)
CREATE POLICY "Chats readable by members" ON public.chats
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_members
      WHERE chat_id = id AND user_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('manager', 'deputy_head', 'admin')
    )
  );

-- Вставка чата
CREATE POLICY "Chats insert" ON public.chats
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = created_by);

-- ---- TASKS RLS ----
-- Чтение все авторизованные
CREATE POLICY "Tasks readable by authenticated" ON public.tasks
  FOR SELECT TO authenticated
  USING (true);

-- Вставка engineer+
CREATE POLICY "Tasks insert by engineers" ON public.tasks
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('engineer', 'manager', 'deputy_head', 'admin')
    )
  );

-- Обновление (назначенный, создатель, manager+)
CREATE POLICY "Tasks update" ON public.tasks
  FOR UPDATE TO authenticated
  USING (
    assignee_id = auth.uid() OR
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin')
    )
  );

-- Удаление manager+
CREATE POLICY "Tasks delete by managers" ON public.tasks
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin')
    )
  );

-- ---- TASKS_AVR RLS ----
CREATE POLICY "Tasks AVR readable" ON public.tasks_avr
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Tasks AVR insert" ON public.tasks_avr
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('engineer', 'manager', 'deputy_head', 'admin')
    )
  );

CREATE POLICY "Tasks AVR update" ON public.tasks_avr
  FOR UPDATE TO authenticated
  USING (
    assignee_id = auth.uid() OR
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin')
    )
  );

-- ---- INSTALLATIONS RLS ----
CREATE POLICY "Installations readable" ON public.installations
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Installations insert" ON public.installations
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('engineer', 'manager', 'deputy_head', 'admin')
    )
  );

CREATE POLICY "Installations update" ON public.installations
  FOR UPDATE TO authenticated
  USING (
    assignee_id = auth.uid() OR
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin')
    )
  );

-- ---- MESSAGES RLS ----
-- Чтение сообщений (участник чата)
CREATE POLICY "Messages readable" ON public.messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_members cm
      JOIN public.messages m ON m.chat_id = cm.chat_id
      WHERE m.id = messages.id AND cm.user_id = auth.uid()
    )
    OR sender_id = auth.uid()
  );

-- Вставка сообщений (участник чата)
CREATE POLICY "Messages insert" ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.chat_members
      WHERE chat_id = messages.chat_id AND user_id = auth.uid()
    )
  );

-- Обновление своих сообщений
CREATE POLICY "Messages update own" ON public.messages
  FOR UPDATE TO authenticated
  USING (sender_id = auth.uid());

-- Удаление своих сообщений
CREATE POLICY "Messages delete own" ON public.messages
  FOR DELETE TO authenticated
  USING (sender_id = auth.uid());

-- ---- COMMENTS RLS ----
CREATE POLICY "Comments readable" ON public.comments
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Comments insert" ON public.comments
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Comments update own" ON public.comments
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Comments delete own" ON public.comments
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ---- MATERIALS RLS ----
CREATE POLICY "Materials readable" ON public.materials
  FOR SELECT TO authenticated
  USING (true);

-- Изменение только manager+
CREATE POLICY "Materials modify" ON public.materials
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin')
    )
  );

-- ---- MATERIALS_REQUESTS RLS ----
CREATE POLICY "Materials requests readable" ON public.materials_requests
  FOR SELECT TO authenticated
  USING (
    requester_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin')
    )
  );

CREATE POLICY "Materials requests insert" ON public.materials_requests
  FOR INSERT TO authenticated
  WITH CHECK (requester_id = auth.uid());

CREATE POLICY "Materials requests update" ON public.materials_requests
  FOR UPDATE TO authenticated
  USING (
    requester_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin')
    )
  );

-- ---- PURCHASE_REQUESTS RLS ----
CREATE POLICY "Purchase requests readable" ON public.purchase_requests
  FOR SELECT TO authenticated
  USING (
    requester_id = auth.uid() OR
    approved_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin')
    )
  );

CREATE POLICY "Purchase requests insert" ON public.purchase_requests
  FOR INSERT TO authenticated
  WITH CHECK (requester_id = auth.uid());

CREATE POLICY "Purchase requests update" ON public.purchase_requests
  FOR UPDATE TO authenticated
  USING (
    requester_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid()
      AND role IN ('manager', 'deputy_head', 'admin')
    )
  );

-- ==========================
-- 5. ТРИГГЕРЫ И ФУНКЦИИ
-- ==========================

-- ---- Триггер: автоматическое создание профиля пользователя ----
CREATE OR REPLACE FUNCTION public.create_user_profile()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, name, auth_user_id, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'role', 'worker')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.create_user_profile();

-- ---- Триггер: обновление updated_at ----
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON public.projects
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tasks_avr_updated_at BEFORE UPDATE ON public.tasks_avr
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_installations_updated_at BEFORE UPDATE ON public.installations
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_messages_updated_at BEFORE UPDATE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_materials_updated_at BEFORE UPDATE ON public.materials
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ---- Функция: автоматическая архивация завершённых задач ----
CREATE OR REPLACE FUNCTION public.archive_completed_tasks()
RETURNS void AS $$
BEGIN
  -- Копируем в archive
  INSERT INTO public.archive (original_type, original_id, original_data, archived_by)
  SELECT 
    'task',
    t.id,
    to_jsonb(t),
    'system'::uuid
  FROM public.tasks t
  WHERE t.status = 'completed'
    AND t.updated_at < NOW() - INTERVAL '24 hours'
    AND t.is_archived = false;
  
  -- Помечаем как архивированные
  UPDATE public.tasks 
  SET is_archived = true 
  WHERE status = 'completed' 
    AND updated_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---- Функция: генерация короткого ID для задач ----
CREATE OR REPLACE FUNCTION public.generate_task_short_id()
RETURNS trigger AS $$
DECLARE
  next_id INTEGER;
BEGIN
  -- Получаем следующий ID
  SELECT COALESCE(last_id, 0) + 1 INTO next_id
  FROM public.id_counters
  WHERE entity_type = 'task'
  FOR UPDATE;
  
  -- Если не существует, создаём
  IF next_id IS NULL THEN
    next_id := 1;
    INSERT INTO public.id_counters (entity_type, last_id)
    VALUES ('task', 1);
  ELSE
    UPDATE public.id_counters
    SET last_id = next_id
    WHERE entity_type = 'task';
  END IF;
  
  NEW.short_id = next_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_task_insert
  BEFORE INSERT ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.generate_task_short_id();

-- ---- Функция: генерация короткого ID для задач АВР ----
CREATE OR REPLACE FUNCTION public.generate_task_avr_short_id()
RETURNS trigger AS $$
DECLARE
  next_id INTEGER;
BEGIN
  SELECT COALESCE(last_id, 0) + 1 INTO next_id
  FROM public.id_counters
  WHERE entity_type = 'task_avr'
  FOR UPDATE;
  
  IF next_id IS NULL THEN
    next_id := 1;
    INSERT INTO public.id_counters (entity_type, last_id)
    VALUES ('task_avr', 1);
  ELSE
    UPDATE public.id_counters
    SET last_id = next_id
    WHERE entity_type = 'task_avr';
  END IF;
  
  NEW.short_id = next_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_task_avr_insert
  BEFORE INSERT ON public.tasks_avr
  FOR EACH ROW EXECUTE FUNCTION public.generate_task_avr_short_id();

-- ---- Функция: генерация короткого ID для монтажей ----
CREATE OR REPLACE FUNCTION public.generate_installation_short_id()
RETURNS trigger AS $$
DECLARE
  next_id INTEGER;
BEGIN
  SELECT COALESCE(last_id, 0) + 1 INTO next_id
  FROM public.id_counters
  WHERE entity_type = 'installation'
  FOR UPDATE;
  
  IF next_id IS NULL THEN
    next_id := 1;
    INSERT INTO public.id_counters (entity_type, last_id)
    VALUES ('installation', 1);
  ELSE
    UPDATE public.id_counters
    SET last_id = next_id
    WHERE entity_type = 'installation';
  END IF;
  
  NEW.short_id = next_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_installation_insert
  BEFORE INSERT ON public.installations
  FOR EACH ROW EXECUTE FUNCTION public.generate_installation_short_id();

-- ==========================
-- 6. REALTIME ПУБЛИКАЦИЯ
-- ==========================

-- Включаем realtime для таблиц
ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks_avr;
ALTER PUBLICATION supabase_realtime ADD TABLE public.installations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.comments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.materials_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE public.purchase_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;

-- ==========================
-- 7. НАЧАЛЬНЫЕ ДАННЫЕ
-- ==========================

-- Счётчики ID
INSERT INTO public.id_counters (entity_type, last_id)
VALUES 
  ('task', 0),
  ('task_avr', 0),
  ('installation', 0),
  ('project', 0),
  ('materials_request', 0),
  ('purchase_request', 0)
ON CONFLICT (entity_type) DO NOTHING;

-- ==========================
-- КОНЕЦ СХЕМЫ
-- ==========================
