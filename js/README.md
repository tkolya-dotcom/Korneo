# 📚 JavaScript Модули - Документация

## 🗂️ Структура модулей

```
js/
├── config.js           # Конфигурация и API ключи
├── api.js              # Supabase клиент и репозитории
├── auth.js             # Аутентификация и пользователи
├── tasks.js            # Управление задачами
├── projects.js         # Управление проектами
├── installations.js    # Управление монтажами
├── chat.js             # Чат и сообщения
├── notifications.js    # Push-уведомления
├── utils.js            # Вспомогательные утилиты
└── app.js              # Главный файл инициализации
```

---

## 🔧 Подключение к index.html

Добавьте перед закрывающим тегом `</body>` в index.html:

```html
<!-- Firebase SDK (уже есть в index.html) -->
<script type="module">
  import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
  import { getMessaging } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging.js";
  
  // Ваша текущая конфигурация Firebase
</script>

<!-- Supabase SDK -->
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>

<!-- Модули приложения -->
<script type="module" src="./js/app.js"></script>
```

---

## 📖 Использование модулей

### Config.js

Конфигурация приложения:

```javascript
import { APP_CONFIG, SUPABASE_CONFIG, FIREBASE_CONFIG } from './config.js';

// Доступные константы
APP_CONFIG.roles.WORKER        // 'worker'
APP_CONFIG.taskStatus.NEW      // 'new'
APP_CONFIG.priorities.HIGH     // 'high'
```

### API.js

Работа с Supabase:

```javascript
import { repositories } from './api.js';

// Получение всех задач
const tasks = await repositories.tasks.getAll();

// Получение задачи по ID
const task = await repositories.tasks.getById(taskId);

// Создание задачи
const newTask = await repositories.tasks.create({
  title: 'Новая задача',
  assignee_id: userId
});

// Обновление
await repositories.tasks.update(taskId, { status: 'completed' });

// Удаление
await repositories.tasks.delete(taskId);
```

### Auth.js

Аутентификация:

```javascript
import { authService } from './auth.js';

// Вход
const result = await authService.signIn(email, password);
if (result.success) {
  console.log('Вход выполнен');
}

// Регистрация
await authService.signUp(email, password, name, role);

// Выход
await authService.signOut();

// Проверка сессии
const session = await authService.checkSession();
if (session.authenticated) {
  console.log('Пользователь:', session.user);
}

// Проверка прав
if (authService.canCreateTasks()) {
  // Создаём задачу
}

if (authService.hasRole(['manager', 'admin'])) {
  // Только для менеджеров
}
```

### Tasks.js

Управление задачами:

```javascript
import { taskService } from './tasks.js';

// Получение всех задач
const tasks = await taskService.getTasks();

// Получение задач пользователя
const userTasks = await taskService.getUserTasks(userId);

// Создание задачи
const newTask = await taskService.createTask({
  title: 'Установить камеру',
  project_id: projectId,
  assignee_id: userId,
  due_date: '2026-04-01'
});

// Изменение статуса
await taskService.updateTaskStatus(taskId, 'in_progress');

// Назначение исполнителя
await taskService.assignTask(taskId, userId);

// Удаление (только manager+)
await taskService.deleteTask(taskId);

// Realtime подписка
taskService.subscribeToTasks((payload) => {
  console.log('Изменение задачи:', payload);
});
```

### Projects.js

Управление проектами:

```javascript
import { projectService } from './projects.js';

// Все проекты со статистикой
const projects = await projectService.getAllProjectsWithStats();

// Создание проекта
const project = await projectService.createProject({
  name: 'Монтаж видеонаблюдения',
  description: 'Установка камер в офисе'
});

// Проект с задачами
const projectData = await projectService.getProjectWithTasks(projectId);
console.log('Статистика:', projectData.stats);
// { total: 10, completed: 5, inProgress: 3, newTasks: 2, progress: 50 }
```

### Installations.js

Управление монтажами:

```javascript
import { installationService } from './installations.js';

// Создание монтажа
const installation = await installationService.createInstallation({
  title: 'Монтаж СК-1',
  project_id: projectId,
  id_ploshadki: 'ПЛОЩАДКА-001',
  servisnyy_id: 'СЕРВИС-123'
});

// Обновление оборудования (до 7 СК)
await installationService.updateEquipment(installationId, 0, {
  id_sk: 'СК-001',
  naimenovanie_sk: 'Камера уличная',
  status_oborudovaniya: 'Установлено'
});

// Изменение статуса
await installationService.updateInstallationStatus(installationId, 'completed');
```

### Chat.js

Чат и сообщения:

```javascript
import { chatService } from './chat.js';

// Создание чата
const chat = await chatService.createChat('Рабочий чат', 'group', [userId1, userId2]);

// Отправка сообщения
await chatService.sendMessage(chatId, 'Привет!', 'text');

// Получение сообщений
const messages = await chatService.getMessages(chatId, 50);

// Realtime подписка
chatService.subscribeToChat(chatId, (payload) => {
  console.log('Новое сообщение:', payload);
});

// Удаление сообщения
await chatService.deleteMessageForMe(messageId);        // У себя
await chatService.deleteMessageForAll(messageId);       // У всех (автор или manager)

// Управление чатом
await chatService.pinChat(chatId, userId);              // Закрепить
await chatService.muteChat(chatId, userId);             // Отключить уведомления
```

### Notifications.js

Push-уведомления:

