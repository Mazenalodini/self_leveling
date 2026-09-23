# Self Leveling

**An intelligent behavioral intervention system for Android** that monitors device usage patterns, applies adaptive interventions, and provides AI-powered coaching to help users build healthier digital habits.

---

## Overview

Self Leveling is an Android behavioral intervention application built with Flutter and Kotlin. It combines real-time device usage monitoring, behavioral risk assessment, adaptive intervention, AI-powered coaching, habit management, analytics, and gamified progression into a single system.

Unlike traditional screen-time blockers that rely primarily on static rules or binary blocking, Self Leveling evaluates behavioral context and responds progressively. Usage patterns are processed through a behavioral decision pipeline that can move from passive monitoring and notifications toward stronger interventions when risky behavior persists.

The application is divided into two major runtime areas:

- **Flutter Application Layer** — user interface, application features, state management, navigation, habits, gamification, analytics, AI chat, and configuration.
- **Android Native Runtime Layer** — continuous usage monitoring, foreground detection, behavioral risk processing, escalation decisions, overlays, notifications, and other Android system-level capabilities.

The two layers communicate through a structured Flutter ↔ Kotlin platform bridge, allowing the native runtime to remain authoritative over enforcement while Flutter provides the main application experience.

---

## Problem & Approach

Traditional app-blocking tools commonly use fixed rules such as time limits or immediate blocking. These approaches do not always account for the context surrounding device usage.

Self Leveling approaches the problem as a behavioral intervention system:

1. **Monitor** device usage and foreground applications.
2. **Extract behavioral context** from sessions, launches, re-entries, time, app category, limits, and related state.
3. **Assess behavioral risk** using on-device machine learning and rule-based analysis.
4. **Evaluate escalation state** using deterministic transition rules.
5. **Deliver an intervention** through notifications, overlays, limited access, or stronger lock states.
6. **Provide coaching and feedback** through AI, habits, focus sessions, analytics, and progression systems.

The goal is to make intervention adaptive rather than purely binary.

---

## System Architecture

### High-Level Flow

```text
User Device Usage
        │
        ▼
Usage Monitoring
(Android Native)
        │
        ▼
Behavior Feature Extraction
        │
        ▼
Behavioral Risk Assessment
(TFLite + Rule-Based)
        │
        ▼
Escalation Decision
(Deterministic State Machine)
        │
        ▼
Intervention Delivery
(Notifications / Overlays / Limited Access)
        │
        ▼
Flutter Application Layer
(AI / Habits / Focus / Analytics / Progression)
```

### Runtime Boundaries

The architecture maintains a clear boundary between the user-facing application and the Android enforcement runtime.

**Flutter** is responsible for application features and presentation.

**Kotlin / Android** is responsible for capabilities that depend on Android system APIs and runtime enforcement.

The native runtime publishes authoritative runtime state to Flutter, allowing the UI to reflect the actual enforcement state rather than independently controlling it.

---

## Adaptive Escalation Architecture

The behavioral intervention pipeline is organized into three conceptual layers.

### Layer A — Risk Assessment

This layer evaluates the current behavioral context and produces a risk signal using:

- Behavioral feature extraction
- TensorFlow Lite inference
- Rule-based heuristics
- App category context
- User sensitivity and configuration
- Current runtime state

### Layer B — Escalation State Machine

The escalation engine uses a deterministic state machine to progressively change intervention intensity.

```text
S0 → S1 → S2 → S3 → S4 → S5
```

Where:

- **S0 — Monitoring**: passive observation.
- **S1 — Warning**: initial intervention notification.
- **S2 — Reminder**: stronger reminder intervention.
- **S3 — Temporary Block**: full-screen overlay intervention.
- **S4 — Limited Access**: controlled re-entry period.
- **S5 — Hard Lock**: stronger extended restriction.

The state machine also supports de-escalation when behavioral risk decreases and handles lock expiration and lifecycle transitions.

### Layer C — Escalation Orchestrator

`EscalationEvaluator` coordinates the complete intervention lifecycle.

It is responsible for:

- Applying state transitions
- Managing active lock state
- Building intervention payloads
- Persisting runtime state where required
- Coordinating notification and overlay delivery
- Requesting intervention text through the AI bridge

This separation keeps the decision model deterministic while allowing delivery and application concerns to remain independently managed.

---

