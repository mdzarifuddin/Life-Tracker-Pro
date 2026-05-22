# 📋 Life Tracker Pro — Product Requirements Document (PRD)

**Version:** 1.0 (build-ready draft)
**Audience:** Claude Code / implementing engineers
**Currency:** BDT (`৳`) · **Locale:** বাংলা + English · **Default theme:** Dark

---

## 1. Product Goal

An all-in-one, **offline-first** productivity platform for Bangladeshi private tutors who are *also* students/researchers/job-aspirants. It merges three worlds:

1. **Tutor Management** — students, class logs, schedule, exams, fees.
2. **Personal Finance** — private, encrypted income/expense/savings/assets/goals vault.
3. **Career & Study** — govt-job prep + MSc thesis tracking + (later) AI assistance.

## 2. Target Users (Phase 1)
Private tutor · university student · MSc student · govt-job aspirant. **Single-user, personal device** first; multi-tutor SaaS is a Phase-3 goal.

## 3. Design Principles
Minimal · Fast · Premium · One-hand use · Fast entry · Zero clutter. (Tokens → [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).)

## 4. Navigation

**Bottom navigation (5 tabs)** with a center **Quick-Add FAB**:

```
[ Dashboard ] [ Students ] [ (+) ] [ Schedule ] [ Finance ] [ More ]
```
> "More" hosts: Exam Tracker · Payments · Govt Job Prep · Thesis · **Family Lists** · Reports · Settings.
> The **(+) FAB** opens: `+ Expense · + Income · + Add Student · + Log Class`.

---

## 5. Screens

> Each screen lists **Purpose · Layout · Key actions · Acceptance criteria (AC)**.

### Screen 1 — Dashboard (Home)
- **Purpose:** instant daily situational awareness.
- **Layout (top → bottom):**
  - **Greeting:** "Good Evening, Zarif" + date.
  - **Stat row:** `Today: 4 Classes` · `Income This Month: ৳27,000` · `Pending: ৳8,000`.
  - **Today's Schedule:** list — `4 PM · Rahim`, `6 PM · Nusrat`, `8 PM · HSC Batch`.
  - **Progress widgets:** Upcoming Exams · Govt Job Progress · Thesis Progress.
  - **Quick Actions FAB:** Add Expense / Income / Student / Log Class.
- **AC:** loads in <1s from local DB; tapping a schedule item opens that class/student; numbers reflect current month.

### Screen 2 — Students
- **Purpose:** manage all students.
- **Layout:** search bar → card list. Each card: name, class+batch (e.g. "HSC 2027"), subjects, "Next Class: Tomorrow".
- **Student Profile (sub-screen) tabs:** Overview · Class Logs · Homework · Attendance · Payments · Exams · Notes.
- **Actions:** add/edit/archive student, call/SMS guardian (deep link).
- **Data model:**
```json
{
  "id": "uuid",
  "name": "",
  "phone": "",
  "class": "",
  "institution": "",
  "monthly_fee": 5000,
  "subjects": [],
  "guardian_name": "",
  "guardian_phone": "",
  "weak_subjects": [],
  "status": "active|archived"
}
```
- **AC:** search filters live; archiving hides from active lists but preserves history.

### Screen 3 — Class Logbook ⭐ (most-used)
- **Purpose:** capture what happened in a class in ≤30 seconds.
- **Form fields:** Student · Date (prefilled today) · Topics Covered · Homework · Performance (0–10 slider) · Remarks.
- **Voice input:** 🎤 button → speech-to-text fills Topics/Homework (e.g. *"Today taught Integration, homework question 1–10"*).
- **Auto-save** + **AI Summary** generates the "Last Class Summary" shown next time.
- **AC:** opening a student shows their **last class summary** without extra taps; voice transcription editable before save.

### Screen 4 — Schedule
- **Purpose:** weekly tuition timetable, calendar-style.
- **Views:** Day · Week · Month.
- **Schedule card:** student · time · location · duration · reminder.
- **Conflict detection:** two classes at the same time render a **red warning**.
- **Reminders:** "Class in 30 minutes" local notification.
- **AC:** creating an overlapping slot triggers a blocking warning with a "schedule anyway" override.

