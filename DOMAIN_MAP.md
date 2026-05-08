# DOMAIN_MAP.md
## Сущности, роли, статусы, сценарии

### 🧑‍💼 Роли (users.role)
```
worker — задачи/монтажи/чат/заявки
engineer — +создание задач/АВР
manager/deputy_head — +управление пользователями/удаление
support — техподдержка (ограниченный доступ)
```

### 📋 Статусы задач (tasks.status)
```
new → in_progress → waiting_materials → done → archived (24h auto)
overdue (blink-red anim)
```

### 🔧 Монтажи (installations)
```
status: new/planned/in_progress/done
SK1..SK7: id_sk/naimenovanie/status/tip_sk
geo: address/id_ploshadki/rayon
```

### 📦 Заявки/закупки
```
materials_requests: pending/approved/rejected
purchase_requests: pending/in_order/ready_for_receipt/received
```

### 💬 Чат
```
private/group/jobs
realtime messages + reactions + read receipts
popup: pin/mute/delete-for-all
```

### 🗺️ Карта
```
manual_addresses (user-created)
user_locations (9-18 realtime для manager)
```

### 📱 Sitemap (Expo Router)
```
/auth (Login/Register/Recovery)
 /(app)
  /index (Dashboard stats)
  /tasks (list/filter/[id])
  /avr (list/filter/[id])
  /installations (list/filter/[id])
  /messages (chats/[id])
  /profile
  /map (площадки/сотрудники)
```

### 🎯 User Flows (MVP)
```
1. Auth → role check → Dashboard (stats)
2. Tasks: list→filter(status)→detail→change status→comment
3. AVR: list→detail (old/new equipment)
4. Installations: list→detail (SK1-7)→status update
5. Push: deep link to tasks/installations
6. Profile: FCM token + external creds (ATS)
```