## Behavioral Risk Engine

Self Leveling uses a hybrid behavioral risk architecture rather than relying on a single decision source.

### Behavior Feature Extraction

`BehaviorFeatureExtractor` converts runtime information into deterministic behavioral features.

These features can include:

- Session duration
- Launch activity
- Daily usage
- Distracting usage
- Daily limits
- Warning history
- Re-entry behavior
- Time of day
- Day of week
- User sensitivity
- Escalation strength
- Focus mode
- App category
- Current escalation state

### TensorFlow Lite

`TFLiteBehaviorRiskEngine` loads the on-device behavioral model and performs local inference.

The model pipeline includes:

- Feature preparation
- Normalization using stored statistics
- TensorFlow Lite inference
- Risk score generation
- Fallback handling when the model cannot be loaded

The model is stored locally in the Android application assets and inference is performed on-device.

### Rule-Based Risk Assessment

`RuleBasedBehaviorRiskEngine` provides deterministic heuristic evaluation based on known behavioral patterns and runtime context.

This provides a predictable baseline independent of the machine learning model.

### Hybrid Risk Processing

`HybridBehaviorRiskEngine` combines the machine learning output with the rule-based result before passing the final assessment into the escalation pipeline.

This allows the system to combine learned behavioral patterns with explicit behavioral rules.

---

## AI & Machine Learning Architecture

The project contains two separate AI paths:

```text
Behavioral ML
    │
    ├── Feature Extraction
    ├── TFLite Inference
    ├── Rule-Based Assessment
    └── Risk Decision
```

and:

```text
Generative AI
    │
    ├── Context Building
    ├── Local Message Generation
    ├── Cloud AI Enhancement
    └── Conversational Coaching
```

The behavioral ML system is focused on **decision support for intervention**, while Generative AI is focused on **communication, coaching, and personalized messaging**.

### On-Device Inference

Behavioral inference is executed locally through TensorFlow Lite.

This design keeps behavioral model processing on the device rather than requiring behavioral signals to be sent to a cloud model.

### Model Assets

The Android application includes:

```text
android/app/src/main/assets/

├── behavior_model_quantized.tflite
├── model_config.json
└── normalization_stats.json
```

The repository contains the runtime model and configuration required by the application. Training and model evaluation artifacts are not part of this repository.

---

## Generative AI / AI Coaching

Self Leveling provides conversational AI coaching using **Firebase AI / Gemini**.

The AI subsystem is designed around a local-first architecture.

### Local-First Messaging

`LocalMessageGenerator` can generate intervention messages locally using:

- User profile information
- Language
- Behavioral state
- Habit context

This allows intervention messaging to continue even when cloud connectivity is unavailable.

### Cloud AI

`AICloudProvider` integrates cloud-based generative AI for enhanced conversational and intervention experiences.

The project supports Firebase AI and configurable proxy-based providers.

### Context-Aware AI

`ChatContextService` builds contextual information before AI requests are made, allowing responses to be informed by the application's behavioral and user context.

### Chat Safety

`ChatGuard` validates AI input before cloud submission and contains protections against several prompt-injection and instruction-manipulation patterns.

The guard is designed to prevent attempts to:

- Override system behavior through authority framing
- Extract protected information
- Hijack expected response formats
- Extract internal instructions
- Abuse symbolic or encoded input patterns

### Native AI Bridge

`AIBridgeService` connects the native Android runtime with the Flutter AI layer.

This allows native intervention components to request context-aware text without embedding cloud AI logic directly inside the Android enforcement engine.

---

## Android Native Runtime

Several core capabilities of Self Leveling depend on Android system APIs and therefore require native Kotlin integration.

### TrackingService

`TrackingService` provides persistent background monitoring and coordinates runtime enforcement.

### ForegroundAccessibilityService

`ForegroundAccessibilityService` provides foreground application detection and complements usage polling when more immediate state information is required.

### UsageStatsHelper

`UsageStatsHelper` integrates Android's `UsageStatsManager` for application usage information.

### AppClassifier

`AppClassifier` categorizes applications into behavioral categories such as:

- Productive
- Neutral
- Distracting
- Essential
- User-defined

The classification system also supports user overrides and protection for essential system applications.

### OverlayManager

`OverlayManager` renders native system overlays for intervention states.

It manages:

