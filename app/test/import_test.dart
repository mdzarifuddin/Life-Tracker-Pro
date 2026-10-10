import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker_pro/core/data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a backup made by the first version imports and is upgraded', () async {
    final dir = Directory.systemTemp.createTempSync('hv_import');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (call) async => dir.path);
    await Repo.init();
    final repo = Repo();

    final old = <String, dynamic>{
      '_app': 'life_tracker_pro',
      '_version': 1,
      'students': {
        's1': {
          'id': '1700000000000000_1', 'name': 'Rahim', 'phone': '017', 'monthlyFee': 3000.0,
          'classesPerMonth': 12, 'status': 'active', 'subjects': ['Math'],
          'guardianName': 'Karim', 'guardianPhone': '018', 'extraPhones': ['019'], 'days': ['Sat'],
        },
      },
      'txns': {
        't1': {'id': 't1', 'type': 'expense', 'category': 'Grocery', 'amount': 500.0,
            'date': '2026-09-01T10:00:00.000', 'account': 'cash', 'note': 'rice', 'sourceRef': ''},
        't2': {'id': 't2', 'type': 'income', 'category': 'Tuition', 'amount': 3000.0,
            'date': '2026-09-05T10:00:00.000', 'account': 'bkash', 'note': 'Rahim', 'sourceRef': 'payment:s1:2026-09'},
      },
      'categories': {
        'c1': {'id': 'c1', 'name': 'Grocery', 'type': 'expense', 'icon': 'basket', 'isDefault': true},
      },
      'payments': {
        // old format: one "mark paid" with no installments list
        'p1': {'id': 'p1', 'studentId': 's1', 'month': '2026-09', 'status': 'paid',
            'txnId': 't2', 'amount': 3000.0, 'paidAmount': 3000.0},
        // new format: two partial payments that must survive untouched
        'p2': {'id': 'p2', 'studentId': 's1', 'month': '2026-10', 'status': 'partial',
            'txnId': '', 'amount': 3000.0, 'paidAmount': 2000.0, 'installments': [
              {'id': 'i1', 'amount': 1200.0, 'date': '2026-10-02T00:00:00.000', 'txnId': '', 'account': ''},
              {'id': 'i2', 'amount': 800.0, 'date': '2026-10-09T00:00:00.000', 'txnId': '', 'account': ''},
            ]},
      },
      'exams': {
        'e1': {'id': 'e1', 'studentId': 's1', 'title': 'Model Test', 'subject': 'Math',
            'syllabus': 'Algebra, Geometry; Trigonometry', 'examType': 'Monthly Test',
            'date': '2026-10-20T10:00:00.000', 'done': false, 'questionReady': false, 'durationMin': 60},
      },
      'settings': {'pinHash': 'abc', 'catsV2': true},
    };
    await repo.importAll(old);

    // student: legacy guardian fields become the first guardian
    final s = repo.studentList.single;
    expect(s.name, 'Rahim');
    expect(s.guardians.single.name, 'Karim');
    expect(s.guardianPhone, '018');
    expect(s.extraPhones, ['019']);
    expect(s.billingDay, 1);

    // Grocery -> Bazar everywhere
    expect(repo.categoriesOf('expense').map((c) => c.name), contains('Bazar'));
    expect(repo.categoriesOf('expense').map((c) => c.name), isNot(contains('Grocery')));
    expect(repo.txnList.firstWhere((t) => t.id == 't1').category, 'Bazar');

    // Cash is gone ("no account"); bKash is brought back because a record uses it
    expect(repo.txnList.firstWhere((t) => t.id == 't1').account, '');
    expect(repo.accountById('bkash')?.name, 'bKash');
    expect(repo.accountById('cash'), isNull);

    // old payment -> one installment dated like its income record; new one untouched
    final p1 = repo.paymentFor('s1', '2026-09')!;
    expect(p1.installments.length, 1);
    expect(p1.paid, 3000);
    expect(p1.installments.single.date, DateTime.parse('2026-09-05T10:00:00.000'));
    final p2 = repo.paymentFor('s1', '2026-10')!;
    expect(p2.installments.map((i) => i.amount), [1200.0, 800.0]);

    // old exam: subject + syllabus text become a subject with a topic checklist
    final e = repo.examList.single;
    expect(e.subject, 'Math');
    expect(e.subjects.single.topics.map((t) => t.title), ['Algebra', 'Geometry', 'Trigonometry']);

    // settings survive
    expect(repo.pinHash, 'abc');

    // restoring the same data again changes nothing (migrations are repeatable)
    // through real JSON, exactly like exporting to a file and restoring it
    await repo.importAll(jsonDecode(jsonEncode(repo.exportAll())) as Map);
    expect(repo.paymentFor('s1', '2026-10')!.installments.length, 2);
    expect(repo.paymentFor('s1', '2026-09')!.installments.length, 1);
    expect(repo.txnList.length, 2);
  });
}
