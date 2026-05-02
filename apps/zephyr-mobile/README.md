# zephyr-mobile

Flutter mobile app for Zephyr.

## MVP status

This app is wired to the Zephyr API MVP endpoints:

- `POST /v1/auth/guest-login`
- `POST /v1/auth/google-login`
- `POST /v1/auth/apple-login`
- `GET /v1/users/me`
- `GET /v1/rooms`
- `POST /v1/rooms`
- `POST /v1/rooms/:roomId/join`

Google sign-in button is included, but it requires platform OAuth configuration
(GoogleService-Info.plist for iOS, google-services.json for Android, and
matching OAuth client IDs).

Apple sign-in button is included, and requires Apple Developer setup for the
app ID/capability plus `APPLE_CLIENT_ID` configured on backend.

## Run locally

1. Start backend (`services/zephyr-api`) on port `3000`
2. Run Flutter app with a reachable API base URL

Default API base URL in app code:

- `http://localhost:3000`

For Android emulator, use `10.0.2.2`:

```zsh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

For iOS simulator on macOS:

```zsh
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## Validate

```zsh
flutter test
```
