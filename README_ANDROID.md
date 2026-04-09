# Корнео — Android-приложение

Android-приложение для ООО Корнео. Загружает веб-версию в WebView и поддерживает FCM push-уведомления.

## Скачать APK

1. Перейдите в [GitHub Releases](../../releases)
2. Скачайте файл `app-debug.apk` из последнего релиза
3. На телефоне: **Настройки** > **Безопасность** > включите **Установка из неизвестных источников** (для вашего браузера)
4. Откройте скачанный файл и установите

> На Android 8+ разрешение запрашивается при первой установке автоматически.

## Firebase — настройка push-уведомлений

Для работы фоновых push-уведомлений нужен настоящий `google-services.json`:

1. Откройте [Firebase Console](https://console.firebase.google.com/)
2. Выберите проект **planner-web-4fec7**
3. Перейдите в **Project Settings** > **General**
4. В разделе **Your apps** нажмите **Add app** > **Android**
5. Укажите package name: `com.korneo.app`
6. Нажмите **Register app**
7. Скачайте `google-services.json`
8. Замените файл `android/app/google-services.json` в репозитории
9. Запушьте изменения — GitHub Actions пересоберёт APK

## Сборка вручную

### Требования
- Java 17 (JDK)
- Android SDK (compileSdk 34)

### Команды
```bash
cd android
chmod +x gradlew
./gradlew assembleDebug
```

APK будет в `android/app/build/outputs/apk/debug/app-debug.apk`.

## Автосборка через GitHub Actions

При каждом push в `main` запускается workflow `Build Android APK`:
- Собирает debug APK
- Загружает как артефакт
- Создаёт GitHub Release с APK-файлом

## Архитектура

- **WebView** загружает https://tkolya-dotcom.github.io/Korneo/
- **Firebase Cloud Messaging** — нативные push-уведомления (даже когда приложение закрыто)
- **Capacitor 6.x** конфигурация для совместимости
- Внешние ссылки открываются в браузере
