# 🎨 Life Tracker Pro — Design System

> **Clean · Fast · Premium · One-hand use · Zero clutter**
> Inspired by **Monefy** (finance), **Notion** (calm modular layout), **Google Calendar** (scheduling).
> **Dark mode is the default.** Light mode is fully supported.

This document defines exact design tokens so the UI can be implemented consistently. All values are ready to drop into a Flutter `ThemeData` / token file.

---

## 1. Brand

- **Name:** Life Tracker Pro
- **Tagline:** *Manage Tuition, Finance, Study & Family — From One Place*
- **Personality:** confident, focused, premium, trustworthy. Not playful, not corporate-cold.
- **Currency:** Bangladeshi Taka — symbol `৳`, format `৳ 27,000` (thousands separator, no decimals for whole amounts).

---

## 2. Color Tokens

### 2.1 Brand & Accent
| Token | Hex | Use |
|:------|:----|:----|
| `primary` | `#6366F1` | Primary actions, active nav, links (Indigo 500) |
| `primaryContainer` | `#4F46E5` | Pressed / emphasized primary |
| `accent` | `#22D3EE` | Highlights, focus rings (Cyan 400) |

### 2.2 Semantic (Finance + status)
| Token | Hex | Use |
|:------|:----|:----|
| `income` / `success` | `#10B981` | Income, paid, positive (Emerald 500) |
| `expense` / `danger` | `#F43F5E` | Expense, conflicts, due (Rose 500) |
| `warning` | `#F59E0B` | Pending, deadlines soon (Amber 500) |
| `savings` | `#3B82F6` | Savings, neutral money (Blue 500) |
| `info` | `#0EA5E9` | Informational chips |

### 2.3 Dark theme (default)
| Token | Hex | Use |
|:------|:----|:----|
| `background` | `#0F1115` | App background |
| `surface` | `#161A20` | Cards, sheets |
| `surfaceVariant` | `#1F242C` | Elevated cards, inputs |
| `outline` | `#2A2F37` | Borders, dividers |
| `onBackground` | `#E6E8EC` | Primary text |
| `onSurfaceMuted` | `#9AA1AC` | Secondary text |
| `disabled` | `#5A616B` | Disabled text/icons |

### 2.4 Light theme
| Token | Hex | Use |
|:------|:----|:----|
| `background` | `#F7F8FA` | App background |
| `surface` | `#FFFFFF` | Cards, sheets |
| `surfaceVariant` | `#EEF0F3` | Inputs, elevated |
| `outline` | `#E2E5EA` | Borders, dividers |
| `onBackground` | `#1A1D21` | Primary text |
| `onSurfaceMuted` | `#5C636E` | Secondary text |

### 2.5 Category color palette (Finance / Calendar)
Used for Monefy-style category bubbles and calendar event dots. Assign cyclically to custom categories.
```
#6366F1  #10B981  #F43F5E  #F59E0B  #3B82F6  #8B5CF6
#EC4899  #14B8A6  #EAB308  #F97316  #06B6D4  #84CC16
```

---

## 3. Typography

**Font:** `Inter` (UI) + `Hind Siliguri` (Bangla support). Tabular figures for money.

| Style | Size / Weight | Use |
|:------|:--------------|:----|
| `display` | 32 / Bold | Big balance numbers, net worth |
| `h1` | 24 / SemiBold | Screen titles |
| `h2` | 20 / SemiBold | Section headers |
| `title` | 16 / SemiBold | Card titles, list items |
| `body` | 14 / Regular | Body text |
| `label` | 13 / Medium | Buttons, chips |
| `caption` | 12 / Regular | Meta, timestamps |
| `mono-amount` | 18 / SemiBold (tabular) | Money values in lists |

---

## 4. Spacing, Radius, Elevation

- **Spacing scale (dp):** `4 · 8 · 12 · 16 · 20 · 24 · 32 · 48`. Default screen padding = `16`.
- **Radius:** cards `16`, sheets/modals `24` (top), chips/buttons `12`, full-pill = `999`.
- **Elevation:** flat by default; cards use a soft shadow (`y4, blur 16, 8% black`) in light mode, subtle border in dark mode.
- **Touch targets:** minimum `48×48`. Primary actions reachable by thumb (bottom 1/3 of screen).

