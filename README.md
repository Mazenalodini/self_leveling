# Self Leveling

**An intelligent behavioral intervention system for Android** that monitors device usage patterns, applies adaptive escalation policies, and leverages AI-powered coaching — built with Flutter, Kotlin, Firebase, and on-device TensorFlow Lite inference.

---

## Overview

Self Leveling is a personal development application that helps users build healthier digital habits through real-time behavioral monitoring and progressive intervention. The system combines native Android usage tracking with a Flutter-based UI to deliver a gamified self-improvement experience.

Rather than simply blocking apps, Self Leveling uses a multi-layered escalation engine — from gentle notifications to full overlay lockouts — that adapts in real time based on the user's behavioral risk score. An on-device TensorFlow Lite model and a rule-based risk engine work together (hybrid approach) to predict high-risk usage patterns without sending data off-device.

---

## Key Features

### Behavioral Monitoring & Intervention
- **Real-time app usage tracking** via Android `UsageStatsManager` and Accessibility Services
- **Hybrid behavioral risk engine** combining a quantized TFLite model with rule-based heuristics
- **Multi-stage escalation system** — notifications → limited access → overlay lock → hard lock
- **App classification** (productive / neutral / destructive) with per-app policy management
- **Foreground service** for persistent background monitoring that survives device reboots

### AI-Powered Coaching
- **Conversational AI chat** powered by Firebase AI (Gemini) with local-first fallback messaging
- **Context-aware recommendations** based on current habits, usage patterns, and user profile
- **Chat safety guard** with multi-vector prompt injection protection
- **Configurable AI provider** supporting Firebase AI and proxy-based endpoints

### Gamification & Progression
- **XP and leveling system** tied to real behavioral improvements
- **Dungeon challenges** — structured goal-based missions
- **Skill trees** with branching progression paths
- **Identity builder** — narrative-driven character development
- **Achievement overlays** for milestone rewards
- **Level-up rewards** and progression projections

### Habit Management
- **Custom habit creation** with flexible scheduling (daily / weekly / custom)
- **Habit priority system** with streak tracking
- **Completion tracking** with automatic daily resets
- **Local notification reminders** with exact alarm scheduling

### Focus Mode
- **Timed focus sessions** with configurable duration
- **Session completion tracking** and XP rewards
- **Distraction blocking** during active sessions

### Analytics & Reporting
- **Usage dashboard** with per-app time breakdowns
- **Weekly review** with behavioral trend analysis
- **Statistical charts** via `fl_chart`
- **Behavior category distribution** and escalation history

### Authentication & Cloud Sync
- **Firebase Authentication** (Email/Password + Google Sign-In)
- **Cloud Firestore** for profile sync and cloud-backed data
- **Firebase App Check** (Play Integrity) for API security

### Localization
- **Bilingual support** — English and Arabic
- **RTL layout support** with dynamic directionality
- **60,000+ characters** of localized strings

---

## Technology Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (Dart SDK ≥ 3.5.3) |
| **State Management** | Riverpod |
| **Navigation** | GoRouter |
| **Native Platform** | Kotlin (Android) |
| **AI / ML** | Firebase AI (Gemini), TensorFlow Lite |
| **Authentication** | Firebase Auth, Google Sign-In |
| **Cloud Database** | Cloud Firestore |
| **Local Database** | SQLite (sqflite) |
| **Local Storage** | SharedPreferences |
| **Notifications** | flutter_local_notifications, exact alarms |
| **Charts** | fl_chart |
| **Animations** | flutter_animate |
| **Typography** | Google Fonts |
| **Security** | Firebase App Check (Play Integrity) |

---

## Architecture

The project follows a **layered architecture** with clear separation of concerns:

```
lib/
├── main.dart                     # App entry point, service initialization
├── core/
│   ├── config/                   # API key configuration
│   ├── constants/                # Localized strings (EN/AR)
│   ├── database/                 # SQLite database helper
│   ├── localization/             # App localization logic
│   ├── theme/                    # Dark theme, colors, typography, effects
│   └── utils/                    # Formatters, feedback utilities
├── data/
│   └── repositories/             # Data access layer (Firestore, SQLite, Auth)
├── domain/
│   ├── contracts/                # Runtime behavior contracts
│   ├── entities/                 # Core data models
│   ├── enums/                    # Behavior categories, escalation levels
│   └── services/                 # Domain rules (progression, reminders)
├── features/
│   ├── ai/                       # AI chat (services, providers, screens, domain)
│   ├── dashboard/                # Main dashboard screen
│   ├── dungeons/                 # Gamified challenge system
│   ├── focus/                    # Focus mode sessions
│   ├── habits/                   # Habit CRUD and tracking
│   ├── identity/                 # Identity builder & skill trees
│   ├── profile/                  # User profile settings
│   ├── settings/                 # App settings, blacklist, escalation config
│   ├── stats/                    # Usage analytics and weekly review
│   └── system/                   # Auth screens, onboarding, setup, overlays
├── navigation/                   # GoRouter config, shell, surface registry
├── platform/                     # Platform channel (Flutter ↔ Kotlin bridge)
├── providers/                    # Global Riverpod providers
├── services/                     # Business services (behavior, habits, XP, focus)
└── widgets/                      # Reusable UI components
```

