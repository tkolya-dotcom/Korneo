# 🚀 ООО "Корнео" - Система Управления Задачами

Современное PWA-приложение для управления задачами, проектами и монтажами.

## 🌐 Демо

**GitHub Pages:** [https://tkolya-dotcom.github.io/task-manager-app/](https://tkolya-dotcom.github.io/task-manager-app/)

---

## ⚡ Быстрый старт

### 1. Настройка Supabase

1. Создайте проект на [supabase.com](https://supabase.com)
2. Выполните SQL дамп из `docs/schema.sql`
3. Скопируйте реквизиты из `Settings → API`

### 2. Настройка Firebase

1. Создайте проект в [Firebase Console](https://console.firebase.google.com)
2. Включите **Authentication** (Email/Password)
3. Включите **Cloud Messaging**
4. Скопируйте конфиг из проекта Firebase

### 3. Обновление конфигурации

Откройте `js/config.js` и обновите:

```javascript
export const SUPABASE_CONFIG = {
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY'
};

export const FIREBASE_CONFIG = {
  apiKey: "YOUR_FIREBASE_API_KEY",
  // ... остальные поля
};
```

### 4. Запуск на GitHub Pages

```bash
# Инициализация Git
git init
git add .
git commit -m "Initial commit"

# Создание репозитория и push
git remote add origin https://github.com/YOUR_USERNAME/task-manager-app.git
git branch -M main
git push -u origin main
```

Включите **GitHub Pages**:
- Settings → Pages
- Branch: `main`, Folder: `/ (root)`
- Save

---

## 📁 Структура проекта

```
OOO Korneo/
├── index.html              # Монолитное приложение (16500+ строк)
├── manifest.json           # PWA манифест
├── service-worker.js       # Service Worker
├── js/                     # JavaScript модули
│   ├── config.js           # Конфигурация
│   ├── api.js              # Supabase клиент
│   ├── auth.js             # Аутентификация
│   ├── tasks.js            # Задачи
│   ├── projects.js         # Проекты
│   ├── installations.js    # Монтажи
│   ├── chat.js             # Чат
│   ├── notifications.js    # Уведомления
│   ├── utils.js            # Утилиты
│   └── app.js              # Главный файл
├── docs/                   # Документация
│   ├── schema.sql          # Схема БД
│   └── SUPABASE_SETUP.md   # Инструкция по настройке
├── APPLICATION_DOCUMENTATION.md  # Полная документация
└── README.md               # Этот файл
```

---

## 🛠️ Технологический стек

### Frontend
- **HTML5/CSS3** - монолитный index.html
- **Vanilla JavaScript (ES6+)** - модульная архитектура
- **PWA** - Service Worker + Manifest
- **Mapbox GL** - интерактивные карты

### Backend (Supabase)
- **PostgreSQL 15** - основная БД
- **Supabase Auth** - JWT аутентификация
- **Realtime** - WebSocket подписки
- **RLS** - Row Level Security

### Уведомления
- **Firebase Cloud Messaging (FCM)** - push-уведомления
- **Web Push API** - браузерные уведомления
- **Service Worker** - фоновая обработка

---

## 👥 Роли пользователей

| Роль | Права |
|------|-------|
| **Worker** | Просмотр задач, выполнение, чат, заявки |
| **Engineer** | + Создание задач, управление монтажами |
| **Manager** | + Управление пользователями, удаление задач, одобрение заявок |
| **Deputy Head** | + Назначение ролей worker/engineer |
| **Admin** | Полный доступ |

---

## 🎯 Основные возможности

### ✅ Управление задачами
- Создание/редактирование/удаление задач
- Назначение исполнителей
- Статусы: New, In Progress, On Hold, Completed, Archived
- Приоритеты: Low, Normal, High, Urgent
- Дедлайны и адреса
- Автоматическая архивация через 24ч после завершения
- Короткие ID (автогенерация)

### 📁 Управление проектами
- Карточки проектов с прогрессом
- Статистика по задачам
- Группировка задач по проектам

### 🔧 Монтажи
- До 7 единиц оборудования (СК)
- Статусы оборудования
- Плановые даты
- Привязка к проектам

### ⚡ Задачи АВР
- Короткие ID
- Учёт оборудования (старое/новое)
- Причины замены

### 💬 Чат
- Личные и групповые чаты
- Чаты рабочих выездов (Jobs)
- Realtime сообщения
- Удаление сообщений (у себя/у всех)
- Реакции (эмодзи)
- Закрепление чатов
- Отключение уведомлений

### 📦 Материалы и заявки
- Каталог материалов
- Заявки на материалы
- Одобрение менеджером
- Выдача со склада

### 🔔 Уведомления
- Push через FCM
- Браузерные уведомления
- Realtime обновления
- Уведомления о новых задачах, сообщениях, комментариях

### 🗺️ Карты
- Mapbox GL интеграция
- Построение маршрутов
- Отметка адресов

---

## 📊 База данных

### Таблицы (29)
- users, projects, chats, tasks, tasks_avr
- installations, jobs, chat_members, messages
- message_read_receipts, comments, equipment_changes
- notification_queue, user_push_subs, user_locations
- materials, warehouse, materials_requests
- materials_request_items, materials_usage
- purchase_requests, purchase_request_items
- id_counters, manual_addresses, archive
- kasip_azm_q1_2026

### RLS Политики (113)
Все таблицы защищены Row Level Security

### Триггеры (13)
- Авто-создание профиля пользователя
- Обновление updated_at
- Генерация коротких ID
- Автоматическая архивация

---

## 🔐 Безопасность

- **JWT токены** - аутентификация
- **RLS политики** - фильтрация данных на уровне БД
- **CORS** - ограничение доменов
- **HTTPS** - шифрование трафика

---

## 📱 PWA Возможности

- ✅ Работа offline (кэширование)
- ✅ Установка на устройство
- ✅ Push-уведомления
- ✅ Адаптивный дизайн
- ✅ Fast loading

---

## 🚀 Развёртывание

### Локальная разработка

```bash
# Клонируйте репозиторий
git clone https://github.com/YOUR_USERNAME/task-manager-app.git

# Откройте index.html в браузере
# Или используйте Live Server (VS Code)
```

### Продакшн (GitHub Pages)

1. Обновите `js/config.js`
2. Выполните SQL дамп в Supabase
3. Задеплойте на GitHub Pages
4. Включите Firebase Cloud Messaging

---

## 📖 Документация

- **[APPLICATION_DOCUMENTATION.md](./APPLICATION_DOCUMENTATION.md)** - полное описание бизнес-процессов
- **[docs/SUPABASE_SETUP.md](./docs/SUPABASE_SETUP.md)** - настройка Supabase
- **[docs/schema.sql](./docs/schema.sql)** - схема базы данных
- **[js/README.md](./js/README.md)** - документация JavaScript модулей

---

## 🔧 Конфигурация

### Переменные окружения

Создайте `.env` (не коммитьте в git):

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
FIREBASE_API_KEY=your-api-key
MAPBOX_TOKEN=your-mapbox-token
VAPID_PUBLIC_KEY=your-vapid-key
```

### Обновление конфига

Откройте `js/config.js` и замените значения:

```javascript
export const SUPABASE_CONFIG = {
  url: 'https://jmxjbdnqnzkzxgsfywha.supabase.co',
  anonKey: 'eyJhbGc...' // ваш ключ
};
```

---

## 🆘 Troubleshooting

### Ошибка CORS
```
Access to fetch has been blocked by CORS policy
```

**Решение:** Проверьте настройки CORS в Supabase Dashboard

### RLS блокирует доступ
```
permission denied for table
```

**Решение:** Проверьте RLS политики и роль пользователя

### Push не работает
**Решение:**
1. Проверьте разрешение браузера
2. Проверьте VAPID ключи
3. Перерегистрируйте Service Worker

---

## 📞 Поддержка

- **Email:** supportSK@korneo.ru
- **Телефон:** +7 (921) 940-36-46

---

## 📝 Changelog

### v1.0.0 (27.03.2026)
- ✅ Монолитное приложение (index.html)
- ✅ Модульная архитектура JS
- ✅ Supabase интеграция
- ✅ Firebase Push уведомления
- ✅ PWA функционал
- ✅ Realtime обновления
- ✅ Чат и комментарии
- ✅ Материалы и заявки
- ✅ Монтажи и АВР

---

## 📄 Лицензия

© 2026 ООО "Корнео". Все права защищены.

Конфиденциальная информация. Не подлежит разглашению.

---

**Версия:** 1.0.0  
**Дата обновления:** 27.03.2026  
**Ответственный:** Технический директор