```javascript
import { notificationService } from './notifications.js';

// Инициализация и запрос разрешения
await notificationService.initFirebaseMessaging();

// Отправка токена на сервер
const token = await notificationService.getToken();
await authService.userProfileService.updateFCMToken(token);

// Показ локального уведомления
notificationService.showLocalNotification({
  title: 'Новая задача',
  body: 'Вам назначена задача #123',
  data: { url: '/tasks/123' }
});

// Отписка
await notificationService.unsubscribe();
```

### Utils.js

Вспомогательные функции:

```javascript
import { DateUtils, TextUtils, StatusUtils } from './utils.js';

// Даты
DateUtils.formatDate(new Date());           // '27.03.2026'
DateUtils.formatTime(new Date());           // '14:30'
DateUtils.relativeTime('5 minutes ago');    // '5 мин. назад'
DateUtils.isOverdue(dueDate);               // true/false

// Текст
TextUtils.truncate('Длинный текст...', 50); // 'Длинный текст...'
TextUtils.getInitials('Иван Иванов');       // 'ИИ'
TextUtils.formatTaskNumber(123);            // '#123'

// Статусы
StatusUtils.getStatusClass('in_progress');  // 'status-in_progress'
StatusUtils.getStatusText('completed');     // 'Завершена'
StatusUtils.getStatusColor('new');          // '#0080FF'

// Файлы
FileUtils.formatFileSize(1048576);          // '1 MB'
FileUtils.validateFileSize(file, 5);        // true/false
```

---

## 🌍 Глобальные объекты (window)

Все модули экспортируются в window для совместимости:

```javascript
// Доступно в консоли браузера и index.html
window.authService           // Аутентификация
window.taskService           // Задачи
window.projectService        // Проекты
window.installationService   // Монтажи
window.chatService           // Чат
window.notificationService   // Уведомления
window.repositories          // Репозитории
window.DateUtils             // Даты
window.TextUtils             // Текст
window.StatusUtils           // Статусы
window.APP_CONFIG            // Константы
```

---

## 🔐 Проверка прав доступа

```javascript
import { authService } from './auth.js';

// Роли
authService.hasRole('worker');                    // true/false
authService.hasRole(['manager', 'admin']);        // true/false

// Права
authService.canCreateTasks();                     // engineer+
authService.canDeleteTasks();                     // manager+
authService.canManageUsers();                     // manager+
authService.canApproveRequests();                 // manager+
```

---

## 🔄 Realtime подписки

```javascript
import { taskService, chatService } from './modules.js';

// Подписка на задачи
const unsubscribeTasks = taskService.subscribeToTasks((payload) => {
  console.log('Тип события:', payload.eventType); // INSERT/UPDATE/DELETE
  console.log('Новые данные:', payload.new);
  console.log('Старые данные:', payload.old);
});

// Подписка на чат
const unsubscribeChat = chatService.subscribeToChat(chatId, (payload) => {
  console.log('Сообщение:', payload.new);
});

// Отписка
unsubscribeTasks();
unsubscribeChat();
```

---

## 🛠️ Обработка ошибок

```javascript
try {
  const task = await taskService.createTask({...});
} catch (error) {
  console.error('Ошибка:', error.message);
  
  // Отображение пользователю
  alert(error.message);
}
```

---

## 📝 Примеры использования

### Создание задачи с комментарием

```javascript
import { taskService, comments } from './modules.js';

// Создаём задачу
const task = await taskService.createTask({
  title: 'Установить сервер',
  description: 'Монтаж серверной стойки',
  project_id: projectId,
  assignee_id: userId,
  priority: 'high',
  due_date: '2026-04-15'
});

// Добавляем комментарий
await comments.addComment('task', task.id, currentUserId, 'Срочно!');
```

### Отчёт о выполнении

```javascript
// Завершение задачи
await taskService.updateTaskStatus(taskId, 'completed');

// Добавление отчёта
await comments.addComment('task', taskId, userId, `
  Выполнено:
  - Установлено оборудование
  - Протестирована система
  - Клиент доволен
  
  Фотоотчёт во вложении.
`);
```

### Мониторинг дедлайнов

```javascript
import { taskService, DateUtils } from './modules.js';

const overdueTasks = await taskService.getOverdueTasks();

overdueTasks.forEach(task => {
  const daysLate = DateUtils.daysUntil(task.due_date);
  console.log(`Задача #${task.short_id} просрочена на ${Math.abs(daysLate)} дн.`);
});
```

---

## ⚙️ Настройка и кастомизация

### Изменение конфигурации

Откройте `js/config.js` и измените:

```javascript
export const APP_CONFIG = {
  notifications: {
    checkInterval: 60000,  // 1 минута
    maxRetries: 5
  },
  cache: {
    enabled: true,
    ttl: 600000  // 10 минут
  }
};
```

### Добавление нового статуса

```javascript
// config.js
export const APP_CONFIG = {
  taskStatus: {
    NEW: 'new',
    IN_PROGRESS: 'in_progress',
    ON_HOLD: 'on_hold',
    COMPLETED: 'completed',
    ARCHIVED: 'archived',
    CANCELLED: 'cancelled'  // Новый статус
  }
};

// utils.js
StatusUtils.getStatusText('cancelled');  // 'Отменена'
```

---

## 📞 Поддержка

При возникновении проблем:

1. Проверьте консоль браузера (F12)
2. Убедитесь, что все модули загружены
3. Проверьте подключение к Supabase
4. Убедитесь, что пользователь авторизован

**Логи включены:**
```javascript
✅ Вход выполнен: user@example.com
📊 Загрузка данных Dashboard...
🔄 Событие аутентификации: SIGNED_IN
```

---

**Версия:** 1.0 | **Дата:** 27.03.2026
