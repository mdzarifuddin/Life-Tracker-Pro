# 🗄️ Life Tracker Pro — Database Design

Single source-of-truth schema for both the **PostgreSQL backend** and the **Drift (SQLite) local store**. Types are given generically; map to `TEXT/INTEGER/REAL/BOOLEAN` (SQLite) or `uuid/varchar/numeric/timestamptz/boolean` (PostgreSQL).

**Conventions**
- Every table has `id` (UUID), `created_at`, `updated_at` (UTC).
- Syncable tables also have `dirty` (bool) and `deleted` (bool, soft delete).
- Money stored as `numeric(12,2)` (BDT). All FKs are UUIDs.

---

## 1. ERD (overview)

```
users 1───* students 1───* class_logs
                  │
                  ├──* schedules
                  ├──* payments ──(auto)──> finance_transactions
                  └──* exam_events

users 1───* finance_transactions *───1 categories
users 1───* assets
users 1───* goals
users 1───* project_costs 1───* project_cost_items
users 1───* job_tasks
users 1───* thesis_stages
users 1───* notifications
users 1───1 settings

users 1───* shopping_lists 1───* list_items
                shopping_lists 1───* list_members   (by Gmail; real-time via Firestore)
```

---

## 2. Tables

### users
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| name | text | |
| email | text | unique (Firebase) |
| photo_url | text | nullable |
| created_at / updated_at | timestamptz | |

### students
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| user_id | uuid (FK→users) | |
| name | text | |
| phone | text | nullable |
| class | text | e.g. "HSC 1st Year" |
| institution | text | school/college |
| batch | text | e.g. "HSC 2027" |
| monthly_fee | numeric(12,2) | |
| subjects | json/text[] | |
| weak_subjects | json/text[] | |
| guardian_name | text | nullable |
| guardian_phone | text | nullable |
| father_name / mother_name | text | nullable |
| address | text | nullable |
| status | text | `active` / `archived` |
| created_at / updated_at / dirty / deleted | | |

### class_logs  ⭐
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| student_id | uuid (FK→students) | |
| date | date | defaults today |
| topics | text | covered topics |
| homework | text | |
| performance | int | 0–10 |
| remarks | text | nullable |
| ai_summary | text | generated "last class summary" |
| source | text | `manual` / `voice` |
| created_at / updated_at / dirty / deleted | | |

### schedules
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| student_id | uuid (FK→students) | |
| day_of_week | int | 0–6 (recurring) |
| start_time | time | |
| duration_min | int | |
| location | text | nullable |
| reminder_min | int | lead time, default 30 |
| created_at / updated_at / dirty / deleted | | |
> Conflict detection = overlapping (`day_of_week`, time range) rows.

### payments
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| student_id | uuid (FK→students) | |
| month | text | `YYYY-MM` |
| amount | numeric(12,2) | |
| status | text | `paid` / `pending` / `partial` |
| paid_amount | numeric(12,2) | for partial |
| paid_date | date | nullable |
| finance_txn_id | uuid (FK→finance_transactions) | the auto-created income link |
| created_at / updated_at / dirty / deleted | | |

### categories
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| user_id | uuid (FK→users) | |
| name | text | |
| type | text | `income` / `expense` |
| icon | text | icon enum key |
| color | text | hex from category palette |
| is_default | bool | seeded vs custom |
| created_at / updated_at / dirty / deleted | | |
> **Seeded expense:** Food, Transport, Internet, Mobile Recharge, Books, Tuition Travel, Family, Medical, Shopping, Entertainment, Govt Job, Thesis, Software, Subscriptions, Investment, Other.
> **Seeded income:** Tuition, Freelancing, Scholarship, Gift, Salary, Business, Other.

### finance_transactions  🔒 (vault — encrypted locally via SQLCipher)
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| user_id | uuid (FK→users) | |
| type | text | `income` / `expense` |
| category_id | uuid (FK→categories) | |
| amount | numeric(12,2) | |
| date | date | defaults today |
| account | text | `cash` / `bkash` / `nagad` / `bank` |
| source_ref | text | nullable, e.g. "payment:{id}" for auto-linked income |
| note | text | nullable |
| created_at / updated_at / dirty / deleted | | |

### assets  🔒
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| user_id | uuid (FK→users) | |
| account | text | Cash / bKash / Nagad / Bank |
| balance | numeric(12,2) | |
| updated_at / dirty / deleted | | |
> Net worth = `SUM(balance)`.

### goals  🔒
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| user_id | uuid (FK→users) | |
| title | text | e.g. "New Laptop", "GRE Fund", "Emergency Fund" |
| target_amount | numeric(12,2) | |
| saved_amount | numeric(12,2) | |
| deadline | date | nullable |
| created_at / updated_at / dirty / deleted | | |
> Progress = `saved_amount / target_amount`.

### project_costs  🔒
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| user_id | uuid (FK→users) | |
| title | text | e.g. "MSc Thesis", "Govt Job", "App Project" |
| created_at / updated_at / dirty / deleted | | |

