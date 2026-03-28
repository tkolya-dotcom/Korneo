# 📦 Инструкция по развёртыванию БД в Supabase

## 🚀 Быстрый старт

### Шаг 1: Создание проекта Supabase

1. Перейдите на [supabase.com](https://supabase.com)
2. Войдите через GitHub
3. Нажмите **"New Project"**
4. Заполните:
   - **Name:** `task-manager-app` (или любое другое)
   - **Database Password:** надёжный пароль (сохраните!)
   - **Region:** выберите ближайший к вам
5. Нажмите **"Create new project"**

⏱️ Ожидание: ~2-5 минут

---

### Шаг 2: Получение реквизитов доступа

После создания проекта:

1. Перейдите в **Settings** → **API**
2. Скопируйте:
   - **Project URL:** `https://jmxjbdnqnzkzxgsfywha.supabase.co`
   - **Anon/Public Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
   - **Service Role Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (секретный!)

⚠️ **Важно:** Service Role Key храните в секрете!

---

### Шаг 3: Выполнение SQL дампа

#### Вариант А: Через SQL Editor (рекомендуется)

1. В панели Supabase перейдите в **SQL Editor**
2. Нажмите **"New Query"**
3. Откройте файл `docs/schema.sql`
4. Скопируйте всё содержимое
5. Вставьте в SQL Editor
6. Нажмите **"Run"** или `Ctrl+Enter`
7. ⏱️ Ожидание: ~10-30 секунд

✅ Успех: Сообщение "Success. No rows returned"

#### Вариант Б: Через psql (для продвинутых)

```bash
# Подключение к базе
psql -h db.jmxjbdnqnzkzxgsfywha.supabase.co \
  -U postgres \
  -d postgres \
  -f docs/schema.sql
```

---

### Шаг 4: Проверка установки

#### 4.1: Проверка таблиц

1. Перейдите в **Table Editor**
2. Убедитесь, что создано **29 таблиц**:
   ```
   users, projects, chats, tasks, tasks_avr, installations,
   jobs, chat_members, messages, message_read_receipts,
   comments, equipment_changes, notification_queue,
   user_push_subs, user_locations, materials, warehouse,
   materials_requests, materials_request_items, materials_usage,
   purchase_requests, purchase_request_items, id_counters,
   manual_addresses, archive, kasip_azm_q1_2026
   ```

#### 4.2: Проверка RLS политик

```sql
-- Проверка RLS
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;
```

✅ Все таблицы должны иметь `rowsecurity = true`

#### 4.3: Проверка триггеров

```sql
-- Проверка триггеров
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_schema = 'public';
```

✅ Должно быть **13+ триггеров**

---

### Шаг 5: Настройка CORS

По умолчанию Supabase разрешает все CORS запросы с авторизацией.

Для проверки:

1. Перейдите в **Settings** → **API**
2. Прокрутите до **CORS**
3. Убедитесь, что стоит галочка **"Enable CORS for all origins"**

⚠️ Для продакшена лучше указать конкретные origin:
```
https://tkolya-dotcom.github.io
```

---

### Шаг 6: Создание первого пользователя

#### Через Sign Up форму:

1. Перейдите в **Authentication** → **Users**
2. Нажмите **"Add User"**
3. Введите:
   - **Email:** `admin@korneo.ru` (или ваш)
   - **Password:** надёжный пароль (мин. 6 символов)
   - **Confirm Password:** повторите пароль
4. Нажмите **"Add User"**

✅ Пользователь создан!

#### Ручное присвоение роли admin:

После регистрации пользователь получит роль `worker` по умолчанию.

Для изменения роли:

```sql
-- Изменение роли пользователя
UPDATE public.users
SET role = 'admin'
WHERE email = 'admin@korneo.ru';
```

Проверка:

```sql
SELECT email, name, role FROM public.users;
```

---

### Шаг 7: Тестирование подключения

#### Проверка аутентификации:

```javascript
// Создайте тестовый файл test-auth.js
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm'

const supabaseUrl = 'https://jmxjbdnqnzkzxgsfywha.supabase.co'
const supabaseKey = 'YOUR_ANON_KEY' // вставьте свой Anon Key

const supabase = createClient(supabaseUrl, supabaseKey)

// Тест входа
async function testLogin() {
  const { data, error } = await supabase.auth.signInWithPassword({
    email: 'admin@korneo.ru',
    password: 'ВАШ_ПАРОЛЬ'
  })
  
  if (error) {
    console.error('❌ Ошибка:', error.message)
  } else {
    console.log('✅ Успешный вход!')
    console.log('User:', data.user)
    console.log('Session:', data.session)
  }
}

testLogin()
```

#### Проверка чтения данных:

```javascript
// Тест чтения задач
async function testTasks() {
  const { data, error } = await supabase
    .from('tasks')
    .select('*')
  
  if (error) {
    console.error('❌ Ошибка:', error.message)
  } else {
    console.log('✅ Задачи получены:', data.length)
  }
}

testTasks()
```

---

## 🔧 Дополнительные настройки

### Включение Realtime

Realtime уже включён для основных таблиц в схеме.

Проверка:

```sql
-- Проверка realtime публикаций
SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime';
```

Если таблица отсутствует в публикации:

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks;
```

### Настройка Storage (бакеты для файлов)

1. Перейдите в **Storage**
2. Нажмите **"New Bucket"**
3. Name: `attachments`
4. Public: false (приватный)
5. Create

RLS политики для Storage:

```sql
-- Разрешить загрузку авторизованным
CREATE POLICY "Attachments upload"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'attachments');

