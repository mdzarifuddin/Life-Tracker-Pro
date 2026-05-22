<div align="center">

# 📚 Mentora

### Manage Tuition, Finance, Study & Family — From One Place

A premium, offline-first **personal life-management system** for private tutors, university students, MSc researchers, and government-job aspirants in Bangladesh.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.11x-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-planning-orange.svg)]()

</div>

---

## ✨ What is Mentora?

Mentora is **not** just a tuition app — it is a **personal academic, finance & life operating system**. It unifies the four things a working tutor-student juggles every day:

| 🎓 Tutor Management | 💰 Personal Finance | 🚀 Career & Study | 🛒 Family & Home |
| :--- | :--- | :--- | :--- |
| Students, class logs, schedules, exams, fee collection | Income, expense, savings, assets, goals (PIN-locked vault) | Govt-job prep tracker, MSc thesis tracker, AI lesson planner | Shared bazar & future-needs lists your family edits in real time |

> **Vision:** Open the app and instantly know — *who you're teaching today, what you taught last class, whose fee is due, how much money you have, and where your thesis and job-prep progress stand.* No mental load. No scattered notebooks.

---

## 🎯 Who is it for?

- **Private tutors** who manage many students and need fast, zero-friction class logging and fee tracking.
- **University & MSc students** tracking thesis stages and deadlines.
- **Govt-job aspirants** (BCS / Bank / NTRCA) tracking daily MCQ targets and study progress.
- **Anyone** who wants a private, encrypted personal-finance vault (Monefy-style) alongside their work data.

---

## 🧩 Core Modules

| # | Module | What it does |
|:-:|:-------|:-------------|
| 1 | **Dashboard** | At-a-glance day: today's classes, month income, pending fees, study progress, quick actions. |
| 2 | **Students** | Rich student profiles — class, institution, subjects, guardian info, weak topics, fee. |
| 3 | **Class Logbook** ⭐ | 30-second post-class entry: topics, homework, performance + **voice-to-text**. Auto "last class summary". |
| 4 | **Schedule** | Google-Calendar-style day/week/month view with **conflict detection** and class reminders. |
| 5 | **Exam Tracker** | Student-wise exam calendar with countdown notifications ("Physics exam in 3 days"). |
| 6 | **Payment Tracker** | Paid / Pending / Partial status per student; paying a fee **auto-posts income** to Finance. |
| 7 | **Finance Vault** 🔒 | Monefy-inspired, PIN/biometric-locked private vault: income, expense, savings, assets, goals, project costs. |
| 8 | **Govt Job Prep** | Subject-wise daily MCQ targets and progress charts. |
| 9 | **MSc Thesis Tracker** | Stage-based progress (Lit Review → Defense) with deadline reminders. |
| 10 | **Reports** | Monthly income/expense, payment reports, study progress — export to PDF / Excel / CSV. |
| 11 | **Shopping & Family Lists** 🛒 | Shared **bazar** (grocery) list + **future-needs** list. Sign in with Google; your wife/family edit the same list in **real time**. Completing a trip auto-logs the expense to Finance. |
| 12 | **AI Assistant** *(Phase 2)* | AI lesson planner, finance insights, OCR receipt scanning. |
| 13 | **Settings** | Theme (dark default), notifications, backup, security, language (বাংলা / English). |

---

## 🎨 Design Philosophy

> **Clean · Fast · Premium · One-hand use · Zero clutter**

Inspired by **Monefy** (finance UX), **Notion** (calm, modular layout), and **Google Calendar** (scheduling). Dark mode by default, fluid 3-second data entry, and a focused bottom-navigation flow.

See **[docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md)** for the full color palette, typography scale, spacing tokens, and component specs.

---

## 🏗️ High-Level Architecture

```
            ┌──────────────────────────────┐
            │       Flutter Mobile App      │
            │  (Riverpod · GoRouter · Drift)│
            │      Offline-first cache      │
            └───────────────┬──────────────┘
                            │  REST / HTTPS (JWT)
                            ▼
            ┌──────────────────────────────┐
            │        FastAPI Backend        │
            │   Auth · Sync · AI gateway    │
            └───────┬───────────┬──────────┘
                    │           │
        ┌───────────▼──┐   ┌────▼─────────┐   ┌──────────────┐
        │  PostgreSQL  │   │    Redis     │   │   Firebase   │
        │ (system of   │   │ (cache/queue)│   │ Auth · FCM   │
        │   record)    │   └──────────────┘   │ Crashlytics  │
        └──────────────┘                      └──────────────┘
                    │
                    ▼
        ┌──────────────────────────────┐
        │   AI Layer (Gemini / OpenAI)  │
        │ Lesson plans · Finance insight│
        └──────────────────────────────┘
```

**Offline-first:** the app is fully usable with no network. Local **Drift (SQLite)** is the working store; changes sync to the FastAPI/PostgreSQL backend when online. Full details in **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

---

## 🛠️ Tech Stack