- Lock presentation
- Warning interfaces
- Limited-access states
- Hard-lock states
- Countdown behavior
- Overlay lifecycle

### InterventionNotifier

`InterventionNotifier` handles notification-based interventions for escalation stages that do not require a full overlay.

### BootReceiver

`BootReceiver` restores the monitoring runtime after device boot so the behavioral engine can continue operating across device restarts.

---

## Flutter ↔ Kotlin Integration

Communication between Flutter and Android Native is implemented through Platform Channels and a shared runtime contract.

### MethodChannel

```text
com.selfleveling/system
```

Used for bidirectional request-response operations such as:

- Starting and stopping the runtime
- Permission operations
- Usage requests
- Overlay operations
- Focus mode changes
- AI intervention requests

### EventChannel

```text
com.selfleveling/state_stream
```

Used for native-to-Flutter runtime state streaming.

The native layer publishes `RuntimeStateSnapshot` information and Flutter consumes it to render the current application state.

### RuntimeContract

The shared runtime contract defines the communication semantics between Dart and Kotlin, including:

- Channel names
- Method names
- State representations
- Shared mappings
- Runtime payload expectations

This reduces coupling between the Flutter and Android layers and helps keep the platform boundary consistent.

---

## Application Architecture

The Flutter application follows a feature-based layered architecture with clear separation of responsibilities.

```text
lib/
├── main.dart
├── core/
├── data/
├── domain/
├── features/
├── navigation/
├── platform/
├── providers/
├── services/
└── widgets/
```

### `core/`

Contains foundational application infrastructure such as:

- Database configuration
- Localization
- Theme
- Constants
- Shared utilities

### `data/`

Contains repository implementations responsible for data access and persistence.

Examples include access to:

- SQLite
- Firestore
- Authentication
- Application settings
- AI-related data

### `domain/`

Contains application-level domain concepts such as:

- Entities
- Enums
- Runtime contracts
- Business rules
- Progression rules
- Reminder policies

### `features/`

Contains self-contained application feature modules.

```text
features/
├── ai/
├── dashboard/
├── dungeons/
├── focus/
├── habits/
├── identity/
├── profile/
├── settings/
├── stats/
└── system/
```

Each feature groups its related presentation, application, and domain logic.

### `navigation/`

Contains centralized GoRouter configuration and shell routing.

### `platform/`

Contains Flutter ↔ Kotlin platform communication.

### `providers/`

Contains application and feature-level Riverpod providers.

### `services/`

Contains business services responsible for domain-specific application behavior.

### `widgets/`

Contains reusable UI components shared across the application.

---

## State Management & Navigation

### Riverpod

Self Leveling uses **Riverpod** for global and feature-scoped state management.

Services are initialized and injected through application providers rather than relying on unrestricted global singletons.

This supports:

- Clear dependency boundaries
- Testability
- Feature-specific state
- Controlled service access

### System State

The application maintains a Flutter-side read model that combines application data with authoritative native runtime state.

This allows the Flutter UI to represent the actual state of the Android enforcement engine.

### GoRouter

Navigation is implemented using **GoRouter**.

The navigation architecture supports:

- Authentication-aware routing
- Persistent application navigation
- Feature screens
- Focus screens
- System and lock screens
- Overlay-related routes

A shell-based navigation structure keeps persistent application navigation consistent across major features.

---

## Data Architecture

Self Leveling uses a hybrid local/cloud data architecture.

### SQLite

SQLite through `sqflite` provides the primary local persistence layer.

It stores application data such as:

- User profile information
- Habits
- Habit completion history
- Focus sessions
- Behavioral records
- App usage
- Escalation history
- Runtime state
- Progression events
- AI chat history
- Skills and identities
- Dungeon state
- Settings

### Data Ownership

The project maintains clear ownership boundaries between Flutter and Kotlin.

Native Android components are responsible for canonical runtime data such as:

- Usage snapshots
- Behavioral runtime records
- Escalation events

Flutter manages application-level data such as:

- Habits
- Focus sessions
- Progression
- Profiles
- AI chat state

Repositories provide the application layer with a controlled data-access boundary.

### Cloud Firestore

Cloud Firestore is used primarily for user profile synchronization.

`UserProfileRepository` manages the relationship between local profile state and cloud-backed profile data.

### SharedPreferences

SharedPreferences is used for lightweight persistent state such as:

