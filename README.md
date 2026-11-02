# SANCHARYA — Mobile Application (Flutter)

SANCHARYA is an offline-first agricultural advisory application built for Indian farmers. It provides real-time mandi wholesale prices, spoilage risk evaluation, price forecasting, nearby resource discovery (cold storages & genuine APMC produce mandis), NGO donation directories, and bilingual voice guidance (Hindi & English).

---

## Architecture & Integration

- **Frontend**: Flutter (Android, iOS, Web, Desktop)
- **Backend**: FastAPI Python API (`https://github.com/Umar-Khan08/sancharya-backend.git`)
- **Mandi Data Pipeline**: Official `data.gov.in` Agmarknet feed (`resource/9ef84268-d588-465a-a308-a864a43d0070`), backed by Neon PostgreSQL storage with offline fallback (`assets/data/mandis.json`).
- **Nearby Mandi Filtering**: Strict exclusion of cloth, textile, garment, and non-agricultural markets, preserving genuine APMC produce and subzi mandis.
- **Farmer Search History**: Local persistent search history across sessions via `SharedPreferences`.

---

## Prerequisites

- Flutter SDK: `^3.x` / Dart `^3.x`
- Java JDK: 17+ (for Android builds)
- Android SDK: API Level 34+

---

## Setup & Running Locally

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run tests**:
   ```bash
   flutter test
   ```

3. **Analyze codebase**:
   ```bash
   flutter analyze
   ```

4. **Run on connected device/emulator**:
   ```bash
   flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000
   ```

---

## Building the Release APK

To generate a standalone release APK for direct installation or website distribution:

```bash
flutter build apk --release
```

The compiled release APK is located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Website Integration & Teammate Distribution

When linking to this application from the Sancharya website:
- **Button Label**: `Download Android App (APK)`
- **File Type**: Android Application Package (`.apk`)
- **Version**: `2.0.0`
- **Recommended HTML Snippet**:
  ```html
  <a href="https://github.com/Umar-Khan08/sancharya-app/releases/latest/download/app-release.apk" class="btn btn-primary">
    Download Android App (v2.0.0 APK)
  </a>
  ```
