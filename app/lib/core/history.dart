// Tuition history export / import: every student's class dates and payments as a clean,
// readable JSON file (separate from the full app backup). Safe to import more than once:
// classes and payments that already exist are skipped.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import 'data.dart';
import 'theme.dart';

const _type = 'tuition_history';

String _two(int n) => n.toString().padLeft(2, '0');
String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// Everything about every student's classes and payments, ready for JSON.
Map<String, dynamic> buildHistory(Repo repo) {
  final students = <Map<String, dynamic>>[];
  for (final s in repo.studentList) {
    final logs = repo.logsFor(s.id)..sort((a, b) => a.date.compareTo(b.date));
    final linked = {for (final l in logs) if (l.isPaid) l.payId};
    final pays = <Map<String, dynamic>>[];
    var received = 0.0;
    for (final p in repo.paymentsOf(s.id)) {
      for (final i in p.installments) {
        received += i.amount;
        if (linked.contains(i.id)) continue; // exported with its class ("paid": true)
        pays.add({
          'date': _day(i.date), 'amount': i.amount, 'month': p.month,
          if (i.classes > 0) 'classes': i.classes,
        });
      }
    }
    pays.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    students.add({
      'name': s.name,
      if (s.phone.isNotEmpty) 'phone': s.phone,
      if (s.grade.isNotEmpty) 'grade': s.grade,
      'status': s.isCurrent ? 'current' : 'previous',
      'fee': {
        'monthlyFee': s.monthlyFee, 'perClass': s.payPerClass,
        'classesPerMonth': s.classesPerMonth, 'billingDay': s.billingDay,
      },
      'summary': {
        'classes': logs.length,
        'paidClasses': logs.where((l) => l.isPaid).length,
        'received': received,
      },
      'classes': [
        for (final l in logs)
          {
            'date': _day(l.date),
            'time': '${_two(l.date.hour)}:${_two(l.date.minute)}',
            if (l.subject.isNotEmpty) 'subject': l.subject,
            if (l.topics.isNotEmpty) 'topics': l.topics,
            if (l.performance > 0) 'performance': l.performance,
            'paid': l.isPaid,
          },
      ],
      'payments': pays,
    });
  }
  return {
    '_app': 'life_tracker_pro',
    '_type': _type,
    '_version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'students': students,
  };
}

class HistoryImportResult {
  int studentsAdded = 0, classesAdded = 0, classesSkipped = 0, markedPaid = 0;
  int paymentsAdded = 0, paymentsSkipped = 0, problems = 0;
  String get summary => [
        if (studentsAdded > 0) '$studentsAdded new students',
        '$classesAdded classes added',
        if (classesSkipped > 0) '$classesSkipped already there',
        if (markedPaid > 0) '$markedPaid marked paid',
        if (paymentsAdded > 0) '$paymentsAdded payments added',
        if (paymentsSkipped > 0) '$paymentsSkipped payments already there',
        if (problems > 0) '$problems entries skipped (bad date)',
      ].join(' · ');
}

/// Throws a [FormatException] with a readable message if [data] is not a history file.
void validateHistory(Object? data) {
  if (data is! Map || data['_app'] != 'life_tracker_pro' || data['_type'] != _type) {
    throw const FormatException('This is not a Life Tracker Pro tuition history file.');
  }
  if (data['students'] is! List) {
    throw const FormatException('The file has no students list.');
  }
}

DateTime? _parseDay(Object? v, [Object? time]) {
  final d = DateTime.tryParse('${v ?? ''}');
  if (d == null) return null;
  final t = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch('${time ?? ''}');
  if (t == null) return DateTime(d.year, d.month, d.day, 16);
  return DateTime(d.year, d.month, d.day, int.parse(t.group(1)!).clamp(0, 23), int.parse(t.group(2)!).clamp(0, 59));
}