- Locale preferences
- Onboarding flags
- Native lock recovery state

---

## Core Features

### Behavioral Monitoring

- Real-time foreground application monitoring
- Android UsageStats integration
- Accessibility-based foreground detection
- App categorization
- User-defined app policies
- Behavioral context collection

### Adaptive Intervention

- Progressive escalation
- Warning notifications
- Reminder interventions
- Full-screen overlays
- Limited access states
- Hard lock behavior
- Lock persistence and lifecycle handling

### Habit Management

- Habit creation and editing
- Daily, weekly, and custom scheduling
- Streak tracking
- Completion history
- Reminder notifications
- Habit progression and XP integration

### Focus Mode

- Timed focus sessions
- Distraction restriction
- Native escalation policy changes
- Session completion tracking
- Progression rewards

### Analytics

- App usage breakdowns
- Behavioral summaries
- Weekly reviews
- Usage trends
- Escalation history
- Statistical charts

### Authentication

- Firebase Authentication
- Email and password sign-in
- Google Sign-In
- Email verification
- Firebase App Check

### Localization

- English
- Arabic
- Dynamic RTL support
- Locale-aware AI messaging
- Bilingual intervention and gamification content

---

## Gamification & Progression

Gamification is integrated into the application's behavioral model rather than existing as an isolated UI layer.

### Progression Ledger

`ProgressionRepository` and `ProgressionRules` track progression events such as:

- Habit completion
- Focus session completion
- Positive behavioral events
- Intervention-related progression changes

The ledger-oriented design provides a consistent record of progression events and supports rebuilding the current profile state from recorded events.

### Identity Builder

Users can select identity archetypes that influence their progression experience.

Identity choices are connected to skill progression and the application's long-term self-improvement model.

### Skill Trees

The skill system provides branching progression paths.

Completing relevant actions allows users to progress through interconnected skills.

### Dungeon Challenges

Dungeons represent structured behavioral challenges.

Challenges can be tied to real application activity such as:

- Screen-time constraints
- Late-night usage avoidance
- Focus sessions
- Daily behavioral goals

Progress can be tracked automatically from application data where supported.

---

## Analytics & Reporting

The analytics layer transforms stored usage and behavioral records into user-facing reports.

### Usage Dashboard

Provides application usage information and per-app breakdowns.

### Weekly Review

Aggregates behavioral information into trends and review-oriented insights.

### Statistical Visualization

Charts are rendered using `fl_chart` to present usage and behavioral information visually.

---

## Authentication & Security Design

Self Leveling uses several implemented security and configuration controls.

### Firebase Authentication

Authentication supports:

- Email / Password
- Google Sign-In
- Email verification

### Firebase App Check

Firebase App Check is integrated with Play Integrity for production usage and a development configuration for local testing.

### Configuration Isolation

Sensitive or environment-specific configuration is intentionally kept outside the committed source where appropriate.

Examples include:

```text
google-services.json
.env/ai_chat.json
api_keys.dart
```

Only safe configuration templates are committed.

### AI Input Protection

AI requests are passed through `ChatGuard` before cloud submission to reduce the risk of prompt-injection and instruction-manipulation patterns.

### On-Device Behavioral Inference

Behavioral ML inference is performed locally through TensorFlow Lite rather than requiring behavioral input to be sent to a cloud inference service.

> The security mechanisms documented here are implementation-level controls. No independent security audit is included in the repository.

---

## Localization & UI/UX

Self Leveling is designed as a bilingual application with English and Arabic support.

### Localization

- English and Arabic content
- Dynamic locale handling
- RTL directionality
- Localized intervention messages
- Localized gamification content
- Locale-aware AI context

### Design System

The application uses a custom dark visual system with reusable UI components and shared styling.

The design layer includes:

- Custom dark theme
- Reusable cards and buttons
- Progress indicators
- Achievement overlays
- Custom decorative components
- `flutter_animate` animations
- `fl_chart` data visualization
- Google Fonts typography

The interface is designed to keep the behavioral system, progression mechanics, and coaching experience visually consistent.

---

## Engineering Decisions

### Why Flutter + Kotlin?

Flutter provides the main application UI and feature architecture, while Kotlin provides direct access to Android capabilities required for:

- Usage monitoring
- Foreground services
- Accessibility services
- System overlays
- Boot-time recovery
- Native runtime enforcement