### Screen 5 — Finance (Monefy-inspired) 🔒
- **Purpose:** the private money hub. Behind PIN/biometric (see Vault).
- **Finance Home:** large **donut chart** (Income · Expense · Savings) + month switcher + center **Quick-Add FAB**.
- **Add Expense flow:** tap Expense → pick **category bubble** → numeric keypad → save (≤3s).
  - **Pre-seeded expense categories:** Food, Transport, Internet, Mobile Recharge, Books, Tuition Travel, Family, Medical, Shopping, Entertainment, Govt Job, Thesis, Software, Subscriptions, Investment, Other.
  - **Custom category:** `+ Create New` (one time) → stored permanently, reusable.
- **Pre-seeded income categories:** Tuition, Freelancing, Scholarship, Gift, Salary, Business, Other.
- **AC:** categories pre-exist so the user only *selects*; adding a custom one persists; entry never takes more than 3 taps + amount.

### Screen 5a — Finance Vault (Private, separate area)
- **Auth:** PIN · Fingerprint · Face Unlock (future). Encrypted DB (SQLCipher).
- **Balance / Assets screen:** Cash · bKash · Nagad · Bank → **Net Worth auto-calculated** (e.g. ৳52,000).
- **Hidden Balance mode:** shows `৳ ******`; tap to reveal.
- **AC:** vault data is inaccessible without auth; toggling hidden mode hides all amounts app-wide in the vault.

### Screen 6 — Expense Analytics
- **Ranges:** Monthly · Yearly · Custom.
- **Charts:** category-wise (pie/bar), income vs expense (bars), savings trend (line).
- **Reports:** export PDF / Excel.
- **AC:** charts recompute on range change; export produces a shareable file.

### Screen 7 — Tuition Payment Tracker
- **Purpose:** track fees per student.
- **Status:** Paid · Pending · Partial (with amount + date).
- **Auto-integration:** marking "Rahim Paid ৳5000" **auto-creates an Income entry** (category Tuition, source Rahim) in Finance.
- **Monthly report:** total tuition income per month.
- **AC:** payment status visible per student & in a monthly roll-up; reversing a payment reverses the linked income entry.

### Screen 8 — Exam Tracker
- **Purpose:** student-wise exam calendar.
- **Exam types:** SSC · HSC · Monthly Test · Pre-Test · Model Test.
- **Calendar view** + **notifications** ("Physics exam in 3 days / 7 days").
- **AC:** exams appear on the schedule calendar with a distinct color; countdown notifications fire at configurable lead times.

### Screen 9 — Govt Job Prep Tracker
- **Subjects:** Bangla · English · Math · GK · ICT.
- **Daily target:** e.g. "Math: 50 MCQ" → "Completed: 37".
- **Progress chart:** daily/weekly completion.
- **AC:** targets reset daily; streak + weekly progress visible.

### Screen 10 — MSc Thesis Tracker
- **Stages:** Literature Review · Methodology · Implementation · Results · Writing · Defense.
- **Each stage:** progress %, deadline, notes.
- **AC:** overall progress = weighted stage average; deadline reminders fire.

### Screen 11 — Reports
- **Generate:** Monthly Income · Monthly Expense · Student Payment Report · Tuition Earnings · Study Progress.
- **Formats:** PDF · Excel · CSV.
- **AC:** each report is parameterized by date range; export is shareable.

### Screen 12 — Settings
- Theme (Dark default) · Notifications · Backup · Security (PIN/biometric) · Language (বাংলা/English) · **Google account & sharing**.
- **AC:** changing theme/language applies instantly; backup triggers a sync/export.

