# LabHub — Master Laboratory Compilation App

A modern, production-lean Flutter application designed as a modular master compilation dashboard for semester laboratory activities.

---

## 📱 Features & Laboratory Activities

- **Home Dashboard**:
  - Live personalized greeting & student avatar.
  - Hero compilation banner with dynamic activity counter.
  - Scalable **Activity Registry** architecture: New activities are registered in a single file (`lib/models/activity_registry.dart`) and automatically render on the dashboard with zero widget tree edits.
  - Fixed 2-tab bottom navigation (`Home` and `Settings`) keeping the navigation clean and scalable regardless of how many lab activities are assigned.

- **Activity 1 — Notes & Ideas (SQLite CRUD)**:
  - Full Create, Read, Update, and Delete operations backed by SQLite.
  - Clean hairline list layout with soft 32% squircle icon chips.
  - Modal bottom sheet for creating and updating notes.
  - Pull-to-refresh and tactile haptic confirmation snackbars.

- **Activity 2 — Task Checklist & Progress Tracker**:
  - Interactive daily checklist with SQLite persistence.
  - Real-time animated progress bar and completion percentage badge.
  - Smooth strikethrough transition and opacity fade on completed tasks.
  - Borderless quick-add input with tinted accent CTA.

- **Settings Screen**:
  - Editable display name updating across the app via Provider state.
  - Dark mode and Light mode toggle with immediate reactive theme rebuilds.
  - Dedicated student profile hero card.

---

## 🎨 Design System & Polish

- **70-20-10 Color Rule**:
  - **70%**: Neutral light (`#FAFAFA` / `#FFFFFF`) and dark (`#121212` / `#1E1E1E`) surfaces.
  - **20%**: Brand primary Teal (`#00897B`) with deep gradient accent (`#005B52`).
  - **10%**: Contrast Coral accent (`#FF7043`) reserved for badges, completion chips, and highlight CTAs.
- **Modern Borderless Visuals**:
  - Borderless cards with soft drop shadows (`BoxShadow(blurRadius: 14, offset: Offset(0, 4))`) and 20px rounded corners.
  - Standardized 32% squircle radius on all icon chips.
  - Exactly one diagonal brand gradient element per screen to maintain clean visual balance.
  - Strict 8pt spacing grid scale (8, 12, 16, 20, 24).
- **Micro-Interactions**:
  - Tactile spring-back scale effect (`TapScale`) on cards and action buttons.
  - Staggered entrance animations (`FadeSlideEntrance`) on list builds.
  - Physical haptic feedback (`HapticFeedback.lightImpact()`) on toggles, additions, and deletions.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter (Channel stable, Material 3)
- **Language**: Dart
- **State Management**: Provider (`ChangeNotifierProvider`, `MultiProvider`)
- **Local Storage**: SQLite (`sqflite` for Android/iOS, `sqflite_common_ffi_web` for Web)
- **Typography**: Google Fonts (Inter)

### Folder Structure
```
lib/
├── db/              # SQLite database helper & schema
├── models/          # Data models & ActivityRegistry
├── providers/       # Theme, User profile, Notes, and Checklist providers
├── screens/         # Home dashboard, Activity 1, Activity 2, Settings
├── theme/           # Central design system, palette, and themes
└── widgets/         # Reusable UI components & motion helpers
```

---

## 🚀 How to Run

### Prerequisites
- Flutter SDK (v3.11+ or latest stable)
- Android Studio / Android SDK with platform-tools
- Java JDK 17 (Microsoft OpenJDK 17 or Adoptium Temurin 17)

### Installation
1. Clone the repository:
   ```bash
   git clone git@github.com:Huhay2313/FLUTTER-PORTFOLIO.git
   cd FLUTTER-PORTFOLIO
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run on a connected Android device:
   ```bash
   flutter run
   ```

4. Run on Chrome (Web):
   ```bash
   flutter run -d chrome
   ```