### project_cost_items  🔒
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| project_id | uuid (FK→project_costs) | |
| label | text | e.g. "Printing", "Server", "Exam Fees" |
| amount | numeric(12,2) | |
| date | date | |
> Total project cost = `SUM(amount)` per project.

### exam_events
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| student_id | uuid (FK→students) | nullable for own exams |
| title | text | |
| subject | text | |
| exam_type | text | SSC / HSC / Monthly / Pre-Test / Model |
| date | date | |
| reminder_days | int[] | e.g. [7,3,1] |
| created_at / updated_at / dirty / deleted | | |

### job_tasks (Govt Job prep)
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| user_id | uuid (FK→users) | |
| date | date | |
| subject | text | Bangla / English / Math / GK / ICT |
| target | int | e.g. 50 MCQ |
| completed | int | |
| created_at / updated_at / dirty / deleted | | |

### thesis_stages
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| user_id | uuid (FK→users) | |
| stage | text | Lit Review / Methodology / Implementation / Results / Writing / Defense |
| progress | int | 0–100 |
| deadline | date | nullable |
| notes | text | nullable |
| weight | int | for weighted overall % |
| created_at / updated_at / dirty / deleted | | |

### notifications
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| user_id | uuid (FK→users) | |
| type | text | class / exam / fee / deadline |
| title / body | text | |
| scheduled_at | timestamptz | |
| ref_id | uuid | linked entity |
| read | bool | |

### settings
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| user_id | uuid (FK→users) | one row |
| theme | text | `dark` (default) / `light` / `system` |
| language | text | `bn` / `en` |
| vault_pin_hash | text | salted hash |
| biometric_enabled | bool | |
| vault_lock_timeout_sec | int | auto-lock |
| hidden_balance | bool | |
| notifications_enabled | bool | |
| last_sync_cursor | text | sync bookmark |
| google_account_email | text | for shared lists (nullable) |

### shopping_lists  🛒 (shared — mirrored to Firestore)
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | matches Firestore `listId` |
| owner_user_id | uuid (FK→users) | |
| title | text | |
| type | text | `bazar` / `future_needs` |
| is_archived | bool | completed bazar trips archive |
| created_at / updated_at / dirty / deleted | | |

### list_items  🛒
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| list_id | uuid (FK→shopping_lists) | |
| name | text | |
| quantity | text | e.g. "2 kg", "1 dozen" |
| unit | text | nullable |
| category | text | Grocery / Vegetables / Fish-Meat / Dairy / Household / Other |
| est_price | numeric(12,2) | nullable; running total source |
| priority | text | future-needs: `low`/`med`/`high` |
| target_month | text | future-needs: `YYYY-MM`, nullable |
| note | text | nullable |
| is_bought | bool | bazar checkbox |
| bought_by | text | member display name/email |
| bought_at | timestamptz | nullable |
| updated_by | text | for "updated by <name>" attribution |
| position | int | manual sort order |
| created_at / updated_at / dirty / deleted | | |

### list_members  🛒
| Column | Type | Notes |
|:-------|:-----|:------|
| id | uuid (PK) | |
| list_id | uuid (FK→shopping_lists) | |
| email | text | Gmail of the member (sharing key) |
| display_name | text | nullable |
| role | text | `owner` / `editor` |
| joined_at | timestamptz | nullable until accepted |

> **Real-time mirror:** shared lists live primarily in **Cloud Firestore** (`lists/{id}` + `items/{id}` subcollection, `memberEmails[]`, `roles{}`) for live multi-user editing and offline sync. The tables above are the local Drift cache / backend record. **No finance or vault data is ever written to Firestore.**

---

## 3. Key Relationships & Rules
- **Fee → income link:** inserting/updating a `payments` row to `paid`/`partial` creates a `finance_transactions` income row (category = Tuition, `source_ref = payment:{id}`); reversing the payment soft-deletes that transaction.
- **Bazar trip → expense link:** "Complete shopping trip" on a `bazar` list sets `is_archived=true` and creates one `finance_transactions` expense row (category = Grocery/Food, `source_ref = list:{id}`) with the actual total.
- **Future-need → goal:** promoting a `future_needs` item creates a `goals` row (`title`, `target_amount = est_price`).
- **Soft deletes** everywhere (`deleted=true`) so sync can propagate removals.
- **Vault tables** (`finance_transactions`, `assets`, `goals`, `project_costs`, `project_cost_items`) live in the encrypted SQLCipher DB locally and behind auth on the server.
- **Indexes:** `students(user_id, status)`, `class_logs(student_id, date)`, `payments(student_id, month)`, `finance_transactions(user_id, date, type)`, `schedules(student_id, day_of_week)`, `list_items(list_id, is_bought, position)`, `list_members(email)`.

---

## 4. Seed Data (first run)
1. Create the local `users` row (single-user) + default `settings`.
2. Insert the 16 default expense + 7 default income `categories` (`is_default=true`).
3. Insert the 6 default `thesis_stages` (progress 0).
4. Seed common **bazar quick-add items** for 1-tap entry (e.g. Rice, Oil, Onion, Potato, Egg, Lentil/Dal, Garlic, Ginger, Salt, Sugar, Flour, Fish, Chicken, Milk, Tea, Vegetables) — selectable, not typed.
