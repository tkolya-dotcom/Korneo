# iOS Signing Setup (Apple Developer Required)

Для установки IPA на физический iPhone требуется платная подписка **Apple Developer Program**.

## Что обязательно

1. Активная подписка Apple Developer Program на аккаунте команды.
2. Team ID (Apple Developer Team).
3. App Store Connect API Key (`.p8`, `Key ID`, `Issuer ID`).
4. Bundle ID приложения, зарегистрированный в Apple Developer.
5. Для установки development/ad-hoc IPA на телефон:
- устройство должно быть доверенным,
- для ad-hoc нужно добавить UDID устройства в профиль.

## GitHub Secrets

Добавьте в репозиторий secrets:

- `APPLE_TEAM_ID`
- `APPLE_BUNDLE_ID` (если не задано, workflow использует `com.korneo.ios`)
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`
- `APPLE_API_PRIVATE_KEY` (содержимое `.p8`)
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `DAICHI_TOKEN` (опционально)

## Как запустить сборку IPA

1. Откройте **Actions** в GitHub.
2. Выберите workflow **Build iOS IPA**.
3. Нажмите **Run workflow** на ветке `main`.
4. После завершения скачайте артефакт `korneo-ios-ipa`.

## Важно

- Этот workflow собирает `development` IPA с automatic signing.
- Если Apple не сможет автоматически выдать профиль, проверьте права аккаунта и настройки сертификатов/идентификаторов в Apple Developer.
- Для TestFlight/App Store нужен отдельный export method (`app-store`) и процесс публикации.
