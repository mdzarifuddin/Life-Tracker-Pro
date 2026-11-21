// Fee engine: pure Dart (no Hive, no Flutter) so it is easy to unit-test.
//
// A "cycle" is one billing month, named by the 'yyyy-MM' of the month it starts in
// (billing day 1 = calendar month; billing day 17 = 17th to 16th). For every cycle the
// engine works out what was charged, what was paid, what is still owed and whether
// that is due / overdue. Unpaid money rolls forward; extra money becomes credit.
import '../models.dart';

String feeKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// First day of the cycle that starts in [month] (clamped for short months).
DateTime feeCycleStart(int billingDay, DateTime month) {
  final last = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, billingDay > last ? last : billingDay);
}

/// Last moment of the cycle that starts in [month].
DateTime feeCycleEnd(int billingDay, DateTime month) {
  final next = feeCycleStart(billingDay, DateTime(month.year, month.month + 1));
  return DateTime(next.year, next.month, next.day - 1, 23, 59, 59);
}

/// The cycle (by its starting month) that contains [d].
DateTime feeCycleMonthOf(int billingDay, DateTime d) {
  final m = DateTime(d.year, d.month);
  return d.isBefore(feeCycleStart(billingDay, m)) ? DateTime(d.year, d.month - 1) : m;
}

/// The plan version in effect for cycle [key]: the last one starting on or before it.
FeePlan feePlanFor(List<FeePlan> plans, String key) {
  final sorted = [...plans]..sort((a, b) => a.from.compareTo(b.from));
  FeePlan? pick;
  for (final p in sorted) {
    if (p.from.compareTo(key) <= 0) pick = p;
  }
  return pick ?? sorted.first;
}

/// Everything about one billing cycle.
class CycleStatement {
  CycleStatement({
    required this.key, required this.month, required this.start, required this.end,
    required this.dueDate, required this.graceEnd, required this.classes,
    required this.plan, required this.base, required this.isCustom,
    required this.planDiscount, required this.adjustments, required this.lateFee,
    required this.net, required this.paid, required this.opening,
    required this.payments, required this.record,
  });

  final String key;
  final DateTime month, start, end, dueDate, graceEnd;
  final int classes;
  final FeePlan plan;
  /// The fee before discounts: from the plan, or set by hand ([isCustom]).
  final double base;
  final bool isCustom;
  final double planDiscount;
  final List<FeeAdjustment> adjustments;
  final double lateFee;
  /// What this cycle costs: base − discounts + extra charges + late fee.
  final double net;
  final double paid;
  /// Balance brought in from earlier cycles (+ owed, − credit).
  final double opening;
  final List<PayInstallment> payments;
  final Payment? record;

  // Set by the engine after the oldest-first allocation of payments.
  double outstanding = 0; // part of this cycle's own bill still unpaid
  String status = 'none'; // none | upcoming | due | overdue | paid
  bool partial = false; // some of this cycle's bill is paid but not all
  int overdueDays = 0;

  /// Balance after this cycle: owed (+) or credit (−).
  double get closing => opening + net - paid;
  double get extraCharges =>
      adjustments.where((a) => a.kind == FeeAdjustment.charge).fold(0.0, (s, a) => s + a.amount);
  double get discounts =>
      planDiscount + adjustments.where((a) => a.kind != FeeAdjustment.charge).fold(0.0, (s, a) => s + a.amount);
}

enum LedgerKind { charge, discount, extra, lateFee, payment }

class LedgerEntry {
  LedgerEntry({required this.date, required this.kind, required this.label, required this.amount,
      required this.cycleKey, this.refId = '', this.running = 0});
  final DateTime date;
  final LedgerKind kind;
  final String label, cycleKey, refId;
  /// + increases what is owed, − reduces it.
  final double amount;
  double running;
}

class FeeAccount {
  FeeAccount({required this.cycles, required this.balance, required this.totalPaid,
      required this.overdueAmount, required this.overdueDays, required this.dueSoonAmount,
      required this.nextDue, required this.todayKey});