| Layer | Technology |
|:------|:-----------|
| **Mobile** | Flutter 3.x · Dart |
| **State** | Riverpod (with code-gen) |
| **Navigation** | GoRouter |
| **Local DB** | Drift (SQLite) — relational, type-safe, offline-first |
| **Local secure store** | `flutter_secure_storage` + SQLCipher for the vault |
| **Backend** | FastAPI (Python) · SQLAlchemy 2.0 · Alembic |
| **Database** | PostgreSQL 16 |
| **Cache/Queue** | Redis |
| **Auth** | Firebase Auth (Email + **Google Sign-In**) + JWT |
| **Real-time collaboration** | Cloud Firestore (shared family lists, live sync, offline) |
| **Notifications** | Firebase Cloud Messaging + local notifications |
| **AI** | Gemini API (pluggable) |
| **Charts** | `fl_chart` |
| **CI/CD** | GitHub Actions |
| **Deploy** | Docker · Oracle Cloud Free Tier / AWS EC2 |
| **Observability** | Firebase Analytics + Crashlytics |

---

## 📁 Repository Structure

```
mentora/
├── app/                        # Flutter application
│   └── lib/
│       ├── core/               # theme, router, di, utils, network, db
│       ├── features/
│       │   ├── dashboard/
│       │   ├── students/
│       │   ├── class_logbook/
│       │   ├── schedule/
│       │   ├── exams/
│       │   ├── payments/
│       │   ├── finance/        # the private vault
│       │   ├── jobprep/
│       │   ├── thesis/
│       │   ├── lists/          # shared bazar + future-needs lists
│       │   ├── reports/
│       │   └── settings/
│       └── main.dart
├── backend/                    # FastAPI service
│   ├── app/
│   │   ├── api/                # routers
│   │   ├── models/             # SQLAlchemy models
│   │   ├── schemas/            # Pydantic schemas
│   │   ├── services/
│   │   └── core/               # config, security, db session
│   ├── alembic/                # migrations
│   └── Dockerfile
├── docs/
│   ├── PRD.md                  # product requirements + every screen
│   ├── ARCHITECTURE.md         # system + Flutter clean architecture
│   ├── DATABASE.md             # full schema + ERD
│   └── DESIGN_SYSTEM.md        # colors, type, components, finance UX
├── docker-compose.yml
└── README.md
```

Each Flutter feature follows **Clean Architecture**: `presentation/` (UI + Riverpod controllers) → `domain/` (entities + use cases) → `data/` (repositories + Drift/remote sources).

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.x · Dart 3.x
- Python 3.11+
- Docker + Docker Compose (for backend + DB)
- A Firebase project (Auth + FCM)

### 1. Backend (Docker)
```bash
cd backend
cp .env.example .env          # set DB url, JWT secret, Gemini key
docker compose up --build     # starts FastAPI + PostgreSQL + Redis
# API docs at http://localhost:8000/docs
```

### 2. Database migrations
```bash
docker compose exec api alembic upgrade head
```

### 3. Flutter app
```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift + Riverpod codegen
flutter run                                                 # pick your device
```

> The app runs **fully offline** out of the box. Backend sync activates once you sign in and configure the API base URL in **Settings → Backup**.

---

## 🗺️ Roadmap

| Phase | Focus | Highlights |
|:-----:|:------|:-----------|
| **v1.0 — MVP** | Local-first core | Dashboard, Students, Class Logbook, Schedule, Payments, Finance Vault, Exams, Job-prep, Thesis, Settings — all offline. |
| **v1.1 — Sync & Sharing** | Cloud | FastAPI/PostgreSQL sync, JWT auth, multi-device, daily backup, **Google Sign-In + real-time shared family lists**. |
| **v1.2 — Reports** | Insights | PDF/Excel/CSV export, monthly financial dashboard, analytics. |
| **v2.0 — AI** | Intelligence | AI lesson planner, finance insights, voice-note logging, OCR receipt scanner. |
| **v2.1 — Guardian Portal** | Sharing | Parents view attendance / homework / results; WhatsApp auto-reports. |
| **v3.0 — Public launch** | Scale | Play Store release as *"Mentora Bangladesh"* for other tutors. |

Full breakdown in **[docs/PRD.md](docs/PRD.md)**.

---

## 📚 Documentation

| Doc | Description |
|:----|:------------|
| [**PRD.md**](docs/PRD.md) | Product requirements — every screen, user flow, and acceptance criteria. |
| [**ARCHITECTURE.md**](docs/ARCHITECTURE.md) | System design, Flutter clean architecture, offline sync, security model. |
| [**DATABASE.md**](docs/DATABASE.md) | Complete schema, ERD, and table definitions. |
| [**DESIGN_SYSTEM.md**](docs/DESIGN_SYSTEM.md) | Color tokens, typography, spacing, components, Monefy-style finance UX. |

---

## 🔐 Privacy & Security

- The **Finance Vault** is a separate, encrypted area locked behind **PIN + biometrics**.
- Vault data is stored in an **SQLCipher-encrypted** local database; balances support a **hidden mode** (`৳ ******`, tap to reveal).
- Student/guardian PII is encrypted at rest and never leaves the device unless cloud sync is enabled.
- **Shared lists are fully separate from the private vault** — only invited Google accounts can see a shared list, and no finance/vault data is ever shared.

---

## 📄 License

Released under the **MIT License** — see [LICENSE](LICENSE).

<div align="center">

**Built for tutors who teach, study, and build — all at once.** 🇧🇩

</div>
