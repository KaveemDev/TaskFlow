# Kronom — TaskFlow Suite ⌛

> **Productivity, Deadlines & Pomodoro Focus Suite**

Kronom (TaskFlow Suite) is a modern, feature-rich productivity ecosystem built with **Flutter**, **Riverpod**, and **Firebase**. It seamlessly combines comprehensive task management, interactive calendar event scheduling, customizable Pomodoro focus sessions, deep analytics and data visualizations, native home screen widgets, and real-time cloud synchronization.

---

## 📸 Overview & Features

### 📋 Task & Category Management
- **Task Organization:** Group tasks by customizable categories with custom colors and icons.
- **Subtasks & Priority:** Break down complex goals into subtasks with low/medium/high priority tags.
- **Pomodoro Estimations:** Estimate required focus sessions per task and track completed Pomodoros in real time.
- **Filtering & Search:** Instant search with status filters (Pending, Completed, High Priority, Category-based).

### ⏱️ Pomodoro Focus Timer
- **Flexible Sessions:** Customizable Focus, Short Break, and Long Break durations.
- **Streak & Counter:** Automatic tracking of completed focus sessions and daily streaks.
- **Timer Modes:** Visual progress rings with pause, play, skip, and reset controls.

### 📅 Interactive Calendar & Deadlines
- **Visual Calendar View:** Powered by `table_calendar` with interactive day, week, and month views.
- **Event & Deadline Scheduling:** Attach deadlines directly to tasks and events with date/time selectors.
- **Chronological Agenda:** Instant view of upcoming events, overdue tasks, and daily schedules.

### 📊 Insights & Visual Analytics
- **Performance Metrics:** Real-time productivity scores, completion rates, and focus duration totals.
- **Interactive Charts:** Powered by `fl_chart` for category time breakdown, daily/weekly focus trends, and historical analysis.
- **Streak & Goal Tracking:** Measure consistency and target achievements across custom timeframes.

### 📱 Native Home Screen Widgets & Deep Links
- **Widget Integration:** Built with `home_widget` for Android & iOS home screen support.
- **Real-Time Sync:** Live display of active tasks, upcoming deadlines, and focus session stats directly on your home screen.
- **Deep-Link Launching:** Tap widgets to immediately launch specific actions inside the app (e.g., Quick Add Task, Jump to Focus Timer, Open Insights).

### 🔔 Smart Local & Push Notifications
- **Reminders & Alerts:** Powered by `flutter_local_notifications` and `timezone` for offline-first, time-zone aware notifications.
- **Lifecycle Awareness:** Auto-clears delivered notifications upon resuming the app.

### 🎨 Modern UI & Experience
- **Glassmorphism & Material 3:** Modern aesthetic featuring blurred backdrops, floating navigation bar, and dark/light mode toggles.
- **Fluid Animations:** Smooth UI transitions and micro-interactions powered by `flutter_animate`.
- **Lucide Iconography:** Clean and unified icon system using `lucide_icons_flutter`.

---

## 🛠️ Tech Stack & Architecture

| Layer | Technology |
| :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev/) (Dart SDK ^3.12.2) |
| **State Management** | [Flutter Riverpod 3](https://riverpod.dev/) |
| **Backend & Cloud** | [Firebase Core](https://firebase.google.com/), [Cloud Firestore](https://firebase.google.com/docs/firestore), [Firebase Auth](https://firebase.google.com/docs/auth) |
| **Charts & Graphics** | [fl_chart](https://pub.dev/packages/fl_chart) |
| **Calendar** | [table_calendar](https://pub.dev/packages/table_calendar) |
| **Widgets** | [home_widget](https://pub.dev/packages/home_widget) |
| **Notifications** | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) & [timezone](https://pub.dev/packages/timezone) |
| **Animations & Icons** | [flutter_animate](https://pub.dev/packages/flutter_animate) & [lucide_icons_flutter](https://pub.dev/packages/lucide_icons_flutter) |
| **Fonts** | [google_fonts](https://pub.dev/packages/google_fonts) |

---

## 📁 Project Structure

```text
lib/
├── firebase_options.dart   # Auto-generated Firebase configurations
├── main.dart               # App entry point, service initializations, & theme setup
├── models/                 # Core data models
│   ├── event_model.dart          # Calendar event model
│   ├── focus_session_model.dart  # Pomodoro session history model
│   ├── task_model.dart           # Task & subtask data model
│   └── user_profile_model.dart   # User profile & stats model
├── providers/              # Riverpod state providers
│   ├── auth_provider.dart        # Authentication state
│   ├── categories_provider.dart  # Task category state
│   ├── navigation_provider.dart  # Root navigation state
│   ├── theme_provider.dart       # Light/Dark mode state
│   ├── timer_provider.dart       # Pomodoro timer logic & state
│   └── providers.dart            # Unified streams & data providers
├── repositories/           # Firestore & local repository layer
│   ├── event_repository.dart
│   ├── focus_session_repository.dart
│   └── task_repository.dart
├── screens/                # UI Screens & Views
│   ├── analytics_screen.dart     # Detailed charts & focus statistics
│   ├── calendar_screen.dart      # Interactive calendar & deadline views
│   ├── focus_screen.dart         # Pomodoro timer UI
│   ├── insights_screen.dart      # Productivity scores & streak metrics
│   ├── root_screen.dart          # Main Scaffold with glassmorphic bottom bar
│   ├── settings_screen.dart      # User preferences & theme settings
│   └── tasks_screen.dart         # Task management list & modals
├── services/               # Background & system services
│   ├── notification_service.dart # Local notification scheduling
│   └── widget_service.dart       # Home widget state management & updates
├── theme/                  # Theme configuration (Material 3 Light/Dark)
└── widgets/                # Reusable UI widgets & components
```

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following installed on your development machine:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.12.2` or later)
- [Dart SDK](https://dart.dev/get-dart)
- Android Studio / Xcode (for mobile emulation & building)
- [Firebase CLI](https://firebase.google.com/docs/cli) (if configuring custom Firebase backends)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/taskflow_suite.git
   cd taskflow_suite
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup:**
   - Configure your Firebase project using FlutterFire CLI:
     ```bash
     flutterfire configure
     ```
   - Ensure your `lib/firebase_options.dart` is populated with your project keys.

4. **Run the Application:**
   ```bash
   # Run on connected device or emulator
   flutter run
   ```

---

## 🌐 Web Deployment (Vercel)

Kronom includes automated web deployment support.

A custom deployment script `build_vercel.sh` and `vercel.json` are provided to build the Flutter web application on Vercel:

```bash
# Manual web build
flutter build web --release
```

When deploying to Vercel, set the build command to:
```bash
bash build_vercel.sh
```
and output directory to `build/web`.

---

## 📄 License

This project is licensed under the MIT License - see the `LICENSE` file for details.
