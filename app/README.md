# Life Tracker Pro — Flutter App

Offline-first Flutter app (see the repository root `README.md` for the full feature list). No backend or account is needed.

## Stack
- **Flutter 3.41** · **Riverpod 3** · **go_router**
- **Hive** for local storage (no code generation)
- fl_chart · share_plus · file_picker · url_launcher · local_auth · crypto · intl

## Run
```bash
flutter pub get
flutter run                  # choose a device / emulator
flutter test
flutter analyze
```

## Project layout
```
lib/
├── main.dart            # boot: Hive init, ProviderScope
├── app.dart             # router, shell, bottom navigation, quick add
├── models.dart          # data models (Map (de)serialisation)
├── core/
│   ├── theme.dart       # design tokens, money/date formatting
│   ├── data.dart        # Repo over Hive boxes, fee maths, backup import/export
│   ├── backup.dart      # save / share / import JSON backups
│   ├── bulk_classes.dart# parser for "Jan_26: Name - 3,5,8" class notes
│   ├── updater.dart     # GitHub Releases in-app updater
│   ├── providers.dart
│   └── widgets.dart     # shared UI
└── features/            # dashboard, students, schedule, payments, finance,
                         # exams, jobprep, thesis, tasks, lists, settings, more
test/                    # fee, backup/import and bulk-class parser tests
```

## Notes
- Backups are JSON (`_app: life_tracker_pro`, `_version`), validated and staged before import; the vault PIN is not exported.
- Tuition payments live in the student's records and never create Finance transactions.
- CI pins Flutter 3.41.4; a `v*` tag builds a signed APK and a GitHub Release (`.github/workflows/release.yml`).
