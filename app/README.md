# Mentora — Flutter App (Phase 1 MVP)

Local-first implementation of the Mentora spec (see `../docs/`). Runs fully offline; no backend required.

## Stack
- **Flutter** · **Riverpod** (state) · **GoRouter** (navigation)
- **Hive** (local storage — chosen for the MVP so it runs on Android/web/desktop with no codegen; Drift remains the documented target for the cloud phase)
- **fl_chart** (finance donut) · **crypto** (vault PIN hashing) · **intl**

## Run
```bash
flutter pub get

# Android emulator (primary target)
flutter run -d emulator-5554        # or: flutter run  (then pick a device)

# Quick preview in the browser
flutter run -d chrome
```

## What works (Phase 1)
- **Dashboard** — today's classes, month income/expense, pending fees, thesis & job-prep progress, upcoming exams.
- **Students** — list + search, add/edit, profile with class-log history & last-class summary.
- **Class Logbook** — topics, homework, performance slider, remarks.
- **Schedule** — weekly timetable with **conflict detection**.
- **Finance** — Monefy-style add expense/income (category bubbles + custom categories), monthly donut, swipe-to-delete, **PIN-locked vault**.
- **Payments** — per-student fee status; **marking paid auto-creates the income transaction**.
- **Exam Tracker · Govt Job Prep · MSc Thesis** trackers.
- **Family Lists** — bazar (quick-add items + "Complete Trip" → auto expense) and future-needs lists (local; real-time Google sharing is the v1.1 target).
- **Settings** — theme (dark default / light / system), vault PIN set/remove.

## Project layout
```
lib/
├── main.dart            # boot: Hive init + seed, ProviderScope
├── app.dart             # MaterialApp.router, shell + bottom nav + Quick Add
├── models.dart          # data models (Map (de)serialization)
├── core/
│   ├── theme.dart       # design tokens (DESIGN_SYSTEM.md), money/date format
│   ├── data.dart        # Repo over Hive boxes (+ reactive listenables, seeding)
│   ├── providers.dart   # repo / themeMode / month / vault providers
│   └── widgets.dart     # shared UI (cards, stat, progress, empty state)
└── features/<module>/   # dashboard, students, schedule, finance, payments,
                         # exams, jobprep, thesis, lists, settings, more
```

## Verified
`flutter analyze` → no issues · `flutter test` → passing · `flutter build web` → builds.
