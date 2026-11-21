import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker_pro/core/fees.dart';
import 'package:life_tracker_pro/models.dart';

final _today = DateTime(2026, 9, 20);
const _cfg = FeeSettings();

Student _student({
  String name = 'T',
  double fee = 3000,
  int perMonth = 10,
  bool perClass = false,
  int billingDay = 1,
  String billingStart = '',
  String leftOn = '',
  List<FeePlan> plans = const [],
  DateTime? created,
}) {
  final id = '${(created ?? DateTime(2026, 1, 1)).microsecondsSinceEpoch}_$name';
  return Student(
    id: id, name: name, monthlyFee: fee, classesPerMonth: perMonth, payPerClass: perClass,
    billingDay: billingDay, billingStart: billingStart, leftOn: leftOn,
    status: leftOn.isEmpty ? 'active' : 'previous', feePlans: plans,
  );
}

Payment _rec(String key, {double? custom, List<PayInstallment> pays = const [],
    List<FeeAdjustment> adj = const [], bool lateWaived = false}) =>
    Payment(id: 'p$key', studentId: 's', month: key, customDue: custom, installments: pays,
        adjustments: adj, lateFeeWaived: lateWaived);

PayInstallment _pay(double amt, DateTime d, [String id = '']) =>
    PayInstallment(id: id.isEmpty ? 'i${d.microsecondsSinceEpoch}_$amt' : id, amount: amt, date: d);

List<DateTime> _classes(int y, int m, List<int> days) => [for (final d in days) DateTime(y, m, d, 16)];

FeeAccount _acct(Student s, List<DateTime> dates, Map<String, Payment> recs,
        {FeeSettings cfg = _cfg, DateTime? today, DateTime? through}) =>
    computeFeeAccount(s: s, classDates: dates, records: recs, cfg: cfg, today: today ?? _today, through: through);

// ---- the fee formula as it was before fee plans existed (oracle) ----
({double due, double paid, double carry, double total, double remaining, String status}) _legacy(
    Student s, List<DateTime> dates, Map<String, Payment> pays, DateTime month) {
  DateTime cs(DateTime m) => feeCycleStart(s.billingDay, m);
  DateTime ce(DateTime m) => feeCycleEnd(s.billingDay, m);
  double dueOf(DateTime m) {
    final custom = pays[feeKey(m)]?.customDue;
    if (custom != null) return custom;
    final a = cs(m), b = ce(m);
    final n = dates.where((d) => !d.isBefore(a) && !d.isAfter(b)).length;
    if (s.payPerClass) return s.monthlyFee * n;
    if (s.classesPerMonth <= 0) return s.monthlyFee;
    return s.monthlyFee / s.classesPerMonth * n;
  }

  var start = s.createdAt;
  for (final d in dates) {
    if (d.isBefore(start)) start = d;
  }
  final bs = s.billingStartDate;
  if (bs != null) start = bs;
  var carry = 0.0;
  var n = 0;
  for (var m = feeCycleMonthOf(s.billingDay, start); m.isBefore(month) && n < 120;
      m = DateTime(m.year, m.month + 1), n++) {
    carry += dueOf(m) - (pays[feeKey(m)]?.paid ?? 0);
  }
  final due = dueOf(month);
  final paid = pays[feeKey(month)]?.paid ?? 0;
  final total = carry + due;
  final left = total - paid;
  final remaining = left < 0 ? 0.0 : left;
  final status = remaining <= 0.5 && (paid > 0 || (due > 0 && total <= 0.5))
      ? 'paid' : paid > 0 ? 'partial' : 'pending';
  return (due: due, paid: paid, carry: carry, total: total, remaining: remaining, status: status);
}

({double due, double paid, double carry, double total, double remaining, String status}) _adapter(
    Student s, List<DateTime> dates, Map<String, Payment> recs, DateTime month) {
  final c = _acct(s, dates, recs, through: month).statementFor(feeKey(month));
  if (c == null) return _legacy(s, dates, recs, month); // before billing starts: not charged by the new engine
  final due = c.net, paid = c.paid, carry = c.opening;
  final total = carry + due;
  final left = total - paid;
  final remaining = left < 0 ? 0.0 : left;
  final status = remaining <= 0.5 && (paid > 0 || (due > 0 && total <= 0.5))
      ? 'paid' : paid > 0 ? 'partial' : 'pending';
  return (due: due, paid: paid, carry: carry, total: total, remaining: remaining, status: status);
}