### Screen 13 — Shopping & Family Lists (Shared) 🛒
- **Purpose:** a shared **bazar (grocery) list** that's ready when you go to market, plus a **future-needs list** for things to buy later — and your **wife/family can edit the same list in real time**.
- **Sign-in & sharing:** Sign in with **Google (Gmail)**. Share any list by inviting a family member's Gmail; roles are **Owner / Editor**. Members see each other's edits live.
- **Two list types (tabs):**
  - **Bazar List (active):** items to buy now. Add item → name, quantity/unit, optional category (Grocery · Vegetables · Fish/Meat · Dairy · Household · Other) and est. price. **Tap to check off** when bought. Pre-seeded common items for **1-tap add**; recent/frequent suggestions surface first.
  - **Future Needs:** bigger upcoming purchases (e.g. Laptop, Furniture). Fields: item, **priority**, target month, est. cost, note. Any item can be **promoted to a Finance Goal**.
- **Real-time collaboration:** wife checks "rice" → it updates on your phone within seconds; each item shows **"updated by <name>"**. Works **offline**; edits merge on reconnect. Optional notification when a collaborator changes a list.
- **Smart link to Finance:** on "Complete shopping trip," enter the actual total → **auto-creates a Finance expense** (category Grocery/Food). The list then archives.
- **Estimated total:** the active bazar list shows a running estimated cost.
- **AC:**
  - A shared list reflects any member's edits within ~seconds when online; offline edits merge without loss on reconnect.
  - Only invited Google accounts can view/edit a list; non-members get no access.
  - Checked items move to a "bought" group; completing a trip clears the active list and (optionally) logs the expense.
  - Future-needs items can be converted to savings goals in one tap.

---

## 6. Cross-Cutting Features

| Feature | Requirement |
|:--------|:------------|
| **Offline-first** | All core features work without network; sync when online. |
| **Quick Add** | Global FAB reachable from any primary tab. |
| **Search** | Students searchable; Finance searchable by category/note. |
| **Notifications** | Class reminders, exam countdowns, fee-due nudges, deadline alerts. |
| **Backup/Restore** | Manual + daily auto backup; versioned restore (Phase 1.1+). |
| **Security** | Vault PIN/biometric; encrypted local DB; hidden-balance mode. |
| **Auto-link** | Fee payment → income entry; completed bazar trip → expense entry (the "smart" links). |
| **Collaboration** | Shared family lists with Google Sign-In, real-time multi-user editing, roles (Owner/Editor), offline merge. |

---

## 7. Phase Plan

### Phase 1 — MVP (local-first, no backend required)
Dashboard · Students · Class Logbook · Schedule · Payments · Finance + Vault · Exams · Job-prep · Thesis · Settings. Local Drift DB. Biometric lock.

### Phase 1.1 — Cloud Sync & Sharing
FastAPI + PostgreSQL, JWT auth, multi-device sync, daily backup. **Google Sign-In + real-time shared family lists** (bazar + future-needs) via Firestore. *(A local-only personal bazar list can ship in Phase 1; live family sharing turns on here.)*

### Phase 1.2 — Reports & Analytics
PDF/Excel/CSV export, monthly financial dashboard.

### Phase 2 — AI & Automation
- **AI Lesson Planner:** input last topic → generates next class plan (topics, numericals, homework).
- **AI Finance Insights:** "You spent 32% more on Food this month."
- **Voice Note → Log:** dictate the class summary; auto-save to logbook.
- **OCR Receipt Scanner:** photograph a receipt → auto-fill expense.

### Phase 2.1 — Guardian Portal
Parents view attendance/homework/results; WhatsApp auto-report; monthly PDF report.

### Phase 3 — Public Launch
Play Store release as **"Life Tracker Pro Bangladesh"**; multi-tutor accounts; premium tier (result prediction, QR attendance).

---

## 8. Non-Goals (for v1)
- No multi-tutor/organization accounts.
- No payment gateway (fees are tracked, not collected in-app).
- No web client (mobile-first; web is a later consideration).

---

## 9. Success Metrics
- Class log entry completed in **< 30s**; expense entry in **< 3s**.
- Dashboard cold-start **< 1s** (local).
- Zero data loss across reinstall (with backup) and offline use.
