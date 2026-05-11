# iOS IPA Build Setup (GitHub Actions)

This guide configures IPA build for this repository using `.github/workflows/build-ios-ipa.yml`.

## 1. Apple account requirement

To install IPA on a physical iPhone, the Apple Developer Program is required.

- Account type: Apple Developer Program (paid)
- Access needed: App Store Connect + Certificates, Identifiers & Profiles

Without this, `Build iOS IPA` cannot sign the app for device install.

## 2. Required repository secrets

Open GitHub repository settings:

- `Settings -> Secrets and variables -> Actions -> New repository secret`

Create these secrets:

1. `APPLE_TEAM_ID`
2. `APPLE_API_KEY_ID`
3. `APPLE_API_ISSUER_ID`
4. `APPLE_API_PRIVATE_KEY` (full `.p8` content)
5. `APPLE_BUNDLE_ID` (optional, default is `com.korneo.ios`)
6. `SUPABASE_URL` (or `VITE_SUPABASE_URL`)
7. `SUPABASE_ANON_KEY` (or `VITE_SUPABASE_ANON_KEY`)

## 3. How to get Apple API credentials

In App Store Connect:

1. `Users and Access -> Integrations -> App Store Connect API`
2. Create API key with access to certificates/profiles
3. Save:
   - Key ID -> `APPLE_API_KEY_ID`
   - Issuer ID -> `APPLE_API_ISSUER_ID`
   - Downloaded `.p8` file content -> `APPLE_API_PRIVATE_KEY`

Team ID:

1. Open Apple Developer account
2. Copy Team ID -> `APPLE_TEAM_ID`

## 4. Run IPA workflow

After secrets are configured:

1. Push to `main` touching `ios/**`, or
2. Manually run `Build iOS IPA` in GitHub Actions.

Artifact output:

- `korneo-ios-ipa` (contains `.ipa`)

## 5. Current status check

`gh secret list` currently shows only:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

So Apple signing secrets are still missing and IPA build will fail until they are added.
