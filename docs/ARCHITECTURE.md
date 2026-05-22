# 🏗️ Mentora — System & Application Architecture

This document is the engineering blueprint: system topology, Flutter clean architecture, offline-first sync, security model, and the backend contract.

---

## 1. System Topology

```
            ┌──────────────────────────────┐
            │       Flutter Mobile App      │
            │  Riverpod · GoRouter · Drift  │
            │   Offline-first local store   │
            └───────────────┬──────────────┘
                            │  REST/HTTPS · JWT
                            ▼
            ┌──────────────────────────────┐
            │        FastAPI Backend        │
            │  Auth · Sync · Reports · AI   │
            └──────┬────────────┬───────────┘
                   │            │
        ┌──────────▼───┐   ┌────▼─────┐    ┌─────────────────┐
        │  PostgreSQL  │   │  Redis   │    │    Firebase     │
        │ system of    │   │ cache /  │    │ Auth · FCM ·    │
        │  record      │   │ job queue│    │ Crashlytics     │
        └──────────────┘   └──────────┘    └─────────────────┘
                   │
                   ▼
        ┌──────────────────────────────┐
        │   AI Provider (Gemini API)    │
        └──────────────────────────────┘
```

**Design stance:** the **mobile app is authoritative for the user's day-to-day work** (offline-first). The backend is the durable system of record + sync hub + AI/report gateway. v1 ships **without** requiring the backend; v1.1 turns sync on.

---

## 2. Flutter App — Clean Architecture

### 2.1 Layered structure (per feature)
```
features/<feature>/
├── presentation/      # Widgets/screens + Riverpod controllers (state)
├── domain/            # Entities + use cases + repository interfaces
└── data/              # Repository impls + data sources
    ├── local/         # Drift DAOs
    └── remote/        # API client (Phase 1.1+)
```
Dependencies point **inward**: `presentation → domain ← data`. Domain has no Flutter/IO imports.

### 2.2 Full folder layout
```
app/lib/
├── main.dart
├── core/
│   ├── theme/             # tokens from DESIGN_SYSTEM.md, ThemeData
│   ├── router/            # GoRouter config, route guards (vault lock)
│   ├── di/                # Riverpod providers / composition root
│   ├── db/                # Drift database, migrations
│   ├── network/           # Dio client, interceptors (JWT, retry)
│   ├── sync/              # sync engine, conflict resolution
│   ├── security/          # biometric, PIN, SQLCipher key mgmt
│   ├── notifications/     # local + FCM handlers
│   ├── l10n/              # ARB files (bn, en)
│   └── utils/             # formatters (৳, dates), extensions
└── features/
    ├── dashboard/
    ├── students/
    ├── class_logbook/
    ├── schedule/
    ├── exams/
    ├── payments/
    ├── finance/           # includes the private vault
    ├── jobprep/
    ├── thesis/
    ├── lists/              # shared bazar + future-needs lists (Firestore-backed)
    ├── reports/
    └── settings/
```

### 2.3 State management — Riverpod
- Use **code-generated providers** (`@riverpod`).
- Pattern: `AsyncNotifier` controllers per screen; repositories injected via providers.
- UI never touches Drift/Dio directly — only through domain use cases / repositories.

### 2.4 Navigation — GoRouter
- Declarative routes; **route guard** redirects to the lock screen before any `finance/vault/*` route if the vault is locked.
- Deep links: `mentora://student/{id}`, `mentora://class/log?student={id}`.

---

## 3. Offline-First & Sync

### 3.1 Local store
- **Drift (SQLite)** is the working database for all non-vault data — relational, type-safe, fast.
- Every syncable row carries: `id (uuid)`, `updated_at`, `dirty (bool)`, `deleted (bool, soft delete)`.

### 3.2 Sync engine (Phase 1.1)
```
On connectivity + auth:
  1. PUSH: send all rows where dirty=true (batched per table).
  2. PULL: GET changes since last_sync_cursor (server returns rows updated after cursor).
  3. MERGE: last-write-wins by updated_at; soft-deletes win over edits.
  4. Persist new cursor; clear dirty flags on ack.
```
- **Conflict policy:** last-write-wins (per field where practical), with deletes prioritized. Money/payment rows are append-only where possible to avoid lossy merges.
- Sync runs on app foreground, on demand (pull-to-refresh), and via a periodic background task.

### 3.3 Backup
- Manual export (encrypted JSON) + daily automatic backup (Phase 1.1) to the backend; **versioned restore**. Backend nightly `pg_dump` retained N days (GitHub Actions cron / cloud cron).

### 3.4 Real-time Shared Lists (Family collaboration)
Shared **bazar / future-needs lists** are multi-user and need live updates, so they use a **different transport from the personal data**:

- **Store:** **Cloud Firestore** — real-time listeners, built-in offline persistence, and trivial multi-device sync. Personal/tutor data stays in Drift; **finance/vault data is never put in Firestore.**
- **Auth:** **Google Sign-In** (Firebase Auth Google provider). A user's Gmail identity is the sharing key.
- **Data shape:**
  ```
  lists/{listId}
    ├── ownerUid, title, type: "bazar" | "future_needs"
    ├── memberEmails: ["husband@gmail.com", "wife@gmail.com"]
    ├── roles: { uid: "owner" | "editor" }
    └── items/{itemId}
          name, qty, unit, category, estPrice,
          isBought, boughtBy, updatedBy, updatedAt, position
  ```
