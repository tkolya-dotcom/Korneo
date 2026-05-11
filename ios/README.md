# Korneo iOS (iOS 26)

This folder contains the iOS app that mirrors the Android app and uses the same Supabase backend/data.

## What is already implemented

- SwiftUI app skeleton for iOS 26 (`KorneoIOSApp`, root navigation, tabs).
- Auth via Supabase REST (`auth/v1/token`).
- Token persistence in Keychain.
- Auto refresh token flow on `401`.
- Data loading from the same tables used by Android:
  - `users`
  - `projects`
  - `tasks`
  - `chats`
  - `installations`
- Installations feature:
  - list
  - create
  - edit
- Runtime connection settings on auth screen (URL + anon key).
- Dashboard with Android-like sections:
  - Projects / Tasks / Installations / Purchase Requests
  - Users / Warehouse / Catalog / AVR / Sites / ATSS / Archive / Calendar
- Chats:
  - chats list
  - chat detail
  - send message
  - typing status sync (`chat_typing`)
  - auto mark messages as read
- Push:
  - APNs registration scaffolding
  - sync device token to Supabase (`functions/v1/push-register`, fallback to `users.fcm_token`)
- Mileage:
  - records list
- Map:
  - Map screen based on `MapKit`
  - points from `user_locations` (filtered by current user)
  - points from `jobs` and `installations` when coordinates are available
- Profile:
  - user info
  - backend settings
  - logout
- Projects and Tasks:
  - list
  - create
  - edit
  - detail screen
- Tasks:
  - status transitions flow
- Installations:
  - list
  - create
  - edit
  - detail screen
  - status transitions flow
- Purchase Requests:
  - list
  - create
  - detail screen
  - status transitions flow

## Generate Xcode project (on macOS)

1. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```
2. Go to the `ios` folder and prepare config:
   ```bash
   cp Configs/Config.xcconfig.example Configs/Config.xcconfig
   ```
3. Fill `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `Configs/Config.xcconfig`.
   You can also update these values directly in the app on the login screen.
4. Generate project:
   ```bash
   xcodegen generate
   ```
5. Open `KorneoIOS.xcodeproj` in Xcode and run on simulator/device.

## Important

- Android and iOS must use the same Supabase project URL and key.
- Do not use `service_role` key in mobile apps.
- RLS policies in Supabase must allow the same role behavior for both clients.

## IPA signing and device install

- See [SIGNING_SETUP.md](./SIGNING_SETUP.md) for Apple Developer subscription requirements and GitHub secrets.
- GitHub Actions workflow for IPA: `.github/workflows/build-ios-ipa.yml`.

## CI workflows

- Simulator build (no Apple signing required): `.github/workflows/build-ios-simulator.yml`
- IPA build for physical iPhone install (Apple signing required): `.github/workflows/build-ios-ipa.yml`