-- Чтение своих файлов
CREATE POLICY "Attachments read own"
ON storage.objects FOR SELECT TO authenticated
USING (owner = auth.uid());
```

### Edge Functions (опционально)

Для отправки Push-уведомлений через FCM:

1. Установите Supabase CLI:
   ```bash
   npm install -g supabase
   ```

2. Войдите:
   ```bash
   supabase login
   ```

3. Создайте функцию:
   ```bash
   supabase functions new push-send
   ```

4. Разместите код в `supabase/functions/push-send/index.ts`

5. Задеплойте:
   ```bash
   supabase functions deploy push-send
   ```

---

## 📊 Мониторинг и логи

### Просмотр логов

1. Перейдите в **Logs**
2. Фильтры:
   - **Auth Logs:** аутентификация
   - **Function Logs:** Edge Functions
   - **Postgres Logs:** запросы к БД

### Мониторинг использования

1. **Dashboard** → обзор использования
2. Следите за:
   - Database size (лимит 500MB на free тарифе)
   - Bandwidth (лимит 2GB/month)
   - Function invocations

---

## 🆘 Troubleshooting

### Ошибка: "permission denied for table"

**Причина:** RLS блокирует доступ

**Решение:**
```sql
-- Проверка текущей роли
SELECT auth.role();

-- Проверка RLS политик
SELECT * FROM pg_policies WHERE schemaname = 'public';
```

### Ошибка: "relation does not exist"

**Причина:** Таблица не создана

**Решение:** Повторно выполните SQL дамп

### Ошибка CORS

**Решение:**
1. Проверьте настройки CORS в Supabase Dashboard
2. Убедитесь, что используете правильный URL проекта
3. Проверьте, что токен передаётся в заголовке

### Пользователь не может войти

**Причина:** Нет связи между `auth.users` и `public.users`

**Решение:**
```sql
-- Проверка связи
SELECT u.email, u.auth_user_id, au.id
FROM public.users u
LEFT JOIN auth.users au ON u.auth_user_id = au.id
WHERE u.email = 'user@example.com';

-- Если auth_user_id NULL, обновите:
UPDATE public.users
SET auth_user_id = (
  SELECT id FROM auth.users WHERE email = 'user@example.com'
)
WHERE email = 'user@example.com';
```

---

## 📋 Чек-лист готовности

- [ ] Проект Supabase создан
- [ ] SQL дамп выполнен успешно
- [ ] 29 таблиц создано
- [ ] RLS политики активны
- [ ] Триггеры работают
- [ ] Первый пользователь создан
- [ ] Аутентификация работает
- [ ] Realtime включён
- [ ] CORS настроен
- [ ] Тесты пройдены

---

## 🔐 Безопасность

### Рекомендации:

1. **Не коммитьте Service Role Key** в git
2. Используйте `.env` для локальной разработки
3. Регулярно делайте backup:
   ```bash
   pg_dump -h db.jmxjbdnqnzkzxgsfywha.supabase.co \
     -U postgres > backup_$(date +%Y%m%d).sql
   ```

4. Включите 2FA для аккаунта Supabase
5. Мониторьте подозрительную активность в логах

---

## 📞 Поддержка

- **Документация Supabase:** [supabase.com/docs](https://supabase.com/docs)
- **Discord сообщество:** [discord.supabase.com](https://discord.supabase.com)
- **GitHub Issues:** [github.com/supabase/supabase/issues](https://github.com/supabase/supabase/issues)

---

**Версия:** 1.0 | **Дата:** 27.03.2026