### Native Android Layer (Kotlin)

The Android layer implements the core behavioral monitoring engine:

```
android/app/src/main/kotlin/com/selfleveling/self_leveling/
├── MainActivity.kt                      # Flutter ↔ Native platform channel host
├── TrackingService.kt                   # Foreground service for usage monitoring
├── ForegroundAccessibilityService.kt    # Accessibility-based foreground detection
├── HybridBehaviorRiskEngine.kt          # Orchestrates TFLite + rule-based engines
├── TFLiteBehaviorRiskEngine.kt          # On-device ML inference
├── RuleBasedBehaviorRiskEngine.kt       # Heuristic risk assessment
├── BehaviorFeatureExtractor.kt          # Feature engineering for ML model
├── BehaviorRiskAssessor.kt              # Risk scoring and thresholds
├── EscalationEvaluator.kt               # Multi-stage escalation logic
├── EscalationStateMachine.kt            # State machine for intervention levels
├── InterventionNotifier.kt              # Notification-based interventions
├── OverlayManager.kt                    # System overlay lockout UI
├── AppClassifier.kt                     # App categorization engine
├── UsageStatsHelper.kt                  # Android UsageStats API wrapper
├── NativeDatabaseAccess.kt              # Direct SQLite access from native
├── NativeRuntimeStore.kt                # Native-side runtime state
├── NativeUsageSnapshotStore.kt          # Usage data snapshots
├── MessagingBridge.kt                   # Flutter ↔ Native messaging
├── BootReceiver.kt                      # Restart service on device boot
└── RuntimeContracts.kt                  # Shared contract definitions
```

### On-Device ML Model

```
android/app/src/main/assets/
├── behavior_model_quantized.tflite      # Quantized TFLite behavior prediction model
├── model_config.json                    # Model architecture configuration
└── normalization_stats.json             # Feature normalization parameters
```

---

## Android Permissions

| Permission | Purpose |
|---|---|
| `INTERNET` | Firebase, AI chat, cloud sync |
| `PACKAGE_USAGE_STATS` | App usage time tracking |
| `SYSTEM_ALERT_WINDOW` | Overlay lockout interventions |
| `FOREGROUND_SERVICE` | Persistent background monitoring |
| `POST_NOTIFICATIONS` | Intervention & habit reminders |
| `SCHEDULE_EXACT_ALARM` | Precise notification scheduling |
| `RECEIVE_BOOT_COMPLETED` | Restart tracking after reboot |
| `QUERY_ALL_PACKAGES` | Enumerate installed apps |
| `BIND_ACCESSIBILITY_SERVICE` | Real-time foreground app detection |

---

## Prerequisites

- **Flutter SDK** ≥ 3.5.3
- **Dart SDK** ≥ 3.5.3
- **Android SDK** with `compileSdk 35`
- **Android NDK** 25.1.8937393
- **Java 17**
- **Firebase project** with Authentication, Firestore, AI, and App Check enabled

---

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/<your-username>/self-leveling.git
cd self-leveling
```

### 2. Firebase Configuration

Place your Firebase configuration file in the Android app directory:

```
android/app/google-services.json
```

> Generate this file from the [Firebase Console](https://console.firebase.google.com/) under **Project Settings → General → Your apps → Android**.

Required Firebase services:
- **Authentication** (Email/Password + Google Sign-In providers)
- **Cloud Firestore**
- **Firebase AI** (Gemini model access)
- **App Check** (Play Integrity provider)

### 3. AI Chat Configuration

Example configuration templates are included in the repository under `.env/`. Copy the appropriate example to create your local runtime configuration:

```bash
cp .env/ai_chat.example.json .env/ai_chat.json
```

Adjust the values in `.env/ai_chat.json` for your environment. For proxy-based providers, use `.env/ai_chat.proxy.example.json` as a starting template instead.

> **Note:** `.env/ai_chat.json` is gitignored — only the example templates are committed.

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Run the Application

```bash
flutter run
```

### 6. Run Tests

```bash
flutter test
```

---

## Configuration Notes

- **`api_keys.dart`** is gitignored. The app uses Firebase AI by default, so no client API key is required. For OpenAI-compatible providers, pass keys via `--dart-define` at build time.
- **`google-services.json`** is gitignored. Each developer must supply their own Firebase config.
- **`local.properties`** is gitignored. It is auto-generated by Android Studio with local SDK paths.
- **`.env/`** — Only `*.example.json` templates are committed. Runtime config files (e.g., `ai_chat.json`) are gitignored. Copy an example file and adjust values locally.

---

## Build

### Debug

```bash
flutter run --debug
```

### Release

```bash
flutter build apk --release
```

---

## Project Stats

| Metric | Count |
|---|---|
| Dart source files | ~80+ |
| Kotlin source files | 26 |
| Unit tests | 22 |
| Feature modules | 10 |
| Domain entities | 14 |
| Repositories | 8 |
| Services | 10+ |
| Localized string keys | 500+ |

---

## License

This project is proprietary. All rights reserved.
