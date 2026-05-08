# Настройка Push-уведомлений (FCM v1 API)

## Проблема (исправлено 02.04.2026)

Старый `push-send` использовал **FCM Legacy API** (`fcm.googleapis.com/fcm/send` с `key=SERVER_KEY`).
Google отключил Legacy API в июне 2024 — поэтому push на Android не работал.

Новый `push-send` использует **FCM HTTP v1 API** через сервисный аккаунт Google.

## Что нужно сделать (один раз)

### 1. Скачать Service Account JSON из Firebase Console

1. Открыть [Firebase Console](https://console.firebase.google.com) → проект **planner-web-4fec7**
2. Шестерёнка → **Настройки проекта** → вкладка **Сервисные аккаунты**
3. Нажать **"Создать новый закрытый ключ"** → скачается файл `serviceAccountKey.json`

### 2. Конвертировать в base64

```bash
base64 -i serviceAccountKey.json | tr -d '\n'
```

Скопировать результат — это значение для `FIREBASE_SERVICE_ACCOUNT`.

### 3. Добавить секреты в Supabase Edge Functions

Открыть [Supabase Dashboard](https://supabase.com/dashboard/project/jmxjbdnqnzkzxgsfywha/settings/edge-functions)
→ **Edge Functions** → **Manage secrets** и добавить:

| Ключ | Значение |
|------|----------|
| `FIREBASE_SERVICE_ACCOUNT` | base64-строка из п.2 |
| `FIREBASE_PROJECT_ID` | `planner-web-4fec7` |

### 4. VAPID ключи (уже должны быть настроены)

| Ключ | Значение |
|------|----------|
| `VAPID_PUBLIC_KEY` | `BDhqTgQRiZ69r0YWz6vw5HIEkecDEqLV9NIGfUEpWaPUFGcc4T_WWlaE8OmSO5EMzvOySOYXdpKtI3J1emZXj0s` |
| `VAPID_PRIVATE_KEY` | (из генерации VAPID-пары) |
| `VAPID_SUBJECT` | `mailto:admin@korneo.app` |

## Как работает теперь

```
Android (FCM токен) → users.fcm_token
                          ↓
push-send → getFirebaseAccessToken() → FCM HTTP v1 API → Android push
                          
Браузер (Web Push) → user_push_subs
                          ↓  
push-send → sendWebPush() → VAPID → браузер push
```

## Проверка

После настройки секретов — отправь сообщение в чат с другого аккаунта.
В логах Supabase Edge Functions должно появиться:
```
FCM v1 ok: projects/planner-web-4fec7/messages/...
push-send done: sent=1/1
```
