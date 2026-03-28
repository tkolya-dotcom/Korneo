# 🚀 ПОШАГОВАЯ ИНСТРУКЦИЯ ПО ЗАПУСКУ

## ✅ ЧТО УЖЕ ГОТОВО

1. ✅ **База данных Supabase** - схема в `docs/schema.sql`
2. ✅ **JavaScript модули** - 10 модулей в папке `js/`
3. ✅ **Конфигурация** - все API ключи и секреты
4. ✅ **PWA компоненты** - manifest.json, service-worker.js
5. ✅ **Документация** - README, SUPABASE_SETUP.md

---

## 📋 ШАГИ ДЛЯ ЗАПУСКА

### ШАГ 1: Настройка Supabase (15 минут)

#### 1.1 Создание проекта
```
1. Перейдите на https://supabase.com
2. Войдите через GitHub аккаунт
3. Нажмите "New Project"
4. Заполните:
   - Name: task-manager-app
   - Database Password: [сохраните!]
   - Region: выберите ближайший
5. Нажмите "Create new project"
```

⏱️ Ожидание: 2-5 минут

#### 1.2 Получение реквизитов
```
1. В панели проекта перейдите в Settings → API
2. Скопируйте:
   - Project URL: https://xxxxx.supabase.co
   - Anon/Public Key: eyJhbGc...
   - Service Role Key: [секретный, для сервера]
```

#### 1.3 Выполнение SQL дампа
```
1. Перейдите в SQL Editor
2. Нажмите "New Query"
3. Откройте файл docs/schema.sql
4. Скопируйте всё содержимое
5. Вставьте в SQL Editor
6. Нажмите "Run" (Ctrl+Enter)
```

✅ Проверка:
- В Table Editor должно быть **29 таблиц**
- Все таблицы имеют `rowsecurity = true`

#### 1.4 Создание первого пользователя
```
1. Authentication → Users
2. "Add User"
3. Email: admin@korneo.ru
4. Password: [надёжный пароль]
5. "Add User"
```

Для изменения роли на admin:
```sql
-- В SQL Editor выполните:
UPDATE public.users
SET role = 'admin'
WHERE email = 'admin@korneo.ru';
```

---

### ШАГ 2: Обновление конфигурации (5 минут)

#### 2.1 Откройте js/config.js

#### 2.2 Замените Supabase ключи:
```javascript
export const SUPABASE_CONFIG = {
  url: 'https://ВАШ_PROJECT_ID.supabase.co',
  anonKey: 'ВАШ_ANON_KEY'
};
```

#### 2.3 Проверьте Firebase конфиг:
```javascript
export const FIREBASE_CONFIG = {
  apiKey: "AIzaSyAM3t4qBtb2FhUElkWvKbEF4Oui2I9rZGk",
  authDomain: "planner-web-4fec7.firebaseapp.com",
  projectId: "planner-web-4fec7",
  storageBucket: "planner-web-4fec7.firebasestorage.app",
  messagingSenderId: "884674213029",
  appId: "1:884674213029:web:25c19a203a33214177894c",
  measurementId: "G-847301YX32"
};
```

✅ Эти ключи уже настроены!

---

### ШАГ 3: Тестирование локально (5 минут)

#### 3.1 Установка зависимостей
```bash
npm install
```

#### 3.2 Запуск локального сервера
```bash
npm start
```

Или откройте index.html в браузере напрямую.

#### 3.3 Проверка работы
```
1. Откройте http://localhost:8080
2. Войдите как admin@korneo.ru
3. Проверьте Dashboard
4. Создайте тестовую задачу
```

---

### ШАГ 4: Развёртывание на GitHub Pages (10 минут)

#### 4.1 Инициализация Git
```bash
git init
git add .
git commit -m "Initial commit - ООО Корнео Task Manager"
```

#### 4.2 Создание репозитория на GitHub
```
1. Зайдите на https://github.com
2. Нажмите "+" → "New repository"
3. Name: task-manager-app
4. Public
5. "Create repository"
```

#### 4.3 Push в репозиторий
```bash
git branch -M main
git remote add origin https://github.com/ВАШ_USERNAME/task-manager-app.git
git push -u origin main
```

