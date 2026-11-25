<div align="center">

# 📚 Life Tracker Pro

### Manage Tuition, Finance, Study & Family — From One Place

A premium, **offline-first personal life-management app** for private tutors, university students, MSc researchers and government-job aspirants in Bangladesh.

[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Storage](https://img.shields.io/badge/storage-Hive%20(offline)-F5A623)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.4.1-blue.svg)]()

</div>

---

## ✨ What is Life Tracker Pro?

Life Tracker Pro is **not** just a tuition app — it is a personal academic, finance and life organiser. It brings together what a working tutor-student juggles every day:

| 🎓 Tutor Management | 💰 Personal Finance | 🚀 Career & Study | 🛒 Family & Home |
| :--- | :--- | :--- | :--- |
| Students, class logs, schedule, exams, fees | Income, expense, accounts (PIN-locked vault) | Govt-job prep, MSc thesis tracker, tasks | Bazar and future-needs lists |

> Open the app and instantly know — *who you're teaching today, what you taught last class, whose fee is due, how much money you have, and where your thesis and job-prep stand.*

Everything is stored **on your phone**. No account, no server, no internet needed.

---

## 🧩 Features

### Tuition
- **Students** — rich profiles (class, institution, subjects, teaching days, card colour, photo), any number of **guardians** with one-tap **call / SMS / WhatsApp**, batches, current / previous status.
- **Class log** — topics, homework, what the student learned, weak points, next plan, performance. Shows a "last class" summary.
- **Add many classes at once** ⭐ — paste your notes and every class is added automatically:
  ```
  Jan_26:
  Labib - 3,5,8,16,17,19,28,31
  Done - 12            ← money lines are ignored
  Sara, farin & rifat - 1,3,5,7
  ```
  Understands month headers (`Jan_26:`, `March_26:`, `Sept_26 :`), several students on one line, and stray symbols. Shows a preview first, skips days that are already logged, and can create students that don't exist yet (dated from their first class).
- **Mark classes paid** — tick a payment per class date, or say "payment done till 22-Nov-2026" and every class up to that date is marked paid (shown in a different colour). From Log Class, the student page, or while bulk-adding. Stays in the student records, never in Finance.
- **Tuition history** — one screen with every student, class and payment (Tuition tab → History), and export / import it all as a readable JSON file (by student: class dates, paid flags, payments). Importing twice never duplicates anything.
- **Busy times** — note when a student can't take classes (School, College, Coaching, Private tutor, Other…). The schedule warns you about a clash before you save a class.
- **Schedule** — weekly timetable with **conflict detection**, one-off booked classes, absences and routine pictures.
- **Exam tracker** — student-wise exams with countdowns.
- **Payments** — per-student, per-billing-cycle fee status (Paid / Partial / Due):
  - monthly fee, pro-rated by classes taught, or **pay per class**;
  - custom billing day, partial payments (installments) with dates, "pay for some classes";
  - unpaid or advance amounts **carry forward** automatically;
  - each row shows the class count, amount to receive, what is paid and what is still due;
  - undo for a payment. Tuition payments stay in the student's records and **do not touch Finance**.

### Finance 🔒
- Monefy-style income / expense entry with category bubbles and custom categories, monthly donut chart, swipe-to-delete.
- **PIN-locked vault** (salted hash) with biometric unlock, accounts, and a hidden-balance mode.

### Career & life
- **Govt job prep**, **MSc thesis** stages and deadlines, **tasks**, and **family lists** (bazar with "Complete Trip" → expense, future needs).

### Data & safety
- **Backup, export, import and share** everything as one JSON file (Settings → Backup): save to device, share (WhatsApp, Drive…), or import — with a safety copy taken first and the file validated before anything is replaced. The vault PIN is never included in a backup.
- **In-app updater** — checks GitHub Releases and installs new versions.
- Dark (default), light or system theme; Material 3 design.

---

## 🛠️ Tech Stack

| Layer | Technology |
|:------|:-----------|
| App | Flutter 3.41 (pinned in CI) · Dart 3.11 |
| State | Riverpod 3 |
| Navigation | go_router |
| Storage | Hive (offline boxes) |
| Charts | fl_chart |
| Sharing / files | share_plus · file_picker · path_provider |
| Contacts / calls | url_launcher · flutter_native_contact_picker |
| Security | crypto (PIN hashing) · local_auth (biometrics) |
| CI/CD | GitHub Actions — a `v*` tag builds a signed APK and publishes a Release |

---

## 📁 Repository Structure

```
.
├── app/                    # Flutter application
│   ├── lib/
│   │   ├── main.dart       # boot: Hive init, ProviderScope
│   │   ├── app.dart        # router, shell, bottom navigation
│   │   ├── models.dart     # data models (Map (de)serialisation)
│   │   ├── core/           # theme, data (Repo over Hive), backup, updater, widgets
│   │   └── features/       # dashboard, students, schedule, payments, finance,
│   │                       # exams, jobprep, thesis, tasks, lists, settings, more
│   └── test/               # unit and import/backup tests
├── docs/                   # PRD, architecture, database and design-system notes
│                           # (planning documents; the app itself is offline-only)
├── .github/workflows/      # release pipeline
└── README.md
```

---

## 🚀 Getting Started

**Prerequisites:** Flutter 3.41+ · Android SDK (or a device / emulator).

```bash
cd app
flutter pub get
flutter run                 # pick your device or emulator
flutter test                # unit tests
flutter analyze
```

### Releasing
```bash
# bump `version:` in app/pubspec.yaml, commit, then
git tag v1.4.1
git push origin v1.4.1      # CI builds the signed APK and creates the Release
```
The installed app's updater then offers the new version. Signing secrets must be set in the repository settings (the workflow checks for them).

---

## 🗺️ Roadmap

Done: tuition, class logs, bulk class paste, schedule with conflicts, busy times, payments, finance vault, exams, job prep, thesis, tasks, lists, JSON backup / import / share, in-app updater.

Ideas next:
- Fee reminders to guardians, receipts, and an "overdue first" fee view
- Free-slot finder for the schedule
- Automatic scheduled backups
- PDF / Excel monthly report export
- Home-screen widget · বাংলা language
- Cloud sync and shared family lists (optional, later)

The longer-term design notes in [`docs/`](docs/) describe a possible cloud backend; none of it is required to use the app.

---

## 🔐 Privacy & Security

- All data stays on the device unless **you** export or share a backup.
- The Finance Vault is behind a PIN (salted hash) and optional biometrics; balances can be hidden.
- Backups never contain the vault PIN.

---

## 📄 License

Released under the **MIT License** — see [LICENSE](LICENSE).

<div align="center">

**Built for tutors who teach, study, and build — all at once.** 🇧🇩

</div>