- **Sharing flow:** owner enters a family member's Gmail → email added to `memberEmails` (+ optional FCM invite). The invitee signs in with that Google account and the list appears.
- **Security rules:** read/write allowed only if `request.auth.token.email in resource.data.memberEmails`; only the owner can add/remove members.
- **Conflict handling:** Firestore last-write-wins per field; each item carries `updatedBy`/`updatedAt` for the "updated by <name>" attribution. Offline edits queue and merge automatically on reconnect.
- **Finance link:** "Complete trip" computes the actual total and writes a single **expense** row into the local finance store (not Firestore) — keeping money data private.

---

## 4. Security Model

| Concern | Approach |
|:--------|:---------|
| **Vault auth** | PIN (hashed, salted) + biometric (`local_auth`). Face unlock = future. |
| **Vault data at rest** | Separate **SQLCipher**-encrypted database; key stored in `flutter_secure_storage` (Keystore/Keychain), unlocked by biometric/PIN. |
| **PII** | Student/guardian fields encrypted at rest; excluded from logs/analytics. |
| **Sign-in** | Firebase Auth — Email + **Google Sign-In** (Google identity is the key for shared lists). |
| **Shared-list access** | Firestore security rules: only `memberEmails` can read/write a list; only owner manages members. |
| **Transport** | HTTPS only; JWT access + refresh tokens; tokens in secure storage. |
| **Hidden balance** | UI-level masking (`৳ ******`) independent of auth, toggle in vault. |
| **Lock behavior** | Vault auto-locks on background after a configurable timeout. |

---

## 5. Backend — FastAPI

### 5.1 Layout
```
backend/app/
├── main.py
├── api/            # routers: auth, students, classes, schedules,
│                   #          payments, finance, exams, jobprep,
│                   #          thesis, reports, sync, ai
├── models/         # SQLAlchemy 2.0 ORM models
├── schemas/        # Pydantic v2 request/response models
├── services/       # business logic (sync, reports, ai gateway)
├── core/           # config (pydantic-settings), security (JWT), db session
└── deps.py         # FastAPI dependencies (auth, db)
backend/alembic/    # migrations
backend/Dockerfile
```

### 5.2 Representative endpoints
| Method | Path | Purpose |
|:------:|:-----|:--------|
| POST | `/auth/login` · `/auth/refresh` | JWT auth (Firebase-verified) |
| GET/POST/PATCH/DELETE | `/students` · `/students/{id}` | Student CRUD |
| POST | `/classes` | Create class log |
| GET | `/students/{id}/last-class` | Last class summary |
| GET/POST | `/schedules` | Timetable + conflict check |
| GET/POST | `/payments` | Fee records (auto-posts income) |
| GET/POST | `/finance/transactions` | Income/expense (vault, server-encrypted) |
| GET/POST | `/exams` · `/jobprep` · `/thesis` | Trackers |
| GET | `/reports/{type}` | Generate PDF/Excel/CSV |
| POST | `/sync/push` · `GET /sync/pull` | Delta sync |
| POST | `/ai/lesson-plan` · `/ai/finance-insight` | AI gateway (Phase 2) |

### 5.3 Conventions
- Pydantic v2 schemas; UUID primary keys; UTC timestamps.
- Alembic migrations for every schema change.
- OpenAPI docs auto-served at `/docs`.

---

## 6. Notifications
- **Local notifications** (`flutter_local_notifications`): class reminders, exam countdowns, deadline/fee nudges — work fully offline.
- **FCM**: cross-device / server-pushed reminders (Phase 1.1+).

---

## 7. AI Layer (Phase 2)
- Backend `ai` service abstracts the provider (Gemini default; OpenAI swappable).
- **Lesson planner:** prompt built from student + last topic → structured plan.
- **Finance insight:** monthly aggregates → natural-language summary.
- **Voice→log / OCR receipt:** on-device speech-to-text + image OCR feeding structured forms; AI only normalizes/structures.

---

## 8. Quality & Delivery

| Area | Choice |
|:-----|:-------|
| **Testing** | Unit (domain/use cases) · widget (key screens) · integration (sync). |
| **CI/CD** | GitHub Actions: analyze, test, build APK; backend lint+test+Docker build. |
| **Deploy** | Docker Compose (api + postgres + redis) on Oracle Cloud Free Tier / AWS EC2. |
| **Observability** | Firebase Analytics + Crashlytics; backend structured logging. |
| **Config** | `.env` (backend) + `--dart-define` / flavor configs (app: dev/prod). |

---

## 9. Key Dependencies (Flutter)
`flutter_riverpod` + `riverpod_annotation` · `go_router` · `drift` + `sqlcipher_flutter_libs` · `dio` · `flutter_secure_storage` · `local_auth` · `flutter_local_notifications` · `fl_chart` · `speech_to_text` · `flutter_localizations` · `intl` · `freezed` + `json_serializable` · `firebase_auth` + `google_sign_in` · `cloud_firestore` (shared lists).