#### 4.4 Включение GitHub Pages
```
1. В репозитории: Settings → Pages
2. Source: Deploy from a branch
3. Branch: main, Folder: / (root)
4. Save
```

⏱️ Ожидание: 1-3 минуты

#### 4.5 Проверка
Ваше приложение доступно по URL:
```
https://ВАШ_USERNAME.github.io/task-manager-app/
```

---

### ШАГ 5: Финальная проверка (10 минут)

#### Чек-лист:

- [ ] Приложение открывается по URL GitHub Pages
- [ ] Аутентификация работает (вход/регистрация)
- [ ] Dashboard загружается
- [ ] Задачи создаются и отображаются
- [ ] Realtime обновления приходят
- [ ] Чат отправляет сообщения
- [ ] PWA устанавливается на устройство

---

## 🔧 ВОЗМОЖНЫЕ ПРОБЛЕМЫ И РЕШЕНИЯ

### Ошибка CORS
```
Access to fetch has been blocked by CORS policy
```

**Решение:**
1. Settings → API в Supabase
2. Прокрутите до CORS
3. Убедитесь, что "Enable CORS for all origins" включён

### RLS блокирует доступ
```
permission denied for table users
```

**Решение:**
1. Проверьте роль пользователя в БД
2. Убедитесь, что пользователь авторизован
3. Проверьте RLS политики в SQL Editor:
```sql
SELECT * FROM pg_policies WHERE schemaname = 'public';
```

### Firebase не инициализирован
```
Firebase Messaging not initialized
```

**Решение:**
1. Проверьте, что Firebase SDK загружен в index.html
2. Проверьте конфиг в js/config.js
3. Включите Cloud Messaging в Firebase Console

### Service Worker не регистрируется
```
Service Worker registration failed
```

**Решение:**
1. Очистите кэш браузера (Ctrl+Shift+Delete)
2. Проверте, что service-worker.js доступен по URL
3. Убедитесь, что HTTPS (GitHub Pages автоматически использует HTTPS)

---

## 📞 ТЕХПОДДЕРЖКА

Если возникли проблемы:

1. **Проверьте логи в консоли** (F12 → Console)
2. **Проверьте Supabase Logs** (Dashboard → Logs)
3. **Посмотрите документацию**:
   - [APPLICATION_DOCUMENTATION.md](./APPLICATION_DOCUMENTATION.md)
   - [js/README.md](./js/README.md)
   - [docs/SUPABASE_SETUP.md](./docs/SUPABASE_SETUP.md)

**Контакты:**
- Email: supportSK@korneo.ru
- Телефон: +7 (921) 940-36-46

---

## 🎯 СЛЕДУЮЩИЕ ШАГИ

После успешного запуска:

1. **Настройте Firebase Cloud Messaging** для Push-уведомлений
2. **Загрузите иконки** (icon-192.png, icon-512.png)
3. **Настройте Storage** для загрузки файлов
4. **Добавьте Edge Functions** для серверной логики
5. **Включите мониторинг** (Supabase Logs, Firebase Analytics)

---

## ✅ ИТОГОВЫЙ СТАТУС

### Создано файлов: 15

**База данных:**
- ✅ docs/schema.sql (1187 строк)
- ✅ docs/SUPABASE_SETUP.md (386 строк)

**JavaScript модули:**
- ✅ js/config.js (139 строк)
- ✅ js/api.js (489 строк)
- ✅ js/auth.js (370 строк)
- ✅ js/tasks.js (268 строк)
- ✅ js/projects.js (193 строк)
- ✅ js/installations.js (287 строк)
- ✅ js/chat.js (430 строк)
- ✅ js/notifications.js (364 строк)
- ✅ js/utils.js (398 строк)
- ✅ js/app.js (228 строк)
- ✅ js/README.md (478 строк)

**Прочее:**
- ✅ README.md (335 строк)
- ✅ .gitignore (44 строки)
- ✅ package.json (35 строк)

### Готово к развёртыванию! 🚀

---

**Версия:** 1.0  
**Дата:** 27.03.2026  
**Статус:** ✅ ГОТОВО К ЗАПУСКУ