  final List<CycleStatement> cycles;
  /// All billed so far minus everything paid (+ owed, − credit).
  final double balance;
  final double totalPaid, overdueAmount, dueSoonAmount;
  final int overdueDays;
  final DateTime? nextDue;
  final String todayKey;

  double get owed => balance > 0.5 ? balance : 0;
  double get credit => balance < -0.5 ? -balance : 0;
  bool get isOverdue => overdueAmount > 0.5;

  CycleStatement? statementFor(String key) {
    for (final c in cycles) {
      if (c.key == key) return c;
    }
    return null;
  }

  CycleStatement? get current => statementFor(todayKey);

  /// Cycles that still have something unpaid, oldest first.
  List<CycleStatement> get unpaid => cycles.where((c) => c.outstanding > 0.5).toList();

  /// Every charge, discount and payment as a dated list with a running balance.
  List<LedgerEntry> ledger() {
    final out = <LedgerEntry>[];
    for (final c in cycles) {
      if (c.base > 0.005) {
        out.add(LedgerEntry(date: c.start, kind: LedgerKind.charge, cycleKey: c.key,
            label: c.isCustom ? 'Fee (set by hand)' : _chargeLabel(c), amount: c.base));
      }
      if (c.planDiscount > 0.005) {
        out.add(LedgerEntry(date: c.start, kind: LedgerKind.discount, cycleKey: c.key,
            label: 'Scholarship / discount', amount: -c.planDiscount));
      }
      for (final a in c.adjustments) {
        out.add(LedgerEntry(
            date: _dateOnly(a.date), cycleKey: c.key, refId: a.id,
            kind: a.kind == FeeAdjustment.charge ? LedgerKind.extra : LedgerKind.discount,
            label: a.label.isEmpty
                ? (a.kind == FeeAdjustment.charge ? 'Extra charge' : a.kind == FeeAdjustment.waiver ? 'Waiver' : 'Discount')
                : a.label,
            amount: a.signed));
      }
      if (c.lateFee > 0.005) {
        out.add(LedgerEntry(date: c.graceEnd.add(const Duration(days: 1)), kind: LedgerKind.lateFee,
            cycleKey: c.key, label: 'Late fee', amount: c.lateFee));
      }
      for (final p in c.payments) {
        out.add(LedgerEntry(date: _dateOnly(p.date), kind: LedgerKind.payment, cycleKey: c.key,
            refId: p.id, label: 'Payment', amount: -p.amount));
      }
    }
    out.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.kind.index.compareTo(b.kind.index);
    });
    var run = 0.0;
    for (final e in out) {
      run += e.amount;
      e.running = run;
    }
    return out;
  }

  static String _chargeLabel(CycleStatement c) {
    final p = c.plan;
    switch (p.kind) {
      case FeePlan.perClass:
        return '${c.classes} ${c.classes == 1 ? 'class' : 'classes'} × ${_n(p.amount)}';
      case FeePlan.monthly:
        return p.classesPerCycle > 0
            ? '${c.classes} ${c.classes == 1 ? 'class' : 'classes'} × ${_n(p.amount / p.classesPerCycle)}'
            : 'Monthly fee';
      case FeePlan.package:
        return 'Package (${p.packageSize} classes)';
      default:
        return 'Fee';
    }
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

/// Works out the whole fee account of one student.
///
/// * [classDates] — dates of all classes taught.
/// * [records] — payment records by cycle key ('yyyy-MM').
/// * [through] — also compute up to this cycle (default: the cycle containing [today]).
FeeAccount computeFeeAccount({
  required Student s,
  required List<DateTime> classDates,
  required Map<String, Payment> records,
  required FeeSettings cfg,
  required DateTime today,
  DateTime? through,
}) {
  final bd = s.billingDay;
  final today0 = _dateOnly(today);
  final plans = s.plans;
  final dates = [...classDates]..sort();

  // Where billing starts: the first class / creation date, unless set by hand.
  var from = s.createdAt;
  for (final d in dates) {
    if (d.isBefore(from)) from = d;
  }
  final bs = s.billingStartDate;
  if (bs != null) from = bs;
  final firstM = feeCycleMonthOf(bd, from);
  var lastM = feeCycleMonthOf(bd, today);
  if (through != null) {
    final t = DateTime(through.year, through.month);
    if (t.isAfter(lastM)) lastM = t;
  }
  final startM = firstM.isAfter(lastM) ? lastM : firstM;

  final leftM = (!s.isCurrent && s.leftDate != null) ? feeCycleMonthOf(bd, s.leftDate!) : null;

  int classesBetween(DateTime a, DateTime b) =>
      dates.where((d) => !d.isBefore(a) && !d.isAfter(b)).length;

  final firstKey = feeKey(startM);
  final cycles = <CycleStatement>[];
  var n = 0;
  for (var m = startM; !m.isAfter(lastM) && n < 600; m = DateTime(m.year, m.month + 1), n++) {
    final key = feeKey(m);
    final rec = records[key];
    final cs = feeCycleStart(bd, m), ce = feeCycleEnd(bd, m);
    final classes = classesBetween(cs, ce);
    final plan = feePlanFor(plans, key);
    final afterLeft = leftM != null && m.isAfter(leftM);

    // --- base fee for the cycle ---
    double base;
    final custom = rec?.customDue;
    if (custom != null) {
      base = custom;
    } else {
      switch (plan.kind) {
        case FeePlan.perClass:
          base = plan.amount * classes;
          break;
        case FeePlan.package:
          final size = plan.packageSize > 0 ? plan.packageSize : 1;
          final vs = plan.from.isEmpty ? DateTime(2000) : feeCycleStart(bd, DateTime.parse('${plan.from}-01'));
          final tEnd = classesBetween(vs, ce);
          final tStart = classesBetween(vs, cs.subtract(const Duration(seconds: 1)));
          final blocks = ((tEnd + size - 1) ~/ size) - ((tStart + size - 1) ~/ size);
          base = plan.amount * blocks;
          break;
        case FeePlan.fixed:
          final startKey = plan.from.isEmpty ? firstKey : plan.from;
          base = (key == startKey && !afterLeft) ? plan.amount : 0;
          break;
        default: // monthly
          if (plan.classesPerCycle > 0) {
            base = plan.amount / plan.classesPerCycle * classes;
          } else {
            base = afterLeft ? 0 : plan.amount;
          }
      }
    }

    final planDiscount = custom != null
        ? 0.0
        : (base * plan.discountPct / 100 + plan.discountFlat).clamp(0.0, base < 0 ? 0.0 : base).toDouble();
    final adj = rec?.adjustments ?? const <FeeAdjustment>[];
    final adjTotal = adj.fold(0.0, (t, a) => t + a.signed);

    // --- due date ---
    final dueDay = plan.dueDay ?? cfg.defaultDueDay;
    final dueRaw = dueDay <= 0 ? _dateOnly(ce) : cs.add(Duration(days: dueDay - 1));
    final dueDate = dueRaw.isAfter(ce) ? _dateOnly(ce) : _dateOnly(dueRaw);
    final grace = plan.graceDays ?? cfg.defaultGraceDays;
    final graceEnd = dueDate.add(Duration(days: grace));

    cycles.add(CycleStatement(
      key: key, month: m, start: cs, end: ce, dueDate: dueDate, graceEnd: graceEnd,
      classes: classes, plan: plan, base: base, isCustom: custom != null,
      planDiscount: planDiscount, adjustments: adj,
      lateFee: 0, // filled in below
      net: base - planDiscount + adjTotal,
      paid: rec?.paid ?? 0, opening: 0,
      payments: [...?rec?.installments]..sort((a, b) => a.date.compareTo(b.date)),
      record: rec,
    ));
  }

  // --- late fees: a cycle that is still unpaid after its grace period gets one ---
  final allPayments = <PayInstallment>[
    for (final r in records.values) ...r.installments,
  ]..sort((a, b) => a.date.compareTo(b.date));
  final withLate = <CycleStatement>[];
  for (var i = 0; i < cycles.length; i++) {
    final c = cycles[i];
    final rate = c.plan.lateFee ?? (cfg.lateFeeOn ? cfg.lateFeeAmount : 0.0);
    var late = 0.0;
    if (rate > 0 && !(c.record?.lateFeeWaived ?? false) && c.net > 0.5 && today0.isAfter(c.graceEnd)) {
      // Pay the oldest bills first, using only money received by the end of the grace period.
      var pool = allPayments
          .where((p) => !_dateOnly(p.date).isAfter(c.graceEnd))
          .fold(0.0, (t, p) => t + p.amount);
      for (var j = 0; j <= i; j++) {
        final w = j == i ? c : withLate[j];
        if (w.net <= 0) {
          pool += -w.net;
          continue;
        }
        if (j == i) {
          if (pool < c.net - 0.5) late = rate;
        } else {
          pool -= w.net < pool ? w.net : pool;
        }
      }
    }
    withLate.add(late == 0 ? c : _withLate(c, late));
  }

  // --- opening balances, then oldest-first allocation of payments ---
  final fin = <CycleStatement>[];
  var run = 0.0;
  for (final c in withLate) {
    final x = _withOpening(c, run);
    run = x.closing;
    fin.add(x);
  }
  var pool = allPayments.fold(0.0, (t, p) => t + p.amount);
  for (final c in fin) {
    if (c.net < 0) pool += -c.net;
  }
  for (final c in fin) {
    if (c.net <= 0.5) {
      c.outstanding = 0;
      continue;
    }
    final used = pool < c.net ? (pool < 0 ? 0.0 : pool) : c.net;
    pool -= used;
    c.outstanding = c.net - used;
    c.partial = used > 0.5 && c.outstanding > 0.5;
  }

  // --- status of every cycle ---
  DateTime? nextDue;
  var overdueAmt = 0.0, dueSoonAmt = 0.0, oldestOver = 0;
  for (final c in fin) {
    if (c.net <= 0.5) {
      c.status = c.paid > 0.5 ? 'paid' : 'none';
    } else if (c.outstanding <= 0.5) {
      c.status = 'paid';
    } else if (today0.isAfter(c.graceEnd)) {
      c.status = 'overdue';
      c.overdueDays = today0.difference(c.graceEnd).inDays;
      overdueAmt += c.outstanding;
      if (c.overdueDays > oldestOver) oldestOver = c.overdueDays;
    } else if (!today0.isBefore(c.dueDate.subtract(Duration(days: cfg.dueSoonDays)))) {
      c.status = 'due';
      dueSoonAmt += c.outstanding;
    } else {
      c.status = 'upcoming';
    }
    if (c.outstanding > 0.5 && (nextDue == null || c.dueDate.isBefore(nextDue))) nextDue = c.dueDate;
  }

  final billed = fin.fold(0.0, (t, c) => t + c.net);
  final paidAll = allPayments.fold(0.0, (t, p) => t + p.amount);
  return FeeAccount(
    cycles: fin,
    balance: billed - paidAll,
    totalPaid: paidAll,
    overdueAmount: overdueAmt,
    overdueDays: oldestOver,
    dueSoonAmount: dueSoonAmt,
    nextDue: nextDue,
    todayKey: feeKey(feeCycleMonthOf(bd, today)),
  );
}

CycleStatement _withLate(CycleStatement c, double late) => CycleStatement(
      key: c.key, month: c.month, start: c.start, end: c.end, dueDate: c.dueDate,
      graceEnd: c.graceEnd, classes: c.classes, plan: c.plan, base: c.base,
      isCustom: c.isCustom, planDiscount: c.planDiscount, adjustments: c.adjustments,
      lateFee: late, net: c.net + late, paid: c.paid, opening: c.opening,
      payments: c.payments, record: c.record);

CycleStatement _withOpening(CycleStatement c, double opening) => CycleStatement(
      key: c.key, month: c.month, start: c.start, end: c.end, dueDate: c.dueDate,
      graceEnd: c.graceEnd, classes: c.classes, plan: c.plan, base: c.base,
      isCustom: c.isCustom, planDiscount: c.planDiscount, adjustments: c.adjustments,
      lateFee: c.lateFee, net: c.net, paid: c.paid, opening: opening,
      payments: c.payments, record: c.record);
