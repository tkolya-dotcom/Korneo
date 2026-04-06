# 🚀 ООО "Корнео" — Система Управления Задачами

Корпоративная система управления задачами, монтажами, складом и персоналом для ООО «Корнео». Доступна как PWA (веб-приложение) и нативное Android-приложение.

**Версия:** 1.38 | **Платформа:** Web (PWA) + Android

---

## 🌐 Доступ

| Платформа | Ссылка |
|-----------|--------|
| Web (PWA) | https://tkolya-dotcom.github.io/Korneo/ |
| Android APK | [GitHub Releases](https://github.com/tkolya-dotcom/Korneo/releases) — файл `app-debug.apk` |

---

## 📱 Android-приложение

Android-клиент загружает веб-версию в WebView и поддерживает нативные FCM push-уведомления (в том числе при закрытом приложении).

### Установка APK

1. Перейдите в [GitHub Releases](https://github.com/tkolya-dotcom/Korneo/releases)
2. Скачайте `app-debug.apk` из последнего релиза
3. На телефоне: **Настройки → Безопасность → Установка из неизвестных источников**
4. Откройте скачанный файл и установите

> На Android 8+ разрешение запрашивается автоматически при первой установке.

### Автосборка и автообновление

- При каждом `push` в `main` GitHub Actions собирает debug APK, создаёт GitHub Release и обновляет `version.json`
- Приложение проверяет `version.json` при запуске и предлагает обновление, если доступна новая версия
- APK скачивается и устанавливается через встроенный `UpdateChecker` + `FileProvider`

Подробнее: [README_ANDROID.md](./README_ANDROID.md)

---

## 📁 Структура проекта

```
Korneo/
├── .github/workflows/       # CI/CD: сборка APK, деплой GitHub Pages
├── android/                 # Нативное Android-приложение (Capacitor + FCM)
├── api/                     # API-слой (Supabase SDK, Firebase)
├── backend/                 # Серверная логика (безопасность, склад, иконки)
├── docs/                    # Документация: schema.sql, SUPABASE_SETUP.md
├── frontend/                # Дополнительные фронтенд-ресурсы
├── js/                      # JavaScript-модули приложения
├── supabase/                # Конфигурация и миграции Supabase
├── sw-services/             # Сервисы Service Worker (FCM, push)
├── index.html               # Монолитное PWA-приложение
├── manifest.json            # PWA-манифест
├── service-worker.js        # Service Worker (кэш, push)
├── firebase-messaging-sw.js # Firebase FCM Service Worker
├── capacitor.config.json    # Capacitor (Android WebView)
├── version.json             # Текущая версия APK для автообновления
├── atss-upload.html         # Страница загрузки план-графика АТСС
├── .env.example             # Пример переменных окружения
├── APPLICATION_DOCUMENTATION.md
├── DEPLOYMENT_GUIDE.md
├── PROJECT_SUMMARY.md
└── README_ANDROID.md
```

---

## 🛠️ Технологический стек

### Frontend
- **HTML5 / CSS3 / Vanilla JS (ES6+)** — монолитный `index.html`
- **PWA** — Service Worker + Web App Manifest
- **Mapbox GL** — интерактивные карты и маршруты

### Mobile
- **Android** (Java) — нативное приложение
- **Capacitor 6.x** — WebView-обёртка
- **Firebase Cloud Messaging** — нативные push-уведомления
- **UpdateChecker + FileProvider** — автоматическое обновление APK

### Backend
- **Supabase** (PostgreSQL 15) — основная БД
- **Supabase Auth** — JWT-аутентификация
- **Supabase Realtime** — WebSocket-подписки
- **RLS (Row Level Security)** — безопасность на уровне БД (113 политик)

### Уведомления
- **Firebase Cloud Messaging (FCM)** — push для Web и Android
- **Web Push API** — браузерные уведомления
- **Service Worker** — фоновая обработка

### CI/CD
- **GitHub Actions** — сборка APK, деплой на GitHub Pages, инкремент версии
- **GitHub Releases** — хранение APK-файлов (v1–v38+)

---

## 🎯 Основные возможности

### ✅ Управление задачами
- Создание / редактирование / удаление задач
- Назначение исполнителей, дедлайны, адреса
- Статусы: `New` → `In Progress` → `On Hold` → `Completed` → `Archived`
- Приоритеты: Low / Normal / High / Urgent
- Короткие автогенерируемые ID
- Автоархивация через 24 ч после завершения

### 📁 Проекты
- Карточки с прогрессом и статистикой задач
- Группировка задач по проектам

### 🔧 Монтажи
- До 7 единиц оборудования (СК) на монтаж
- Статусы оборудования, плановые даты
- Привязка к проектам

### ⚡ Задачи АВР
- Учёт старого/нового оборудования
- Причины замены, короткие ID

### 💬 Чат
- Личные и групповые чаты
- Чаты рабочих выездов (Jobs)
- Realtime-сообщения, реакции, закрепление чатов
- Удаление у себя / у всех, отключение уведомлений

### 📦 Склад и заявки
- Каталог материалов, управление остатками
- Заявки на материалы с одобрением менеджером
- Автосоздание заявок на закупку при отрицательном остатке
- Выдача со склада

### 🗺️ Площадки и карты
- Вкладка «Площадки» с объектами
- Mapbox GL: интерактивные карты, построение маршрутов, отметка адресов

### 🔔 Уведомления
- Push через FCM (Web + Android, в том числе при закрытом приложении)
- Realtime-обновления по WebSocket
- Уведомления о задачах, сообщениях, комментариях

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

## 📊 База данных

- **29 таблиц**: users, projects, tasks, tasks_avr, installations, jobs, chats, chat_members, messages, message_read_receipts, comments, equipment_changes, notification_queue, user_push_subs, user_locations, materials, warehouse, materials_requests, materials_request_items, materials_usage, purchase_requests, purchase_request_items, id_counters, manual_addresses, archive, kasip_azm_q1_2026 и др.
- **113 RLS-политик** — все таблицы защищены на уровне БД
- **13 триггеров**: авто-профиль, `updated_at`, генерация коротких ID, архивация

Схема БД: [`docs/schema.sql`](./docs/schema.sql)

---

## ⚡ Быстрый старт

### 1. Настройка Supabase

1. Создайте проект на [supabase.com](https://supabase.com)
2. Выполните SQL-дамп из `docs/schema.sql`
3. Скопируйте реквизиты из **Settings → API**

### 2. Настройка Firebase

1. Создайте проект в [Firebase Console](https://console.firebase.google.com)
2. Включите **Cloud Messaging**
3. Скопируйте конфиг проекта

### 3. Переменные окружения

Создайте `.env` на основе `.env.example`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
FIREBASE_API_KEY=your-api-key
MAPBOX_TOKEN=your-mapbox-token
VAPID_PUBLIC_KEY=your-vapid-key
```

### 4. Деплой на GitHub Pages

1. Включите **Settings → Pages → Branch: main / root**
2. При каждом `push` в `main` GitHub Actions автоматически деплоит сайт и собирает APK

---

## 🔐 Безопасность

- **JWT** — аутентификация через Supabase Auth
- **RLS** — фильтрация данных на уровне PostgreSQL
- **HTTPS** — шифрование трафика
- **CORS** — ограничение разрешённых доменов
- Конфиденциальные данные хранятся в `.env` (не коммитятся)

---

## 🆘 Troubleshooting

**CORS-ошибка** (`Access to fetch has been blocked`) — проверьте настройки CORS в Supabase Dashboard.

**RLS блокирует доступ** (`permission denied for table`) — проверьте RLS-политики и роль пользователя.

**Push не работает** — проверьте разрешение браузера, VAPID-ключи и регистрацию Service Worker.

**Android: push не приходят при закрытом приложении** — нужен настоящий `google-services.json` с Firebase. См. [README_ANDROID.md](./README_ANDROID.md).

---

## 📖 Документация

| Файл | Описание |
|------|----------|
| [APPLICATION_DOCUMENTATION.md](./APPLICATION_DOCUMENTATION.md) | Полное описание бизнес-процессов |
| [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) | Инструкция по развёртыванию |
| [PROJECT_SUMMARY.md](./PROJECT_SUMMARY.md) | Сводка по проекту |
| [README_ANDROID.md](./README_ANDROID.md) | Android: сборка, FCM, автообновление |
| [docs/schema.sql](./docs/schema.sql) | Схема базы данных |
| [docs/SUPABASE_SETUP.md](./docs/SUPABASE_SETUP.md) | Настройка Supabase |

---

## 📞 Поддержка

- **Email:** supportSK@korneo.ru
- **Телефон:** +7 (921) 940-36-46

---

## 📝 Changelog

### v1.38 (06.04.2026)
- Автообновление APK: `version.json`, `UpdateChecker`, `FileProvider`
- Push-уведомления Android при закрытом приложении
- Исправлен UUID null в Service Worker

### v1.36 (02.04.2026)
- Вкладка «Площадки»
- Склад: автосоздание заявок на закупку при отрицательном остатке
- Исправлена безопасность backend

### v1.0 (27.03.2026)
- Первый публичный релиз
- PWA, Supabase, Firebase FCM, Realtime, чат, монтажи, АВР, материалы

---

## 📄 Лицензия

© 2026 ООО «Корнео». Все права защищены.  
Конфиденциальная информация. Не подлежит разглашению.

**Ответственный:** Технический директор
