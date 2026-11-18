# Modern Classes Patna - Educational Institute Platform

A production-grade mobile learning and institutional management application built for **Modern Classes Patna**.

---

## 🏗️ Architecture & Tech Stack

- **Mobile Client:** Flutter (Dart, Android-first)
- **Backend & Database:** Supabase (PostgreSQL with Row Level Security)
- **Authentication:** Supabase Auth (Role-Based Access Control: Student, Faculty, Admin)
- **Payments:** Google Play Billing (for Android digital in-app course enrollments)
- **Notifications:** Firebase Cloud Messaging (FCM)
- **Design System:** Custom dark modern theme tailored with official Modern Classes branding

---

## 📁 Project Directory Layout

```
lib/
├── core/                  # Core modules, configs, utilities, widgets & theme
│   ├── config/            # AppConfig and environment variables
│   ├── theme/             # Modern Classes color scheme and typography
│   ├── utils/             # Responsive helpers and formatters
│   └── widgets/           # Reusable UI components (AppLogo, AppScaffold, Badges)
├── data/                  # Data repositories and seed datasources
├── models/                # Typed data models (User, Course, Batch, Test, Doubt)
├── providers/             # State management providers
├── screens/               # User interfaces by role (Auth, Student, Teacher, Admin)
└── main.dart              # Application entrypoin

### 1. Prerequisites
- Flutter SDK (v3.24+ recommended)
- Android SDK (API 34+)
- Git

### 2. Environment Configuration
Copy the template file to `.env` and provide your development credentials:
```bash
cp .env.example .env
```

### 3. Install Dependencies & Run
```bash
# Clean and fetch packages
flutter pub get

# Run on connected Android device or Chrome
flutter run -d chrome
# OR
flutter run -d android
```
flutter run -d A101BM
---

## 🔐 Security & Secrets
- Never commit `.env`, keystores, or private credentials to source control.
- All secrets are excluded in `.gitignore`.

