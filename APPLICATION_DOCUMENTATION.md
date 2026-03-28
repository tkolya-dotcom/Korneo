# ООО "Корнео" - Система Управления Задачами и Монтажом
## Полное описание бизнес-процессов, интерфейса и инструкция пользователя

---

## 📋 ОГЛАВЛЕНИЕ

1. [Общее описание системы](#общее-описание-системы)
2. [Архитектура и технологии](#архитектура-и-технологии)
3. [Роли пользователей](#роли-пользователей)
4. [Бизнес-процессы](#бизнес-процессы)
5. [Описание интерфейса](#описание-интерфейса)
6. [Инструкция пользователя](#инструкция-пользователя)
7. [База данных](#база-данных)
8. [Уведомления](#уведомления)
9. [Чат и коммуникации](#чат-и-коммуникации)
10. [Материалы и заявки](#материалы-и-заявки)

---

## 🎯 ОБЩЕЕ ОПИСАНИЕ СИСТЕМЫ

### Назначение
Система предназначена для управления задачами, проектами, монтажами и коммуникациями между сотрудниками компании ООО "Корнео".

### Основные возможности
- ✅ Управление задачами (создание, назначение, отслеживание)
- ✅ Управление проектами
- ✅ Планирование и учёт монтажей
- ✅ Внутренний чат между сотрудниками
- ✅ Система уведомлений (Push + FCM)
- ✅ Заявки на материалы
- ✅ Комментарии к задачам
- ✅ Архив выполненных работ
- ✅ PWA (Progressive Web App)

### Платформы
- **Фронтенд:** GitHub Pages (https://tkolya-dotcom.github.io/task-manager-app/)
- **Бэкенд:** Supabase (PostgreSQL + Auth + Realtime)
- **PWA:** Работает на desktop и мобильных устройствах

---

## 🏗️ АРХИТЕКТУРА И ТЕХНОЛОГИИ

### Технологический стек

#### Frontend
```
HTML5 (монолитный index.html - 16500+ строк)
Vanilla JavaScript (ES6+)
CSS3 (кастомные стили)
PWA (Service Worker + Manifest)
Firebase SDK v10.7.1 (для Push-уведомлений)
Supabase JS Client (для работы с БД)
```

#### Backend (Supabase)
```
PostgreSQL 15
Supabase Auth (JWT аутентификация)
RLS (Row Level Security) политики
Realtime подписки
Edge Functions (Deno)
Storage (файлы)
```

#### База данных
```
29 таблиц
1 view
27 функций
13 триггеров
133 индекса
113 RLS политик
```

### Структура файлов проекта
```
manager supabase/
├── index.html              # Монолитное приложение (весь frontend)
├── service-worker.js       # PWA Service Worker
├── manifest.json           # PWA Manifest
├── tasks.js                # Логика задач
├── projects.js             # Логика проектов
├── installations.js        # Логика монтажей
├── materials.js            # Логика материалов
├── purchaseRequests.js     # Заявки на материалы
├── comment_system.js       # Система комментариев
├── chat.js                 # Чат
├── auth.js                 # Аутентификация
├── users.js                # Пользователи
├── schema.sql              # Схема БД
└── check_and_fix_users_rls.sql  # RLS политики
```

---

## 👥 РОЛИ ПОЛЬЗОВАТЕЛЕЙ

### 1. Worker (Рабочий)
**Права:**
- Просмотр назначенных задач
- Выполнение задач (смена статуса)
- Участие в чатах
- Просмотр материалов
- Создание заявок на материалы
- Добавление комментариев

**Ограничения:**
- Не может создавать задачи
- Не может назначать исполнителей
- Не может удалять задачи
- Не может создавать пользователей

### 2. Engineer (Инженер)
**Права:**
- Все права Worker
- Создание задач
- Редактирование своих задач
- Назначение исполнителей (worker)
- Управление монтажами

### 3. Manager (Руководитель)
**Права:**
- Все права Engineer
- Создание пользователей
- Удаление любых задач
- Доступ ко всем проектам
- Модерация чатов
- Удаление сообщений "у всех"
- Подтверждение рабочих выездов

**Ограничения:**
- Не может назначать роли manager/deputy_head

### 4. Deputy Head (Заместитель руководителя)
**Права:**
- Все права Manager
- Назначение ролей worker/engineer
- Расширенная аналитика

### 5. Admin (Администратор)
**Права:**
- Полный доступ ко всем функциям
- Управление ролями
- Настройка системы

---

## 🔄 БИЗНЕС-ПРОЦЕССЫ

### 1. Аутентификация и Регистрация

#### Вход в систему
```
1. Пользователь открывает приложение
2. Вводит email и пароль
3. Нажимает "ВОЙТИ"
4. Supabase Auth проверяет credentials
5. Получает JWT token
6. Загружает профиль из таблицы users
7. Применяет RLS политики
8. Показывает Dashboard
```

**Технические детали:**
- `supabase.auth.signInWithPassword()` → JWT session
- Token сохраняется в `localStorage`
- Session хранится в IndexedDB
- RLS фильтрует данные по роли

#### Регистрация нового пользователя
```
1. Нажимает "ЗАРЕГИСТРИРОВАТЬСЯ"
2. Вводит имя, email, пароль, роль
3. Проверка на запрещённые роли (manager, deputy_head, admin)
4. Supabase Auth создаёт запись в auth.users
5. Триггер автоматически создаёт запись в users
6. Профиль готов к работе
```

**Важно:**
- Пароль мин. 6 символов
- Email должен быть уникальным
- Роль по умолчанию: 'worker'
- Только Manager может создавать пользователей через админку

### 2. Управление задачами

#### Жизненный цикл задачи
```
NEW → IN_PROGRESS → COMPLETED → ARCHIVED
         ↓
      ON_HOLD
```

#### Статусы задач
- **new** - Новая задача (создана, не выполнена)
- **in_progress** - В работе (исполнитель начал работу)
- **on_hold** - Приостановлена (ожидание материалов/согласования)
- **completed** - Завершена (работа выполнена)
- **archived** - Архивирована (перемещена в архив через 24ч)

#### Процесс создания задачи
```
1. Engineer/Manager создаёт задачу
2. Указывает: название, описание, проект, исполнителя
3. Опционально: дедлайн, приоритет, адрес
4. Задача сохраняется в tasks
5. Realtime-подписка уведомляет исполнителя
6. Push-уведомление отправляется через FCM
```

#### Автоматическая архивация
```
Триггер каждые 24 часа:
1. Находит задачи со статусом 'completed'
2. Ждёт 24 часа после завершения
3. Копирует задачу в таблицу archive
4. Оригинальную задачу помечает is_archived=true
```

### 3. Управление монтажами

#### Особенности монтажей
Монтаж - это специфический тип работ с дополнительными полями:

**Поля:**
- `id_ploshadki` - ID площадки
- `servisnyy_id` - Сервисный ID
- `rayon` - Район
- `naimenovanie_sk` - Наименование СК (до 7 штук)
- `status_oborudovaniya` - Статус оборудования
- `tip_sk_po_dogovoru` - Тип СК по договору
- `planovaya_data_1_kv_2026` - Плановая дата

#### Статусы монтажей
- **new** - Новый монтаж
- **in_progress** - В работе
- **completed** - Завершён
- **archived** - Архивирован

#### Бизнес-правила
- Монтаж может содержать до 7 единиц оборудования (СК)
- Каждое оборудование имеет свой статус
- Привязка к проекту обязательна
- Ответственный назначается из инженеров

### 4. Задачи АВР (Аварийно-Восстановительные Работы)

#### Отличия от обычных задач
- Короткие ID (автогенерация из sequence)
- Расширенные поля оборудования
- Трекинг замены оборудования

#### Поля оборудования
```
Старое оборудование:
- mark, model, serial, inventory

Новое оборудование:
- mark, model, serial, inventory

Причина замены: change_reason
```

#### Процесс АВР
```
1. Создание задачи АВР
2. Фиксация старого оборудования
3. Установка нового оборудования
4. Указание причины замены
5. Завершение работы
6. Автоматическая генерация короткого ID
```

### 5. Материалы и Заявки

#### Каталог материалов
```
Таблица: materials
- id, name, category, default_unit
- is_optional (можно ли не использовать)
- comment (описание)
```

#### Процесс заявки на материалы
```
1. Worker создаёт заявку (materials_request)
2. Добавляет позиции (materials_request_items)
3. Указывает количество для каждой позиции
4. Manager получает уведомление
5. Manager одобряет заявку
6. Склад выдаёт материалы
7. Заявка закрывается
```

#### Статусы заявок
- **pending** - Ожидает подтверждения
- **approved** - Одобрена
- **rejected** - Отклонена
- **issued** - Выдана

### 6. Чат и Сообщения

#### Типы чатов
- **private** - Личная переписка (2 пользователя)
- **group** - Групповой чат (несколько участников)
- **job** - Чат рабочей поездки (привязан к job)

#### Структура сообщения
```json
{
  "id": "uuid",
  "chat_id": "uuid",
  "user_id": "uuid",
  "content": {"text": "..."},
  "type": "text|image|file",
  "job_id": "uuid?",
  "deleted_for": ["uuid1", "uuid2"],
  "created_at": "timestamp"
}
```

#### Удаление сообщений
**"Удалить у себя":**
- Добавляет user_id в `deleted_for[]`
- Сообщение скрывается только для этого пользователя
- Остальные продолжают видеть

**"Удалить у всех":**
- Полное удаление из базы
- Доступно только:
  - Автору сообщения
  - Manager (модерация)

### 7. Комментарии

#### Иерархия комментариев
```
Комментарий (root)
├── Ответ 1 (parent_comment_id = root.id)
├── Ответ 2
│   └── Вложенный ответ
└── Ответ 3
```

#### Ресурсы для комментирования
- **task** - Комментарии к задачам
- **installation** - Комментарии к монтажам
- **task_avr** - Комментарии к АВР задачам

#### Возможности
- Текстовые сообщения
- Прикрепление файлов (file_url, file_name)
- Редактирование (is_edited = true)
- Вложенные ответы (через parent_comment_id)

### 8. Уведомления

#### Типы уведомлений
1. **Push Notifications** (браузер)
2. **FCM** (Firebase Cloud Messaging)
3. **Realtime** (изменения в БД)

#### Механизм Push-уведомлений
```
1. Пользователь разрешает уведомления
2. Service Worker регистрируется
3. Подписка сохраняется в user_push_subs
   - endpoint (FCM URL)
   - p256dh ключ
   - auth ключ
4. При событии (новая задача):
   - Edge Function push-send
   - POST на FCM API
   - FCM доставляет на устройство
5. Service Worker показывает уведомление
```

#### События для уведомлений
- Назначение новой задачи
- Изменение статуса задачи
- Новое сообщение в чате
- Упоминание в комментарии
- Одобрение заявки на материалы

### 9. Рабочие выезды (Jobs)

#### Процесс выезда
```
1. Manager создаёт job
2. Указывает адрес, координаты
3. Назначает engineer_id
4. Статус: pending
5. Engineer начинает: status = started
6. Engineer завершает: status = finished
7. Manager подтверждает: confirmed_by
```

#### Чат выезда
- Автоматически создаётся chat_id
- Все участники (engineer + workers)
- Отдельная ветка обсуждений
- Привязка сообщений к job_id

---

## 🖥️ ОПИСАНИЕ ИНТЕРФЕЙСА

### Глобальные элементы

#### Верхняя панель (Header)
```
┌─────────────────────────────────────────────┐
│ ☰  Логотип    Поиск    🔔  👤 Профиль     │
└─────────────────────────────────────────────┘
```

**Элементы:**
- **☰** - Бургер меню (мобильная версия)
- **Логотип** - Клик → Dashboard
- **Поиск** - Живой поиск по задачам/проектам
- **🔔** - Колокольчик уведомлений (красная точка при непрочитанных)
- **👤** - Аватар профиля (выпадающее меню)

#### Боковое меню (Sidebar)
```
┌─────────────────────┐
│ 📊 Дашборд          │
│ 📁 Проекты          │
│ ✅ Задачи           │
│ 🔧 Монтажи          │
│ ⚡ АВР / НРД        │
│ 💬 Чаты             │
│ 📦 Материалы        │
│ 📋 Заявки           │
│ 🗂️ Архив            │
│ ⚙️ Настройки        │
└─────────────────────┘
```

**Навигация:**
- Активный пункт подсвечен синим
- Счётчики рядом с пунктами (непрочитанные чаты, задачи)
- Быстрый переход по клику

### Страницы приложения

#### 1. Dashboard (Главная)

**Виджеты:**
```
┌──────────────┬──────────────┐
│ Мои задачи   │ Статистика   │
│ • В работе   │ • Всего      │
│ • Новые      │ • Завершено  │
│ • Просрочены │ • % выполнения│
└──────────────┴──────────────┘

┌─────────────────────────────┐
│ Последние уведомления       │
│ • Новая задача: ...         │
│ • Комментарий: ...          │
└─────────────────────────────┘
```

**Функции:**
- Быстрый обзор состояния
- Переход к важным задачам
- Уведомления в реальном времени

#### 2. Задачи (Tasks)

**Представление:**
```
┌─────────────────────────────────────────┐
│ [+ Новая задача]  [Фильтры ▼]          │
├─────────────────────────────────────────┤
│ ☐ Задача 1    Статус   Исполнитель  📅 │
│ ☐ Задача 2    Статус   Исполнитель  📅 │
│ ☐ Задача 3    Статус   Исполнитель  📅 │
└─────────────────────────────────────────┘
```

**Карточка задачи:**
- Чекбокс (быстрое завершение)
- Название + короткий ID
- Цветной бейдж статуса
- Аватар исполнителя
- Дедлайн (красный если просрочен)

**Фильтры:**
- По статусу (all/new/in_progress/completed)
- По исполнителю
- По дедлайну
- По приоритету

**Сортировка:**
- По дате создания
- По дедлайну
- По приоритету
- По статусу

#### 3. Детальная страница задачи

**Структура:**
```
┌───────────────────────────────────┐
│ ← Назад    Задача #123    ✏️ 🗑️  │
├───────────────────────────────────┤
│ ЗАГОЛОВОК                         │
│                                   │
│ Описание:                         │
│ Полный текст описания...          │
│                                   │
│ ────────────────────────────────  │
│ Проект: Название проекта          │
│ Исполнитель: 👤 Иван Иванов       │
│ Статус: 🟢 В работе               │
│ Приоритет: 🔴 Высокий             │
│ Дедлайн: 25.03.2026 18:00         │
│ Адрес: ул. Примерная, д.1         │
│                                   │
│ ────────────────────────────────  │
│ 💬 Комментарии (5)                │
│ [Написать комментарий...]         │
└───────────────────────────────────┘
```

**Действия:**
- **✏️ Редактировать** - Изменить поля (автор/manager)
- **🗑️ Удалить** - Удалить задачу (manager)
- **Сменить статус** - Dropdown меню
- **Назначить исполнителя** - Выбор из списка

#### 4. Проекты (Projects)

**Вид:**
```
┌────────────┬────────────┬────────────┐
│ Проект 1   │ Проект 2   │ Проект 3   │
│ 📊 70%     │ 📊 30%     │ 📊 100%    │
│ 10 задач   │ 5 задач    │ 20 задач   │
│ ✅ 7       │ ✅ 1       │ ✅ 20      │
└────────────┴────────────┴────────────┘
```

**Карточка проекта:**
- Название + описание
- Прогресс бар (%)
- Счётчик задач (всего/выполнено)
- Статус (active/completed/on_hold)
- Дата создания

**Детали проекта:**
- Список всех задач
- Участники проекта
- Хронология событий
- Файлы и документы

#### 5. Монтажи (Installations)

**Таблица:**
```
┌──────────────────────────────────────────────┐
│ ID  │ Название      │ Статус  │ СК    │ Дата │
├──────────────────────────────────────────────┤
│ 001 │ Монтаж А      │ 🟢 New  │ 3/7   │ 25.03│
│ 002 │ Монтаж Б      │ 🟡 Work │ 5/7   │ 26.03│
│ 003 │ Монтаж В      │ 🔴 Done │ 7/7   │ 27.03│
└──────────────────────────────────────────────┘
```

**Детали монтажа:**
- Основная информация
- Оборудование по каждой СК (до 7)
- Статус каждой позиции
- Плановая дата
- Фотографии (опционально)

#### 6. Чаты (Messenger)

**Список чатов:**
```
┌───────────────────────────────────┐
│ 🔍 Поиск                          │
├───────────────────────────────────┤
│ 👤 Иван Иванов                    │
│    Последнее сообщение...    14:30│
│    🔴 3                           │
├───────────────────────────────────┤
│ 💬 Рабочий чат                    │
│    Обсуждение проекта...     12:00│
│    🟢 15                          │
└───────────────────────────────────┘
```

**Окно чата:**
```
┌───────────────────────────────────┐
│ ← 👤 Иван Иванов           📞 ⋮   │
├───────────────────────────────────┤
│                                   │
│    Привет! Как дела?         10:00│
│                                   │
│ Привет! Всё отлично.        10:05 │
│                                   │
├───────────────────────────────────┤
│ [📎] [_________________] [➤]     │
└───────────────────────────────────┘
```

**Функции:**
- Текстовые сообщения
- Прикрепление файлов
- Реакции (эмодзи)
- Удаление сообщений
- Поиск по истории

#### 7. Материалы (Materials)

**Каталог:**
```
┌───────────────────────────────────┐
│ 🔍 Поиск материалов               │
├───────────────────────────────────┤
│ Категория: Все ▼                  │
├───────────────────────────────────┤
│ 🔩 Кабель UTP 4PR 24AWG           │
│    Категория: Кабели              │
│    Ед. изм.: м                    │
│    📦 В наличии: 500м             │
├───────────────────────────────────┤
│ 🔌 Розетка 220V                   │
│    Категория: Электрика           │
│    Ед. изм.: шт                   │
│    📦 В наличии: 50шт             │
└───────────────────────────────────┘
```

#### 8. Заявки на материалы (Purchase Requests)

**Создание заявки:**
```
┌───────────────────────────────────┐
│ Новая заявка на материалы         │
├───────────────────────────────────┤
│ Задача: [Выбрать задачу ▼]        │
├───────────────────────────────────┤
│ Позиции:                          │
│ + Добавить материал               │
│                                   │
│ 1. Кабель UTP                     │
│    Количество: [100] [м]          │
│    ×                              │
│                                   │
│ 2. Розетка 220V                   │
│    Количество: [10] [шт]          │
│    ×                              │
├───────────────────────────────────┤
│ [Отправить на одобрение]          │
└───────────────────────────────────┘
```

**Статусы в списке:**
- 🟡 Pending (ожидает)
- 🟢 Approved (одобрено)
- 🔴 Rejected (отклонено)
- 🔵 Issued (выдано)

#### 9. Архив (Archive)

**Таблица:**
```
┌────────────────────────────────────────────┐
│ Тип │ ID  │ Название   │ Дата    │ Кто    │
├────────────────────────────────────────────┤
│ Task│ 045 │ Задача 1   │ 20.03   │ Admin  │
│ Inst│ 012 │ Монтаж А   │ 19.03   │ Manager│
└────────────────────────────────────────────┘
```

**Данные:**
- Original data (JSONB) - полная копия
- Archived at - дата архивации
- Archived by - кто архивировал
- Reason - причина (auto_archive_24h)

#### 10. Профиль пользователя

**Вкладки:**
```
[Основное] [Уведомления] [Безопасность]
```

**Основное:**
- Аватар (загрузка)
- Имя (редактирование)
- Email (только просмотр)
- Роль (только просмотр)
- Телефон
- Дата регистрации

**Уведомления:**
- Push уведомления (toggle)
- Email уведомления (toggle)
- Звуковые сигналы (toggle)

**Безопасность:**
- Сменить пароль
- Двухфакторная аутентификация (future)
- Активные сессии

---

## 📖 ИНСТРУКЦИЯ ПОЛЬЗОВАТЕЛЯ

### Быстрый старт

#### 1. Первый вход
```
1. Откройте https://tkolya-dotcom.github.io/task-manager-app/
2. Введите email и пароль
3. Нажмите "ВОЙТИ"
4. Вы на Dashboard
```

#### 2. Создание задачи (Engineer+)
```
1. Перейдите в "Задачи"
2. Нажмите "+ Новая задача"
3. Заполните поля:
   - Заголовок (обязательно)
   - Описание
   - Проект (если есть)
   - Исполнитель
   - Дедлайн
4. Нажмите "Создать"
```

#### 3. Начало работы над задачей
```
1. Откройте задачу
2. Измените статус на "В работе"
3. Добавьте комментарий (опционально)
4. Начните выполнение
```

#### 4. Завершение задачи
```
1. Откройте задачу
2. Измените статус на "Завершена"
3. Добавьте комментарий о выполнении
4. Через 24ч задача уйдёт в архив
```

#### 5. Отправка заявки на материалы
```
1. Перейдите в "Заявки"
2. Нажмите "+ Новая заявка"
3. Выберите задачу
4. Добавьте материалы из каталога
5. Укажите количество
6. Нажмите "Отправить"
7. Дождитесь одобрения Manager
```

#### 6. Работа с чатом
```
1. Перейдите в "Чаты"
2. Выберите контакт или группу
3. Напишите сообщение
4. Для прикрепления файла нажмите 📎
5. Для удаления сообщения:
   - Долгий клик (mobile) или ПКМ (desktop)
   - Выберите "Удалить у себя" или "Удалить у всех"
```

### Ролевые инструкции

#### Для Worker

**Ежедневные задачи:**
1. Проверить Dashboard утром
2. Открыть новые задачи
3. Взять в работу
4. Выполнить
5. Отметить выполненным
6. Написать отчёт в комментариях

**Если нужны материалы:**
1. Создать заявку
2. Приложить список
3. Дождаться одобрения
4. Получить на складе

#### Для Engineer

**Планирование:**
1. Создать задачи на неделю
2. Назначить исполнителей
3. Установить дедлайны
4. Контролировать выполнение

**Монтажи:**
1. Создать монтаж
2. Добавить оборудование
3. Назначить команду
4. Контролировать этапы

#### Для Manager

**Управление командой:**
1. Мониторить Dashboard
2. Проверять новые заявки
3. Одобряйте/отклоняйте
4. Создавать пользователей

**Контроль:**
1. Проверять завершённые задачи
2. Подтверждать выезды
3. Модерировать чаты
4. Анализировать статистику

---

## 🗄️ БАЗА ДАННЫХ

### Основные таблицы

#### users
```sql
id                        UUID (PK)
name                      TEXT
email                     TEXT (UNIQUE)
role                      TEXT (CHECK constraint)
auth_user_id              UUID (FK → auth.users)
is_online                 BOOLEAN
last_seen                 TIMESTAMP
phone                     TEXT
avatar_url                TEXT
has_unread_notifications  BOOLEAN
created_at                TIMESTAMP
updated_at                TIMESTAMP
```

#### tasks
```sql
id           UUID (PK)
project_id   UUID (FK → projects)
title        TEXT
description  TEXT
assignee_id  UUID (FK → users)
created_by   UUID (FK → users)
status       TEXT (DEFAULT 'new')
priority     TEXT (DEFAULT 'normal')
scheduled_at TIMESTAMP
deadline     TIMESTAMP
finished_at  TIMESTAMP
address      TEXT
is_archived  BOOLEAN
short_id     INTEGER
created_at   TIMESTAMP
updated_at   TIMESTAMP
```

#### installations
```sql
id                      UUID (PK)
project_id              UUID (FK → projects)
title                   TEXT
description             TEXT
assignee_id             UUID (FK → users)
created_by              UUID (FK → users)
status                  TEXT
scheduled_at            TIMESTAMP
deadline                TIMESTAMP
actual_completion_date  TIMESTAMP
address                 TEXT
id_ploshadki            TEXT
servisnyy_id            TEXT
rayon                   TEXT
id_sk[0-6]              TEXT
naimenovanie_sk[0-6]    TEXT
status_oborudovaniya[0-6] TEXT
tip_sk_po_dogovoru[0-6] TEXT
planovaya_data_1_kv_2026 INTEGER
is_archived             BOOLEAN
short_id                INTEGER
```

#### tasks_avr
```sql
id                      UUID (PK)
project_id              UUID (FK → projects)
title                   TEXT
description             TEXT
assignee_id             UUID (FK → users)
created_by              UUID (FK → users)
executor_id             UUID (FK → users)
status                  TEXT
scheduled_at            TIMESTAMP
deadline                TIMESTAMP
finished_at             TIMESTAMP
address                 TEXT
address_text            TEXT
address_id              UUID
site_id                 TEXT
manual_address          TEXT
equipment_mark          VARCHAR(100)
equipment_model         VARCHAR(100)
equipment_serial        VARCHAR(100)
equipment_inventory     VARCHAR(100)
equipment_changed       BOOLEAN
old_equipment_*         VARCHAR(100)
new_equipment_*         VARCHAR(100)
change_reason           TEXT
is_archived             BOOLEAN
short_id                INTEGER (AUTO INCREMENT)
```

#### messages
```sql
id          UUID (PK)
chat_id     UUID (FK → chats)
user_id     UUID (FK → users)
content     JSONB
type        TEXT (DEFAULT 'text')
job_id      UUID (FK → jobs, NULLABLE)
deleted_for UUID[] (DEFAULT '{}')
created_at  TIMESTAMP
```

#### materials_requests
```sql
id           UUID (PK)
task_id      UUID (FK → tasks)
status       VARCHAR(50) (DEFAULT 'pending')
requested_at TIMESTAMP
approved_at  TIMESTAMP
issued_at    TIMESTAMP
created_by   UUID (FK → users)
created_at   TIMESTAMP
```

### RLS Политики (Row Level Security)

#### users
```sql
-- Чтение все
CREATE POLICY "Users readable by authenticated" ON users
    FOR SELECT TO authenticated
    USING (true);

-- Вставка себе
CREATE POLICY "Users insert for registration" ON users
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = id);

-- Обновление своего профиля
CREATE POLICY "Users update own profile" ON users
    FOR UPDATE TO authenticated
    USING (auth.uid() = id);
```

#### tasks
```sql
-- Чтение: все авторизованные
CREATE POLICY "Tasks readable" ON tasks
    FOR SELECT TO authenticated
    USING (true);

-- Вставка: engineer+
CREATE POLICY "Tasks insert" ON tasks
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('engineer', 'manager', 'deputy_head', 'admin')
        )
    );

-- Обновление: назначенный или создатель
CREATE POLICY "Tasks update" ON tasks
    FOR UPDATE TO authenticated
    USING (
        assignee_id = auth.uid() OR 
        created_by = auth.uid() OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role IN ('manager', 'deputy_head', 'admin')
        )
    );
```

### Триггеры

#### Автоматическое создание профиля
```sql
CREATE FUNCTION create_user_profile() RETURNS trigger AS $$
BEGIN
    INSERT INTO users (id, email, name, auth_user_id)
    VALUES (NEW.id, NEW.email, NEW.email.split('@')[0], NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION create_user_profile();
```

#### Автоматическая архивация
```sql
CREATE FUNCTION archive_completed_tasks() RETURNS void AS $$
BEGIN
    INSERT INTO archive (original_type, original_id, original_data, archived_by)
    SELECT 
        'task',
        t.id,
        to_jsonb(t),
        'system'
    FROM tasks t
    WHERE t.status = 'completed'
    AND t.finished_at < NOW() - INTERVAL '24 hours'
    AND t.is_archived = false;
    
    UPDATE tasks 
    SET is_archived = true 
    WHERE status = 'completed' 
    AND finished_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;
```

---

## 🔔 УВЕДОМЛЕНИЯ

### Типы событий

1. **Назначение задачи**
   - Trigger: INSERT INTO tasks WHERE assignee_id = X
   - Канал: Push + FCM + Realtime

2. **Изменение статуса**
   - Trigger: UPDATE tasks SET status
   - Канал: Realtime

3. **Новое сообщение**
   - Trigger: INSERT INTO messages
   - Канал: Push + FCM + Realtime

4. **Упоминание в комментарии**
   - Parser: @username
   - Канал: Push + Email

5. **Одобрение заявки**
   - Trigger: UPDATE materials_requests SET status
   - Канал: Push + FCM

### Service Worker

```javascript
self.addEventListener('push', function(event) {
    const data = event.data.json();
    
    const options = {
        body: data.body,
        icon: '/icon-192.png',
        badge: '/icon-192.png',
        vibrate: [200, 100, 200],
        data: {
            url: data.url
        }
    };
    
    event.waitUntil(
        self.registration.showNotification(data.title, options)
    );
});

self.addEventListener('notificationclick', function(event) {
    event.notification.close();
    event.waitUntil(
        clients.openWindow(event.notification.data.url)
    );
});
```

---

## 💬 ЧАТ И КОММУНИКАЦИИ

### Архитектура чата

```
Client (WebSocket Realtime)
    ↓
Supabase Realtime Server
    ↓
PostgreSQL (messages table)
    ↓
Realtime Subscription (client)
    ↓
UI Update
```

### Онлайн статус

```sql
-- Таблица users
is_online  BOOLEAN (DEFAULT false)
last_seen  TIMESTAMP (DEFAULT now())

-- Обновление при активности
UPDATE users 
SET last_seen = now(), is_online = true 
WHERE id = current_user_id;

-- Offline после 5 мин бездействия
UPDATE users 
SET is_online = false 
WHERE last_seen < now() - INTERVAL '5 minutes';
```

### Индикаторы чтения

```sql
-- Таблица message_read_receipts
message_id  UUID (FK → messages)
user_id     UUID (FK → users)
read_at     TIMESTAMP
UNIQUE (message_id, user_id)

-- Проставление прочтения
INSERT INTO message_read_receipts (message_id, user_id)
VALUES (:messageId, :userId)
ON CONFLICT DO NOTHING;
```

---

## 📦 МАТЕРИАЛЫ И ЗАЯВКИ

###Workflow заявки

```
1. Worker
   ↓
   Создаёт materials_request
   Добавляет items
   Статус: pending
   
2. System
   ↓
   Уведомляет Manager
   
3. Manager
   ↓
   Проверяет заявку
   Решение: approve/reject
   Статус: approved/rejected
   
4. Warehouse
   ↓
   Выдаёт материалы
   Статус: issued
   
5. Worker
   ↓
   Получает материалы
   Закрывает заявку
```

### Отчётность

```sql
-- Заявки за период
SELECT 
    mr.status,
    COUNT(*) as count,
    SUM(mri.quantity) as total_items
FROM materials_requests mr
JOIN materials_request_items mri ON mri.request_id = mr.id
WHERE mr.created_at BETWEEN :start AND :end
GROUP BY mr.status;

-- Популярные материалы
SELECT 
    m.name,
    SUM(mri.quantity) as total_used
FROM materials m
JOIN materials_request_items mri ON mri.material_id = m.id
GROUP BY m.id
ORDER BY total_used DESC
LIMIT 10;
```

---

## 🔐 БЕЗОПАСНОСТЬ

### JWT Token

```
Format: Header.Payload.Signature

Payload:
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "role": "worker",
  "iat": 1234567890,
  "exp": 1234654290
}

Lifetime: 1 hour
Refresh: 7 days
```

### RLS Enforcement

```sql
-- Все таблицы защищены
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
-- ... для всех таблиц

-- Публикация для realtime
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
```

### CORS Policy

```
Allowed Origins:
- https://tkolya-dotcom.github.io
- https://jmxjbdnqnzkzxgsfywha.supabase.co

Methods: GET, POST, PUT, DELETE
Headers: Authorization, Content-Type
Credentials: Include
```

---

## 📱 PWA ВОЗМОЖНОСТИ

### Manifest
```json
{
  "name": "ООО Корнео - Задачи",
  "short_name": "Корнео",
  "start_url": "/task-manager-app/",
  "display": "standalone",
  "background_color": "#0A0A0F",
  "theme_color": "#0A0A0F",
  "icons": [
    {
      "src": "/task-manager-app/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    }
  ]
}
```

### Cache Strategy

```javascript
// Cache-first для статики
// Network-first для API
// Stale-while-revalidate для изображений

const CACHE_NAME = 'task-manager-v1';

self.addEventListener('fetch', (event) => {
    if (event.request.url.includes('/api/')) {
        // API: network-first
        event.respondWith(networkFirst(event.request));
    } else {
        // Static: cache-first
        event.respondWith(cacheFirst(event.request));
    }
});
```

### Offline Mode

```
Доступно offline:
- Кэшированные страницы
- Последняя версия Dashboard
- Сохранённые данные в IndexedDB

Недоступно offline:
- Realtime обновления
- Отправка сообщений
- Создание задач
```

---

## 🎨 UI/UX ПРИНЦИПЫ

### Цветовая схема

```css
--bg-primary: #0A0A0F      /* Основной фон */
--bg-secondary: #1A1A2E    /* Вторичный фон */
--text-primary: #FFFFFF    /* Основной текст */
--text-secondary: #A0A0B0  /* Вторичный текст */
--accent: #00D9FF          /* Акцент (синий) */
--success: #51CF66         /* Успех (зелёный) */
--warning: #FFD43B         /* Предупреждение (жёлтый) */
--danger: #FF6B6B          /* Ошибка (красный) */
```

### Адаптивность

```
Mobile: < 768px
  - Бургер меню
  - Одна колонка
  - Сворачиваемые секции

Tablet: 768px - 1024px
  - Боковое меню
  - Две колонки
  
Desktop: > 1024px
  - Фиксированный sidebar
  - Три колонки (опционально)
```

### Микро-взаимодействия

- Hover эффекты на кнопках
- Transition при смене статуса
- Skeleton loaders при загрузке
- Toast уведомления об операциях
- Pull-to-refresh (mobile)

---

## 📊 МЕТРИКИ И АНАЛИТИКА

### Dashboard метрики

```
1. Эффективность команды
   - Задач завершено за неделю
   - Среднее время выполнения
   - % задач в срок

2. Загрузка сотрудников
   - Активных задач по каждому
   - Просроченные задачи
   - Перегрузка (>5 задач)

3. Статус проектов
   - Прогресс по проектам
   - Риски срыва сроков
   - Использование ресурсов
```

### SQL запросы для отчётов

```sql
-- Задач по статусам
SELECT status, COUNT(*) 
FROM tasks 
GROUP BY status;

-- Производительность по сотрудникам
SELECT 
    u.name,
    COUNT(CASE WHEN t.status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN t.status = 'in_progress' THEN 1 END) as in_progress
FROM users u
LEFT JOIN tasks t ON t.assignee_id = u.id
GROUP BY u.id;

-- Соблюдение дедлайнов
SELECT 
    COUNT(*) FILTER (WHERE finished_at <= deadline) as on_time,
    COUNT(*) FILTER (WHERE finished_at > deadline) as late,
    ROUND(
        COUNT(*) FILTER (WHERE finished_at <= deadline) * 100.0 / COUNT(*),
        2
    ) as on_time_percentage
FROM tasks
WHERE status = 'completed';
```

---

## 🛠️ АДМИНИСТРИРОВАНИЕ

### Backup базы данных

```bash
# Ежедневный backup
pg_dump -h db.jmxjbdnqnzkzxgsfywha.supabase.co \
  -U postgres \
  task-manager-app > backup_$(date +%Y%m%d).sql

# Восстановление
psql -h db.jmxjbdnqnzkzxgsfywha.supabase.co \
  -U postgres \
  -d task-manager-app < backup_20260327.sql
```

### Мониторинг

```sql
-- Активные пользователи
SELECT COUNT(*) FROM users WHERE is_online = true;

-- Задачи сегодня
SELECT COUNT(*) FROM tasks 
WHERE DATE(created_at) = CURRENT_DATE;

-- Ошибки аутентификации
SELECT COUNT(*) FROM auth_audit_logs 
WHERE event_name = 'login_failed' 
AND created_at > NOW() - INTERVAL '1 hour';
```

### Логи

```
Расположение логов:
- Supabase Dashboard → Logs
- Firebase Console → Analytics
- Browser Console (client errors)
- Service Worker logs

Уровни логирования:
- INFO: Обычные операции
- WARN: Предупреждения
- ERROR: Ошибки
```

---

## 🆘 TROUBLESHOOTING

### Проблема: Не входит в приложение

**Решение:**
1. Проверить credentials
2. Очистить localStorage
3. Проверить консоль на ошибки
4. Проверить RLS политики

```sql
-- Проверка связи users ↔ auth.users
SELECT u.id, u.email, u.auth_user_id, au.id
FROM users u
LEFT JOIN auth.users au ON u.auth_user_id = au.id
WHERE u.email = 'user@example.com';
```

### Проблема: Не приходят уведомления

**Решение:**
1. Проверить разрешение браузера
2. Проверить подписку в user_push_subs
3. Проверить Service Worker
4. Проверить Firebase VAPID ключи

```javascript
// Проверка подписки
const reg = await navigator.serviceWorker.ready;
const sub = await reg.pushManager.getSubscription();
console.log('Subscription:', sub);
```

### Проблема: Задачи не обновляются realtime

**Решение:**
1. Проверить подписку
2. Проверить публикацию таблиц
3. Проверить токен аутентификации

```sql
-- Проверка realtime публикации
SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime';
```

---

## 📞 ПОДДЕРЖКА

### Контакты технической поддержки

- **Email:** supportSK@korneo.ru
- **Телефон:** +7 (921) 940-36-46
- **Чат:** Раздел "Помощь" в приложении

### Время работы

- Пн-Пт: 9:00 - 18:00 (МСК)
- Сб-Вс: Выходной

### SLA

- Критические ошибки: 2 часа
- Обычные вопросы: 24 часа
-Feature requests: рассмотрение на спринте

---

### второй этап разработки

- [ ] Мобильное приложение (React Native)
- [ ] Оффлайн режим с синхронизацией
- [ ] Интеграция с календарём с разрешения пользователя.
- [ ] Gantt диаграмма для проектов
- [ ] AI ассистент для планирования GigaChat
- [ ] Расширенная аналитика
--

## 📝 ЛИЦЕНЗИЯ

© 2026 ООО "Корнео". Все права защищены.

Конфиденциальная информация. Не подлежит разглашению.

---

**Версия документа:** 1.0  
**Дата обновления:** 27.03.2026  
**Ответственный:** Технический директор

-- ============================================================
-- ПОЛНЫЙ ДАМП БАЗЫ ДАННЫХ: Планировщик
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
  fact_count     integer     DEFAULT