/// Adds the classes and payments from [data] to the app, skipping what already exists.
Future<HistoryImportResult> applyHistory(Repo repo, Map data) async {
  validateHistory(data);
  final res = HistoryImportResult();
  for (final raw in (data['students'] as List).whereType<Map>()) {
    final name = '${raw['name'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    final classes = (raw['classes'] is List ? raw['classes'] as List : const []).whereType<Map>().toList();
    final pays = (raw['payments'] is List ? raw['payments'] as List : const []).whereType<Map>().toList();

    Student? st;
    for (final s in repo.studentList) {
      if (s.name.trim().toLowerCase() == name.toLowerCase()) st = s;
    }
    if (st == null) {
      // A new student starts from their first class so past months list them too.
      DateTime first = DateTime.now();
      for (final c in classes) {
        final d = _parseDay(c['date']);
        if (d != null && d.isBefore(first)) first = d;
      }
      final fee = raw['fee'] is Map ? raw['fee'] as Map : const {};
      final nid = '${first.microsecondsSinceEpoch}_${newId().split('_').last}';
      st = Student.fromMap({
        'id': nid, 'name': name,
        'phone': '${raw['phone'] ?? ''}', 'grade': '${raw['grade'] ?? ''}',
        'monthlyFee': (fee['monthlyFee'] as num?)?.toDouble() ?? 0,
        'payPerClass': fee['perClass'] == true,
        'classesPerMonth': (fee['classesPerMonth'] as num?)?.toInt() ?? 0,
        'billingDay': (fee['billingDay'] as num?)?.toInt() ?? 1,
        'status': raw['status'] == 'previous' ? 'previous' : 'active',
      });
      await repo.saveStudent(st);
      res.studentsAdded++;
    }

    final have = {for (final l in repo.logsFor(st.id)) _day(l.date): l};
    for (final c in classes) {
      final d = _parseDay(c['date'], c['time']);
      if (d == null) {
        res.problems++;
        continue;
      }
      var log = have[_day(d)];
      if (log == null) {
        log = ClassLog(
          id: newId(), studentId: st.id, date: d,
          subject: '${c['subject'] ?? ''}', topics: '${c['topics'] ?? ''}',
          performance: (c['performance'] as num?)?.toInt() ?? 0,
        );
        await repo.saveLog(log);
        have[_day(d)] = log;
        res.classesAdded++;
      } else {
        res.classesSkipped++;
      }
      if (c['paid'] == true && !log.isPaid) {
        await repo.setLogPaid(st, log, true);
        res.markedPaid++;
      }
    }

    final existing = <String>{
      for (final p in repo.paymentsOf(st.id))
        for (final i in p.installments) '${_day(i.date)}|${i.amount}|${p.month}',
    };
    for (final p in pays) {
      final d = _parseDay(p['date']);
      final amount = (p['amount'] as num?)?.toDouble() ?? 0;
      if (d == null || amount <= 0) {
        res.problems++;
        continue;
      }
      final cycle = RegExp(r'^\d{4}-\d{2}$').hasMatch('${p['month']}')
          ? DateTime.parse('${p['month']}-01')
          : repo.cycleMonthOf(st, d);
      final key = '${_day(d)}|$amount|${monthKey(cycle)}';
      if (existing.contains(key)) {
        res.paymentsSkipped++;
        continue;
      }
      await repo.addPayment(st, cycle, amount, d, classes: (p['classes'] as num?)?.toInt() ?? 0);
      existing.add(key);
      res.paymentsAdded++;
    }
  }
  return res;
}

String _name() => 'tuition_history_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';
String _json(Repo repo) => const JsonEncoder.withIndent('  ').convert(buildHistory(repo));

/// Shares the history JSON (WhatsApp, Drive, email…).
Future<void> shareHistory(Repo repo) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${_name()}');
  await file.writeAsString(_json(repo));
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Tuition history'));
}

/// Saves the history JSON where the user chooses. Returns the path, or null if cancelled.
Future<String?> saveHistoryToDevice(Repo repo) => FilePicker.saveFile(
      dialogTitle: 'Save tuition history',
      fileName: _name(),
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(_json(repo))),
    );

/// Lets the user pick a history JSON and adds it to the app. Null if cancelled.
Future<HistoryImportResult?> importHistoryFile(Repo repo) async {
  final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
  final path = res?.files.single.path;
  if (path == null) return null;
  final Object? data;
  try {
    data = jsonDecode(await File(path).readAsString());
  } on FormatException {
    throw const FormatException('This file is not valid JSON.');
  }
  validateHistory(data);
  return applyHistory(repo, data as Map);
}