This separation allows the project to use Flutter for application development while retaining native control over Android-specific runtime behavior.

### Why Hybrid ML + Rules?

The ML engine can identify behavioral patterns that are not represented by simple static rules, while the rule-based layer provides explicit and predictable behavioral logic.

Combining the two allows the escalation system to consider both learned signals and deterministic rules.

### Why a Deterministic State Machine?

Intervention transitions need to be predictable and reproducible.

A deterministic state machine makes escalation behavior easier to reason about, debug, test, and maintain.

### Why Local-First AI?

Intervention messaging should not depend entirely on network availability.

Local message generation provides an immediate fallback while cloud AI can enhance responses when available.

### Why Repository Abstraction?

Repositories create a controlled boundary between the application and data sources, allowing SQLite, Firestore, authentication, and related data operations to remain separated from feature presentation logic.

### Why a Contract-Based Platform Bridge?

A shared runtime contract makes Flutter ↔ Kotlin communication explicit and keeps both sides aligned on channels, methods, and state representations.

---

## Technical Challenges

### Continuous Android Monitoring

Persistent usage monitoring requires Android-specific background execution and careful coordination between foreground services, accessibility capabilities, usage APIs, and application state.

### Runtime Enforcement

Intervention cannot depend only on the Flutter UI because enforcement needs to remain active even when the application interface is not visible.

The native runtime therefore owns enforcement-related state and delivery.

### Flutter ↔ Native Synchronization

Maintaining a consistent state between Flutter and Kotlin requires:

- Explicit platform channels
- Shared runtime contracts
- Native state snapshots
- Controlled data ownership

### Offline Intervention Support

AI-powered interventions may depend on network connectivity, so the system includes local-first messaging to keep intervention delivery available when cloud services are unavailable.

### Behavioral Decision Complexity

The system must combine usage context, behavioral signals, risk assessment, escalation state, policies, and intervention lifecycle without turning all decision logic into one large component.

The layered risk-assessment → state-machine → orchestrator architecture separates these responsibilities.

---

## Testing

The repository includes a unit testing layer covering important application and business logic.

Testing areas include:

- AI input protection
- Local-first messaging
- AI chat services
- Reporting and aggregation
- Habit state
- Focus state
- Progression rules
- Runtime contracts
- Behavioral services
- Statistics and reporting logic
- Application policy behavior

The current repository focuses primarily on unit-level verification of application and domain logic.

---

## Technology Stack

| Layer | Technology | Role |
|---|---|---|
| Framework | Flutter | Application UI and feature development |
| Language | Dart | Application and domain logic |
| Native Platform | Kotlin | Android runtime and system integration |
| State Management | Riverpod | State management and dependency injection |
| Navigation | GoRouter | Application routing and navigation |
| Generative AI | Firebase AI / Gemini | Conversational coaching and intervention messaging |
| On-Device ML | TensorFlow Lite | Behavioral risk inference |
| Authentication | Firebase Auth | User authentication |
| Social Authentication | Google Sign-In | Google-based authentication |
| Cloud Database | Cloud Firestore | Profile synchronization |
| Local Database | SQLite / sqflite | Local application persistence |
| Local Storage | SharedPreferences | Lightweight persistent state |
| Notifications | flutter_local_notifications | Reminders and intervention notifications |
| Timezone | timezone / flutter_timezone | Time-aware scheduling |
| Charts | fl_chart | Analytics visualization |
| Animations | flutter_animate | UI animations |
| Typography | Google Fonts | Application typography |
| Security | Firebase App Check / Play Integrity | Application integrity checks |
| Platform Integration | MethodChannel / EventChannel | Flutter ↔ Kotlin communication |

---

## Project Structure

### Flutter Layer

```text
lib/
├── main.dart
├── core/
│   ├── constants/
│   ├── database/
│   ├── localization/
│   ├── theme/
│   └── utils/
├── data/
│   └── repositories/
├── domain/
│   ├── contracts/
│   ├── entities/
│   ├── enums/
│   └── services/
├── features/
│   ├── ai/
│   ├── dashboard/
│   ├── dungeons/
│   ├── focus/
│   ├── habits/
│   ├── identity/
│   ├── profile/
│   ├── settings/
│   ├── stats/
│   └── system/
├── navigation/
├── platform/
├── providers/
├── services/
└── widgets/
```