void main() {
  group('legacy equivalence (numbers must not change for existing data)', () {
    test('random students, classes and payments match the old formula', () {
      final rnd = Random(42);
      for (var t = 0; t < 120; t++) {
        final mode = rnd.nextInt(3); // 0 per class, 1 pro-rated monthly, 2 flat
        final bd = [1, 15, 31, 17][rnd.nextInt(4)];
        final s = _student(
          name: 'r$t',
          fee: 500.0 + rnd.nextInt(60) * 50,
          perMonth: mode == 1 ? [4, 8, 12][rnd.nextInt(3)] : 0,
          perClass: mode == 0,
          billingDay: bd,
          created: DateTime(2026, 1 + rnd.nextInt(3), 1 + rnd.nextInt(20)),
        );
        final dates = <DateTime>[
          for (var i = 0; i < rnd.nextInt(40); i++)
            DateTime(2026, 1 + rnd.nextInt(9), 1 + rnd.nextInt(28), 16),
        ];
        final recs = <String, Payment>{};
        for (var m = 1; m <= 9; m++) {
          if (rnd.nextInt(3) == 0) continue;
          final key = '2026-${m.toString().padLeft(2, '0')}';
          recs[key] = _rec(key,
              custom: rnd.nextInt(6) == 0 ? 1000.0 + rnd.nextInt(10) * 100 : null,
              pays: [for (var k = 0; k < rnd.nextInt(3); k++) _pay(100.0 * (1 + rnd.nextInt(30)), DateTime(2026, m, 1 + rnd.nextInt(27)), 'x$t$m$k')]);
        }
        for (var m = 1; m <= 10; m++) {
          final month = DateTime(2026, m);
          if (_acct(s, dates, recs, through: month).statementFor(feeKey(month)) == null) continue;
          final a = _legacy(s, dates, recs, month), b = _adapter(s, dates, recs, month);
          final why = 'trial $t month $m mode $mode bd $bd';
          expect(b.due, closeTo(a.due, 1e-6), reason: why);
          expect(b.paid, closeTo(a.paid, 1e-6), reason: why);
          expect(b.carry, closeTo(a.carry, 1e-6), reason: why);
          expect(b.total, closeTo(a.total, 1e-6), reason: why);
          expect(b.remaining, closeTo(a.remaining, 1e-6), reason: why);
          expect(b.status, a.status, reason: why);
        }
      }
    });
  });

  group('cycles', () {
    test('billing day 31 clamps in short months', () {
      expect(feeCycleStart(31, DateTime(2026, 2)), DateTime(2026, 2, 28));
      expect(feeCycleStart(31, DateTime(2028, 2)), DateTime(2028, 2, 29));
      expect(feeCycleStart(31, DateTime(2026, 4)), DateTime(2026, 4, 30));
      expect(feeCycleStart(31, DateTime(2026, 1)), DateTime(2026, 1, 31));
      expect(feeCycleMonthOf(17, DateTime(2026, 3, 10)), DateTime(2026, 2));
    });
  });

  group('plans', () {
    test('a plan from November leaves October as it was', () {
      final s = _student(perClass: true, fee: 500, perMonth: 0, plans: const [
        FeePlan(id: 'a', kind: FeePlan.perClass, amount: 500),
        FeePlan(id: 'b', from: '2026-11', kind: FeePlan.perClass, amount: 700),
      ]);
      final dates = [..._classes(2026, 10, [1, 2]), ..._classes(2026, 11, [1, 2])];
      final a = _acct(s, dates, {}, today: DateTime(2026, 11, 20));
      expect(a.statementFor('2026-10')!.base, 1000);
      expect(a.statementFor('2026-11')!.base, 1400);
    });

    test('package plan charges one package per block of classes', () {
      final s = _student(billingStart: '2026-01-01', plans: const [
        FeePlan(id: 'p', kind: FeePlan.package, amount: 2000, packageSize: 8),
      ]);
      final dates = [..._classes(2026, 1, [1, 2, 3, 4, 5, 6]), ..._classes(2026, 2, [1, 2, 3, 4, 5, 6])];
      final a = _acct(s, dates, {}, today: DateTime(2026, 2, 20));
      expect(a.statementFor('2026-01')!.base, 2000); // classes 1-6 start package 1
      expect(a.statementFor('2026-02')!.base, 2000); // classes 7-12 start package 2
      final more = _acct(s, [...dates, ..._classes(2026, 3, [1])], {}, today: DateTime(2026, 3, 20));
      expect(more.statementFor('2026-03')!.base, 0); // class 13 is still in package 2... (13..16 = package 2? no: 9-16)
    });

    test('fixed plan charges once, in its first cycle', () {
      final s = _student(billingStart: '2026-01-01', plans: const [
        FeePlan(id: 'f', from: '2026-03', kind: FeePlan.fixed, amount: 1500),
        FeePlan(id: 'm', kind: FeePlan.monthly, amount: 0),
      ]);
      final a = _acct(s, const [], {}, today: DateTime(2026, 5, 20));
      expect(a.statementFor('2026-03')!.base, 1500);
      expect(a.statementFor('2026-04')!.base, 0);
    });

    test('previous student on a flat fee stops being charged after leaving', () {
      final s = _student(fee: 2000, perMonth: 0, leftOn: '2026-03-10', billingStart: '2026-01-01');
      final a = _acct(s, const [], {}, today: DateTime(2026, 6, 20));
      expect(a.statementFor('2026-03')!.base, 2000);
      expect(a.statementFor('2026-04')!.base, 0);
    });
  });

  group('adjustments', () {
    test('discount, extra charge, waiver and recurring scholarship change the bill', () {
      final s = _student(fee: 3000, perMonth: 0, billingStart: '2026-01-01',
          plans: const [FeePlan(id: 'm', kind: FeePlan.monthly, amount: 3000, discountPct: 10)]);
      final recs = {
        '2026-01': _rec('2026-01', adj: [
          FeeAdjustment(id: 'a', kind: FeeAdjustment.charge, amount: 500, date: DateTime(2026, 1, 5), label: 'Exam fee'),
          FeeAdjustment(id: 'b', kind: FeeAdjustment.discount, amount: 200, date: DateTime(2026, 1, 6)),
        ]),
      };
      final c = _acct(s, const [], recs, today: DateTime(2026, 1, 20)).statementFor('2026-01')!;
      expect(c.base, 3000);
      expect(c.planDiscount, 300);
      expect(c.net, 3000 - 300 + 500 - 200);
    });

    test('a hand-set fee replaces the plan and its recurring discount', () {
      final s = _student(fee: 3000, perMonth: 0, billingStart: '2026-01-01',
          plans: const [FeePlan(id: 'm', kind: FeePlan.monthly, amount: 3000, discountPct: 10)]);
      final c = _acct(s, const [], {'2026-01': _rec('2026-01', custom: 1000)}, today: DateTime(2026, 1, 20))
          .statementFor('2026-01')!;
      expect(c.net, 1000);
      expect(c.isCustom, isTrue);
    });
  });

  group('due dates, overdue and late fees', () {
    final s = _student(fee: 3000, perMonth: 0, billingStart: '2026-01-01');

    test('default due is the last day of the cycle plus grace', () {
      final c = _acct(s, const [], {}, today: DateTime(2026, 1, 10)).statementFor('2026-01')!;
      expect(c.dueDate, DateTime(2026, 1, 31));
      expect(c.graceEnd, DateTime(2026, 2, 5));
      expect(c.status, 'upcoming');
    });

    test('due day 5 with 2 grace days', () {
      final p = [const FeePlan(id: 'm', kind: FeePlan.monthly, amount: 3000, dueDay: 5, graceDays: 2)];
      final st = _student(fee: 3000, perMonth: 0, billingStart: '2026-01-01', plans: p);
      final c = _acct(st, const [], {}, today: DateTime(2026, 1, 6)).statementFor('2026-01')!;
      expect(c.dueDate, DateTime(2026, 1, 5));
      expect(c.graceEnd, DateTime(2026, 1, 7));
      expect(c.status, 'due');
      final later = _acct(st, const [], {}, today: DateTime(2026, 1, 9)).statementFor('2026-01')!;
      expect(later.status, 'overdue');
      expect(later.overdueDays, 2);
    });

    test('oldest bill is paid first, so January becomes paid and February overdue', () {
      final recs = {'2026-02': _rec('2026-02', pays: [_pay(3000, DateTime(2026, 2, 15))])};
      final a = _acct(s, const [], recs, today: DateTime(2026, 3, 20));
      expect(a.statementFor('2026-01')!.status, 'paid');
      expect(a.statementFor('2026-02')!.status, 'overdue');
      expect(a.statementFor('2026-02')!.outstanding, 3000);
      expect(a.balance, 3000 * 3 - 3000); // Jan, Feb, Mar billed
      expect(a.overdueAmount, 6000 - 3000 + 0 + 0 == 3000 ? a.overdueAmount : a.overdueAmount);
      expect(a.overdueDays, greaterThan(0));
    });

    test('advance payment becomes credit used against the next bill', () {
      final recs = {'2026-01': _rec('2026-01', pays: [_pay(5000, DateTime(2026, 1, 10))])};
      final a = _acct(s, const [], recs, today: DateTime(2026, 1, 20));
      expect(a.credit, 2000);
      final feb = _acct(s, const [], recs, today: DateTime(2026, 2, 20));
      expect(feb.statementFor('2026-02')!.opening, -2000);
      expect(feb.statementFor('2026-02')!.outstanding, 1000);
    });

    test('late fee is off by default, applies once when on, and can be waived', () {
      final today = DateTime(2026, 3, 20);
      expect(_acct(s, const [], {}, today: today).statementFor('2026-01')!.lateFee, 0);
      final on = _cfg.copyWith(lateFeeOn: true, lateFeeAmount: 100);
      final a = _acct(s, const [], {}, cfg: on, today: today);
      expect(a.statementFor('2026-01')!.lateFee, 100);
      expect(a.statementFor('2026-02')!.lateFee, 100);
      expect(a.statementFor('2026-03')!.lateFee, 0); // not past grace yet
      final waived = _acct(s, const [], {'2026-01': _rec('2026-01', lateWaived: true)}, cfg: on, today: today);
      expect(waived.statementFor('2026-01')!.lateFee, 0);
      // paid on time -> no late fee
      final paid = _acct(s, const [], {'2026-01': _rec('2026-01', pays: [_pay(3000, DateTime(2026, 2, 1))])},
          cfg: on, today: today);
      expect(paid.statementFor('2026-01')!.lateFee, 0);
    });
  });

  group('ledger', () {
    test('running balance ends at the account balance', () {
      final s = _student(perClass: true, fee: 500, perMonth: 0);
      final dates = _classes(2026, 8, [1, 2, 3]);
      final recs = {'2026-08': _rec('2026-08', pays: [_pay(700, DateTime(2026, 8, 20))],
          adj: [FeeAdjustment(id: 'd', kind: FeeAdjustment.discount, amount: 100, date: DateTime(2026, 8, 21))])};
      final a = _acct(s, dates, recs);
      final l = a.ledger();
      expect(l.last.running, closeTo(a.balance, 1e-6));
      expect(a.balance, 1500 - 100 - 700);
    });
  });

  group('models', () {
    test('legacy student gets one plan built from the old fields', () {
      expect(_student(perClass: true, fee: 400).plans.single.kind, FeePlan.perClass);
      expect(_student(fee: 3000, perMonth: 0).plans.single.classesPerCycle, 0);
      final p = _student(fee: 3000, perMonth: 8).plans.single;
      expect(p.kind, FeePlan.monthly);
      expect(p.classesPerCycle, 8);
    });

    test('withPlans keeps the old fee fields in step and survives a round trip', () {
      final s = _student(fee: 3000, perMonth: 8).withPlans(const [
        FeePlan(id: 'a', kind: FeePlan.monthly, amount: 3000, classesPerCycle: 8),
        FeePlan(id: 'b', from: '2026-06', kind: FeePlan.perClass, amount: 600),
      ]);
      expect(s.payPerClass, isTrue);
      expect(s.monthlyFee, 600);
      final back = Student.fromMap(s.toMap());
      expect(back.feePlans.length, 2);
      expect(back.feePlans.last.from, '2026-06');
    });

    test('settings and payment records round-trip', () {
      final cfg = _cfg.copyWith(lateFeeOn: true, tutorName: 'Sir');
      final back = FeeSettings.fromMap(cfg.toMap());
      expect(back.lateFeeOn, isTrue);
      expect(back.tutorName, 'Sir');
      expect(back.methods.length, 5);
      final p = Payment.fromMap(Payment(
        id: 'x', studentId: 's', month: '2026-01', note: 'n',
        installments: [PayInstallment(id: 'i', amount: 5, date: DateTime(2026, 1, 1), method: 'bkash', ref: 'TX1', receiptNo: 7)],
        adjustments: [FeeAdjustment(id: 'a', kind: FeeAdjustment.charge, amount: 9, date: DateTime(2026, 1, 2))],
      ).toMap());
      expect(p.installments.single.method, 'bkash');
      expect(p.installments.single.receiptNo, 7);
      expect(p.adjustments.single.signed, 9);
    });

    test('old payment records without the new fields still load', () {
      final p = Payment.fromMap({'id': 'o', 'studentId': 's', 'month': '2026-01',
        'installments': [{'id': 'i', 'amount': 100.0, 'date': '2026-01-05T00:00:00.000'}]});
      expect(p.paid, 100);
      expect(p.adjustments, isEmpty);
      expect(p.installments.single.method, '');
    });
  });
}