---

## 5. Core Components

| Component | Spec |
|:----------|:-----|
| **Bottom Nav** | 5 items: Dashboard · Students · Schedule · Finance · More. Center has a raised **FAB** for Quick Add. |
| **Quick Add FAB** | Tapping opens a radial / bottom-sheet menu: `+ Expense`, `+ Income`, `+ Add Student`, `+ Log Class`. |
| **Stat Card** | Title + big number + delta chip (▲/▼). Used on Dashboard & Finance. |
| **Category Bubble** | Circular icon (Monefy-style), label below, colored from category palette. |
| **Progress Ring / Bar** | Used for thesis stages, job-prep targets, savings goals. |
| **Schedule Card** | Time · student · location · duration · reminder. Conflicts render with `expense` red left-border. |
| **Amount Pill** | Tabular figure with semantic color (green income / red expense). |
| **Bottom Sheet Form** | Default for all quick entry (expense, income, class log). Keyboard-aware, single-screen, ≤3 taps. |
| **Empty State** | Friendly illustration + one-line prompt + primary CTA. |
| **Hidden Balance** | `৳ ******` until tapped (Finance Vault). |
| **List Item Row** | Leading checkbox · item name · qty/unit · trailing est. price + small "updated by" avatar. Bought items dim + strike-through, grouped below. |
| **Shared-List Header** | Title + stacked member avatars + a "Shared" chip; tap avatars to manage members (invite by Gmail). |
| **Bazar Quick-Add Chips** | Horizontally scrollable pre-seeded item chips (Rice, Oil, Onion…) for 1-tap add, recents first. |
| **Member Avatar** | Circular initial/photo from Google account; colored ring shows who last edited. |

---

## 6. Signature Flows (must feel instant)

### 6.1 Add Expense (Monefy-style, ≤3 seconds)
```
Tap FAB → "Expense"
   ↓
Grid of category bubbles (recently used first)
   ↓  tap "Food"
Numeric keypad sheet → type "200"
   ↓  tap ✓
Saved. Toast: "৳200 · Food added"   (auto-dated today)
```
- Categories are **pre-seeded** (see PRD §Finance). User just selects.
- If a needed category isn't there → `+ Create New` (one time) → it's stored permanently and reused.

### 6.2 Log a Class (≤30 seconds)
```
Tap FAB → "Log Class" (or from Student profile)
   ↓
Pick student (defaults to next scheduled) · today's date prefilled
   ↓
Topics · Homework · Performance (slider 0–10) · Remarks
   ↓  🎤 optional voice input → speech-to-text fills topics/homework
Save → next time the app shows "Last Class Summary" for that student
```

### 6.3 Receive a Fee → auto income
```
Payments → mark "Rahim · Paid ৳5000"
   ↓
Auto-creates Income entry (category: Tuition, source: Rahim) in Finance
```

### 6.4 Shared Bazar List (you + wife, real-time)
```
Family Lists → "Bazar" tab (shared via Google)
   ↓  husband adds "Rice 5kg" from quick-add chips
Wife's phone updates within seconds → she adds "Fish 1kg"
   ↓  at the market, tap items to check off (shows "bought by …")
"Complete trip" → enter actual total ৳1,250
   ↓
Auto-logs an Expense (category: Grocery) · list archives
```
- Works offline; edits merge on reconnect. Only invited Gmail accounts can see the list.

---

## 7. Motion

- **Durations:** micro `120ms`, standard `220ms`, sheet `300ms`. Curve: `easeOutCubic`.
- **Number transitions:** balances animate (count-up) on change.
- **Page transitions:** shared-axis (horizontal for nav, vertical for sheets).
- Keep it subtle — premium means restraint, not flashiness.

---

## 8. Accessibility & Localization

- WCAG AA contrast for all text on its surface.
- Full **বাংলা / English** localization (`flutter_localizations` + ARB files). Bangla numerals optional.
- Dynamic type: respect OS font scaling up to 1.3×.
- All icons paired with text labels where space allows; semantic labels for screen readers.

---

## 9. Iconography

- Library: **Lucide** (or `Phosphor`) — consistent stroke, rounded.
- Each module has a signature icon (used in nav + headers + reports).
- Category icons stored as a fixed enum so they survive sync and export.