### Native Android Layer

```text
android/app/src/main/kotlin/com/selfleveling/self_leveling/
├── MainActivity.kt
├── TrackingService.kt
├── ForegroundAccessibilityService.kt
├── UsageStatsHelper.kt
├── AppClassifier.kt
├── BehaviorFeatureExtractor.kt
├── BehaviorRiskAssessor.kt
├── TFLiteBehaviorRiskEngine.kt
├── RuleBasedBehaviorRiskEngine.kt
├── HybridBehaviorRiskEngine.kt
├── EscalationStateMachine.kt
├── EscalationEvaluator.kt
├── InterventionNotifier.kt
├── OverlayManager.kt
├── BootReceiver.kt
├── NativeDatabaseAccess.kt
├── NativeRuntimeStore.kt
├── NativeUsageSnapshotStore.kt
├── MessagingBridge.kt
└── RuntimeContracts.kt
```

### ML Assets

```text
android/app/src/main/assets/
├── behavior_model_quantized.tflite
├── model_config.json
└── normalization_stats.json
```

---

## Android Permissions

The Android runtime uses platform permissions and capabilities required by the implemented monitoring and intervention architecture.

| Permission / Capability | Purpose |
|---|---|
| `INTERNET` | Firebase and cloud AI communication |
| `PACKAGE_USAGE_STATS` | Application usage information |
| `SYSTEM_ALERT_WINDOW` | System overlay interventions |
| `FOREGROUND_SERVICE` | Persistent background monitoring |
| `POST_NOTIFICATIONS` | Notifications and reminders |
| `SCHEDULE_EXACT_ALARM` | Precise reminder scheduling |
| `RECEIVE_BOOT_COMPLETED` | Runtime recovery after device boot |
| `QUERY_ALL_PACKAGES` | Application enumeration |
| `BIND_ACCESSIBILITY_SERVICE` | Foreground application detection |

---

## Setup & Configuration

### Prerequisites

Install the required development environment:

- Flutter SDK
- Dart SDK
- Android SDK
- Android SDK Platform required by the project
- Android NDK
- Java 17
- A Firebase project configured for the application's required services

### 1. Clone the Repository

```bash
git clone https://github.com/Mazenalodini/self_leveling.git
cd self_leveling
```

### 2. Firebase Configuration

Create or obtain the Android Firebase configuration file from Firebase Console and place it at:

```text
android/app/google-services.json
```

The required Firebase capabilities include:

- Firebase Authentication
- Cloud Firestore
- Firebase AI
- Firebase App Check

`google-services.json` is intentionally excluded from version control.

### 3. AI Configuration

The repository includes safe example configuration templates:

```text
.env/
├── ai_chat.example.json
└── ai_chat.proxy.example.json
```

Create your local runtime configuration from the appropriate template:

```bash
cp .env/ai_chat.example.json .env/ai_chat.json
```

For a proxy-based provider:

```bash
cp .env/ai_chat.proxy.example.json .env/ai_chat.json
```

Then update the local configuration for your environment.

The runtime configuration file is gitignored and should not be committed.

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

## Configuration Notes

The project intentionally separates source code from environment-specific configuration.

Ignored runtime configuration includes:

```text
google-services.json
.env/ai_chat.json
api_keys.dart
```

Only safe example templates are committed to the repository.

For providers that require external credentials, pass keys through the configured build-time environment mechanism rather than hard-coding secrets into Dart or Kotlin source.

---

## Design Principles

Self Leveling follows several implementation-oriented principles:

**Separation of Concerns**
Application, domain, data, platform, and native runtime responsibilities are kept distinct.

**Native Runtime Authority**
Android Native owns runtime enforcement state while Flutter consumes the resulting runtime state.

**Deterministic Decisions**
Escalation transitions are explicitly modeled rather than embedded in unrelated UI logic.

**Local-First Behavior**
Critical intervention messaging can continue locally without depending entirely on network availability.

**Feature-Oriented Organization**
Major user-facing capabilities are grouped into self-contained feature modules.

**Repository-Based Data Access**
Feature code interacts with persistence through repository abstractions rather than directly coupling all UI logic to storage implementations.

**Contract-Based Platform Communication**
Flutter and Kotlin communicate through explicitly defined platform contracts rather than ad-hoc message structures.

---

## License

This project is proprietary.

All rights reserved.