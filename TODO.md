# Korneo Mobile: Полная реализация плана (до Этапа 9)

## ✅ Этап 1: Audit & Decomposition
- [x] APPLICATION_DOCUMENTATION.md
- [x] DOMAIN_MAP.md
- [x] packages/domain/types.ts (User/Task/Installation/AvrTask/Chat/Message)
- [x] apps/mobile/korneo-mobile (Expo + Router + NativeWind + AuthContext)

## 🔄 Этап 2: Backend & Auth (95%)
- [x] Supabase client (src/config/supabase.ts)
- [x] AuthContext + session restore
- [x] Login/Register screens
- [x] Role-aware routing (_layout.tsx)
- [ ] Recovery screen

## ⏳ Этап 3: Navigation & Core UI (70%)
- [x] Expo Router: AuthStack + MainTabs
- [x] Dashboard (role-stats, cyberpunk UI)
- [x] Design system (Tailwind/NativeWind, dark/matrix)
- [ ] Детали экранов (tasks/[id], etc.)

## ⏳ Этап 4: Tasks (50%)
- [x] Список задач + фильтры status
- [ ] Детали задачи + change status + comments

## ⏳ Этап 5: AVR + Installations (50%)
- [x] Списки AVR/Installations + фильтры
- [ ] Детали + update status/actions

## ⏳ Этап 6: Push Notifications (0%)
- [ ] Expo Notifications + device token
- [ ] Deep linking

## ⏳ Этап 7: Geo & Map (0%)
- [ ] Foreground location + Mapbox

## ⏳ Этап 8: Messenger (0%)
- [ ] Chats list + detail + media

## ⏳ Этап 9: CI/CD (20%)
- [ ] EAS Build workflows

**✅ Выполнено**:
1. [x] package.json в apps/mobile/korneo-mobile
2. [x] packages/api/supabase.ts (queries: tasks/installations/update)

**✅ Этапы 3-5 ~90%**:
- [x] tasks/[id].tsx (details/status/comments)
- [x] avr/[id].tsx
- [x] installations/[id].tsx (SK data)
- [x] profile.tsx (FCM + settings)

**🔄 Next (Этап 6 Push)**:
1. `npm install expo-notifications` (уже в package.json)
2. NotificationsContext + token register
3. Deep links config
4. `npx expo start --web` test MVP

**Команды** (cmd):
```
cd /d "c:/Users/Tkolya/Desktop/мои/OOO Korneo/apps/mobile/korneo-mobile"
npm install
npx expo start --web
```




**Команды**:
```
cd apps/mobile/korneo-mobile
npm install
npx expo doctor
npx expo start --web
```

