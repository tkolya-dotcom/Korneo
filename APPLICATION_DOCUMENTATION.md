# APPLICATION_DOCUMENTATION.md
## Сводный документ по продукту OOO Korneo (v1.38 → Expo v2.0)

### 🎯 Бизнес-цель
Корпоративная система для **строительной компании** (монтажи СК, АВР/НРД, склад, персонал). **5 ролей**: worker/engineer/manager/deputy_head/support.

### 📊 Домен (29 таблиц)
```
users (roles, fcm_token, online)
projects
tasks (short_id, status: new/in_progress/completed)
tasks_avr (АВР/НРД)
installations (СК1..СК7, ats_plan)
chats/jobs/messages (realtime)
materials/warehouse/requests (склад/заявки)
purchase_requests (закупки)
user_locations (geo 9-18)
archive/notification_queue
```

### 🛡️ RLS (113 политик)
- **Users**: own profile + manager видит всех
- **Tasks/Installations**: assignee/creator/manager
- **Messages**: chat members only
- **Requests**: requester/manager

### 🔌 Интеграции
| Сервис | Цель |
|--------|------|
| Supabase | Auth/Realtime/Edge (push-send) |
| Firebase FCM | Push (Web+Android closed) |
| Mapbox GL | Площадки/сотрудники |
| Capacitor | Android APK auto-update |

### 📱 Текущий UI/UX
- **Dark cyberpunk**: #0A0A0F + cyan(#00D9FF)/green(#00FF88), Orbitron
- **PWA монолит**: 19k строк index.html + SW
- **Mobile nav**: Top tabs + bottom bar
- **Status badges**: new/in_progress/done/overdue (glow/animations)

### 🚀 Production метрики
- **Push**: 100% (FCM v1 + VAPID)
- **Realtime**: Chats/comments (Supabase)
- **Offline**: SW cache + notification_queue
- **Geo**: Foreground (9-18), manager видит на Mapbox
- **Scale**: GitHub Actions APK, version.json OTA

### 🎨 Design system (для Expo)
```
Colors: --primary:#0A0A0F, --accent:#00D9FF, --accent2:#00FF88
Fonts: Orbitron (headers), Inter (body)
Components: Card, StatusBadge, NavBtn, SwipeList
Animations: Glow pulse, slideUp modals
```

**MVP для Expo**: Auth → Dashboard → Tasks/AVR/Installations + Push + Profile.

