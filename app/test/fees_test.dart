import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker_pro/core/data.dart';
import 'package:life_tracker_pro/core/history.dart';
import 'package:life_tracker_pro/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Repo repo;

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('hv_fees');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    await Repo.init();
    repo = Repo();
  });

  Student student({int billingDay = 1, double fee = 3000, int perMonth = 10, bool perClass = false}) {
    final id = '${DateTime(2026, 1, 1).microsecondsSinceEpoch}_${newId()}';
    return Student(id: id, name: 'T', monthlyFee: fee, classesPerMonth: perMonth,
        billingDay: billingDay, payPerClass: perClass);
  }

  Future<void> teach(Student s, DateTime d) =>
      repo.saveLog(ClassLog(id: newId(), studentId: s.id, date: d));

  test('marking classes paid records one payment per class date and can be undone', () async {
    final s = student(perClass: true, fee: 500);
    await repo.saveStudent(s);
    final logs = <ClassLog>[
      for (final d in [3, 5, 8, 20]) ClassLog(id: newId(), studentId: s.id, date: DateTime(2026, 3, d, 16)),
    ];
    for (final l in logs) {
      await repo.saveLog(l);
    }
    // "payment done till 10 March": the 3rd, 5th and 8th.
    final till = DateTime(2026, 3, 10, 23, 59, 59);
    final fresh = repo.logsFor(s.id);
    await repo.setLogsPaid(s, fresh.where((l) => !l.date.isAfter(till)), true);
    expect(repo.logsFor(s.id).where((l) => l.isPaid).length, 3);
    final st = repo.payState(s, DateTime(2026, 3));
    expect(st.paid, 1500);
    expect(st.remaining, 500); // the 20th is still unpaid
    expect(repo.txnList.where((t) => t.sourceRef.contains(s.id)), isEmpty); // never touches Finance
    // undo one
    final one = repo.logsFor(s.id).firstWhere((l) => l.isPaid);
    await repo.setLogPaid(s, one, false);
    expect(repo.payState(s, DateTime(2026, 3)).paid, 1000);
    expect(repo.logsFor(s.id).where((l) => l.isPaid).length, 2);
  });

  test('tuition history exports to JSON and imports back without duplicating', () async {
    final base = student(perClass: true, fee: 400);
    final s = Student(id: base.id, name: 'Hist Kid', monthlyFee: 400, payPerClass: true);
    await repo.saveStudent(s);
    final a = ClassLog(id: newId(), studentId: s.id, date: DateTime(2025, 5, 3, 16), topics: 'Algebra');
    final b = ClassLog(id: newId(), studentId: s.id, date: DateTime(2025, 5, 6, 16));
    await repo.saveLog(a);
    await repo.saveLog(b);
    await repo.setLogPaid(s, a, true);
    await repo.addPayment(s, DateTime(2025, 5), 300, DateTime(2025, 5, 20));
    final json = buildHistory(repo);
    final me = (json['students'] as List).cast<Map>().firstWhere((x) => x['name'] == 'Hist Kid');
    expect((me['classes'] as List).first['paid'], isTrue);
    expect((me['payments'] as List).length, 1); // the per-class payment is not listed twice
    expect(me['summary']['received'], 700);

    // Same file again: nothing is added twice.
    final again = await applyHistory(repo, {...json, 'students': [me]});
    expect(again.classesAdded, 0);
    expect(again.paymentsAdded, 0);

    // A fresh student from the file gets the classes, the paid flag and the payment.
    final copy = {
      ...json,
      'students': [
        {...me, 'name': 'Imported Kid'},
      ],
    };
    final res = await applyHistory(repo, copy);
    expect(res.studentsAdded, 1);
    expect(res.classesAdded, 2);
    expect(res.markedPaid, 1);
    expect(res.paymentsAdded, 1);
    final kid = repo.studentList.firstWhere((x) => x.name == 'Imported Kid');
    expect(kid.createdAt.year, 2025); // shows up in past months
    expect(repo.payState(kid, DateTime(2025, 5)).paid, 700);
    expect(() => validateHistory({'x': 1}), throwsFormatException);
  });

  test('billing day 31 falls back to the last day of short months', () {
    final s = student(billingDay: 31);
    expect(repo.cycleStart(s, DateTime(2026, 2)), DateTime(2026, 2, 28));
    expect(repo.cycleStart(s, DateTime(2026, 4)), DateTime(2026, 4, 30));
    expect(repo.cycleStart(s, DateTime(2026, 1)), DateTime(2026, 1, 31));
  });

  test('unpaid fee carries into the next month, advance payment reduces it', () async {
    final s = student(perClass: true, fee: 500);
    await repo.saveStudent(s);
    await teach(s, DateTime(2026, 1, 5));
    await teach(s, DateTime(2026, 1, 6));
    await teach(s, DateTime(2026, 2, 3));
    var jan = repo.payState(s, DateTime(2026, 1));
    expect(jan.due, 1000);
    expect(jan.status, 'pending');
    await repo.addPayment(s, DateTime(2026, 1), 400, DateTime(2026, 1, 20));
    jan = repo.payState(s, DateTime(2026, 1));
    expect(jan.status, 'partial');
    expect(jan.remaining, 600);
    final feb = repo.payState(s, DateTime(2026, 2));
    expect(feb.carry, 600);
    expect(feb.total, 1100);
    await repo.addPayment(s, DateTime(2026, 2), 1100, DateTime(2026, 2, 20));
    expect(repo.payState(s, DateTime(2026, 2)).status, 'paid');
  });

  test('undoing a payment restores the due amount', () async {
    final s = student(perClass: true, fee: 100);
    await repo.saveStudent(s);
    await teach(s, DateTime(2026, 3, 2));
    final id = await repo.addPayment(s, DateTime(2026, 3), 100, DateTime(2026, 3, 3));
    expect(repo.payState(s, DateTime(2026, 3)).status, 'paid');
    await repo.removeInstallment(repo.paymentFor(s.id, '2026-03')!, id);
    expect(repo.payState(s, DateTime(2026, 3)).remaining, 100);
  });

  test('busy time clash detection', () async {
    final s = student();
    await repo.saveBusy(BusyTime(id: newId(), studentId: s.id, label: 'School',
        days: [0, 1], startMinutes: 9 * 60, endMinutes: 14 * 60));
    expect(repo.busyClash(s.id, 0, 13 * 60, 14 * 60), isNotNull);
    expect(repo.busyClash(s.id, 0, 14 * 60, 15 * 60), isNull); // touching is fine
    expect(repo.busyClash(s.id, 2, 10 * 60, 11 * 60), isNull); // other day
  });

  test('backup export/import round trip; pin kept out; bad files rejected', () async {
    repo.setPin('1234');
    final s = student();
    await repo.saveStudent(s);
    await repo.saveBusy(BusyTime(id: 'b1', studentId: s.id, days: [3], startMinutes: 600, endMinutes: 700));
    final data = repo.exportAll();
    expect((data['settings'] as Map).containsKey('pinHash'), isFalse);
    expect((data['busytimes'] as Map).containsKey('b1'), isTrue);
    expect(() => Repo.validateBackup({'students': {}}), throwsFormatException);
    expect(() => Repo.validateBackup({'_app': 'life_tracker_pro'}), throwsFormatException);
    await repo.busytimes.clear();
    await repo.importAll(data);
    expect(repo.busyFor(s.id).single.id, 'b1');
    expect(repo.checkPin('1234'), isTrue); // PIN survives a restore
    expect(repo.checkPin('0000'), isFalse);
  });
}
