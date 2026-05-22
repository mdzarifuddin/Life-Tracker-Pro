import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models.dart';
import 'theme.dart';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}';

/// Single repository over Hive boxes. Boxes are listenable for reactive UI.
class Repo {
  static const _boxes = [
    'students', 'classlogs', 'schedules', 'payments', 'txns',
    'categories', 'exams', 'jobtasks', 'jobapps', 'studylogs', 'tasks',
    'scheddone', 'thesis', 'listitems', 'settings',
  ];

  late final Box students = Hive.box('students');
  late final Box classlogs = Hive.box('classlogs');
  late final Box schedules = Hive.box('schedules');
  late final Box payments = Hive.box('payments');
  late final Box txns = Hive.box('txns');
  late final Box categories = Hive.box('categories');
  late final Box exams = Hive.box('exams');
  late final Box jobtasks = Hive.box('jobtasks');
  late final Box jobapps = Hive.box('jobapps');
  late final Box studylogs = Hive.box('studylogs');
  late final Box tasks = Hive.box('tasks');
  late final Box scheddone = Hive.box('scheddone');
  late final Box thesis = Hive.box('thesis');
  late final Box listitems = Hive.box('listitems');
  late final Box settings = Hive.box('settings');

  static Future<void> init() async {
    await Hive.initFlutter();
    for (final b in _boxes) {
      await Hive.openBox(b);
    }
    Repo()._seed();
  }

  void _seed() {
    if (categories.isEmpty) {
      const expense = [
        'Food', 'Transport', 'Internet', 'Mobile Recharge', 'Books',
        'Tuition Travel', 'Family', 'Medical', 'Shopping', 'Entertainment',
        'Govt Job', 'Thesis', 'Software', 'Subscriptions', 'Investment',
        'Grocery', 'Other',
      ];
      const income = [
        'Tuition', 'Freelancing', 'Scholarship', 'Gift', 'Salary',
        'Business', 'Other',
      ];
      for (final c in expense) {
        final m = Category(id: newId(), name: c, type: 'expense', isDefault: true);
        categories.put(m.id, m.toMap());
      }
      for (final c in income) {
        final m = Category(id: newId(), name: c, type: 'income', isDefault: true);
        categories.put(m.id, m.toMap());
      }
    }
    if (thesis.isEmpty) {
      const stages = [
        'Literature Review', 'Methodology', 'Implementation',
        'Results', 'Writing', 'Defense',
      ];
      for (var i = 0; i < stages.length; i++) {
        final s = ThesisStage(id: newId(), stage: stages[i], order: i);
        thesis.put(s.id, s.toMap());
      }
    }
  }

  // ---- typed readers ----
  List<T> _all<T>(Box b, T Function(Map) f) =>
      b.values.map((e) => f(e as Map)).toList();

  List<Student> get studentList =>
      _all(students, Student.fromMap)..sort((a, b) => a.name.compareTo(b.name));
  Student? student(String id) =>
      students.containsKey(id) ? Student.fromMap(students.get(id) as Map) : null;
  List<ClassLog> logsFor(String sid) =>
      _all(classlogs, ClassLog.fromMap).where((e) => e.studentId == sid).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  ClassLog? lastLog(String sid) {
    final l = logsFor(sid);
    return l.isEmpty ? null : l.first;
  }

  int classesInMonth(String sid, DateTime month) => logsFor(sid)
      .where((l) => l.date.year == month.year && l.date.month == month.month)
      .length;
  int classesThisMonth(String sid) => classesInMonth(sid, DateTime.now());

  /// Fee due for a month = per-class rate × classes taught (flat fee if classes/month unset).
  double dueForMonth(Student s, DateTime month) {
    if (s.classesPerMonth <= 0) return s.monthlyFee;
    return (s.monthlyFee / s.classesPerMonth) * classesInMonth(s.id, month);
  }

  /// The soonest upcoming weekly class for a student (relative to now).
  ScheduleItem? nextClassFor(String sid) {
    final items = scheduleList.where((e) => e.studentId == sid).toList();
    if (items.isEmpty) return null;
    final now = DateTime.now();
    final nowDay = now.weekday - 1;
    final nowMin = now.hour * 60 + now.minute;
    ScheduleItem? best;
    var bestDelta = 1 << 30;
    for (final s in items) {
      var dayDelta = (s.dayOfWeek - nowDay) % 7;
      if (dayDelta < 0) dayDelta += 7;
      var delta = dayDelta * 1440 + s.startMinutes - nowMin;
      if (delta < 0) delta += 7 * 1440;
      if (delta < bestDelta) {
        bestDelta = delta;
        best = s;
      }
    }
    return best;
  }

  List<Exam> examsFor(String sid) =>
      examList.where((e) => e.studentId == sid).toList();

  /// Students relevant to a given month: those created on/before that month's end.
  /// (Current/future months show all; past months hide later-added students.)
  List<Student> studentsForMonth(DateTime month) {
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return studentList.where((s) => !s.createdAt.isAfter(end)).toList();
  }

  List<ScheduleItem> get scheduleList => _all(schedules, ScheduleItem.fromMap);
  List<ScheduleItem> scheduleForDay(int day) =>
      scheduleList.where((e) => e.dayOfWeek == day).toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  /// Returns ids of schedule items that overlap another on the same day.
  Set<String> get conflictIds {
    final out = <String>{};
    for (var d = 0; d < 7; d++) {
      final items = scheduleForDay(d);
      for (var i = 0; i < items.length; i++) {
        for (var j = i + 1; j < items.length; j++) {
          if (items[i].startMinutes < items[j].endMinutes &&
              items[j].startMinutes < items[i].endMinutes) {
            out..add(items[i].id)..add(items[j].id);
          }
        }
      }
    }
    return out;
  }

  List<Txn> get txnList =>
      _all(txns, Txn.fromMap)..sort((a, b) => b.date.compareTo(a.date));
  List<Txn> txnsForMonth(DateTime m) => txnList
      .where((t) => t.date.year == m.year && t.date.month == m.month)
      .toList();
  List<Category> categoriesOf(String type) =>
      _all(categories, Category.fromMap).where((c) => c.type == type).toList();

  List<Exam> get examList =>
      _all(exams, Exam.fromMap)..sort((a, b) => a.date.compareTo(b.date));
  List<Exam> get upcomingExams =>
      examList.where((e) => e.date.isAfter(DateTime.now().subtract(const Duration(days: 1)))).toList();

  List<JobTask> get jobTaskList => _all(jobtasks, JobTask.fromMap);

  List<JobApplication> get jobAppList => _all(jobapps, JobApplication.fromMap)
    ..sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return (a.examDate ?? a.deadline ?? DateTime(2100))
          .compareTo(b.examDate ?? b.deadline ?? DateTime(2100));
    });
  JobApplication? get nextJobExam {
    final now = DateTime.now().subtract(const Duration(days: 1));
    final upcoming = jobAppList
        .where((a) => !a.done && a.examDate != null && a.examDate!.isAfter(now))
        .toList();
    return upcoming.isEmpty ? null : upcoming.first;
  }

  List<StudyLog> get studyLogs =>
      _all(studylogs, StudyLog.fromMap)..sort((a, b) => b.date.compareTo(a.date));

  /// Tasks ordered: not-done first, then high priority, then by due date.
  List<PersonalTask> get taskList => _all(tasks, PersonalTask.fromMap)
    ..sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      if (a.priorityRank != b.priorityRank) return a.priorityRank.compareTo(b.priorityRank);
      return a.due.compareTo(b.due);
    });
  List<PersonalTask> get todayTasks {
    final now = DateTime.now();
    final endToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return taskList.where((t) => !t.done && !t.due.isAfter(endToday)).toList();
  }
  Future<void> saveTask(PersonalTask t) => tasks.put(t.id, t.toMap());
  Future<void> deleteTask(String id) => tasks.delete(id);

  /// Per-day completion of a recurring schedule item (auto-resets each day).
  bool isSchedDone(String id, DateTime d) => scheddone.get('$id|${dateKey(d)}') == true;
  Future<void> toggleSchedDone(String id, DateTime d) async {
    final k = '$id|${dateKey(d)}';
    if (scheddone.get(k) == true) {
      await scheddone.delete(k);
    } else {
      await scheddone.put(k, true);
    }
  }

  /// (mcq, minutes) studied between [start] and [end] inclusive.
  (int, int) studyTotals(DateTime start, DateTime end) {
    var mcq = 0, mins = 0;
    for (final s in studyLogs) {
      if (!s.date.isBefore(start) && !s.date.isAfter(end)) {
        mcq += s.mcq;
        mins += s.minutes;
      }
    }
    return (mcq, mins);
  }
  List<ThesisStage> get thesisStages =>
      _all(thesis, ThesisStage.fromMap)..sort((a, b) => a.order.compareTo(b.order));
  int get thesisProgress {
    final s = thesisStages;
    if (s.isEmpty) return 0;
    return (s.map((e) => e.progress).reduce((a, b) => a + b) / s.length).round();
  }

  List<ListItem> itemsOf(String type) =>
      _all(listitems, ListItem.fromMap).where((e) => e.listType == type).toList();

  List<Payment> get paymentList => _all(payments, Payment.fromMap);
  Payment? paymentFor(String sid, String month) {
    try {
      return paymentList.firstWhere((p) => p.studentId == sid && p.month == month);
    } catch (_) {
      return null;
    }
  }

  // ---- dashboard aggregates ----
  double incomeThisMonth() => txnsForMonth(DateTime.now())
      .where((t) => t.type == 'income')
      .fold(0.0, (s, t) => s + t.amount);
  double expenseThisMonth() => txnsForMonth(DateTime.now())
      .where((t) => t.type == 'expense')
      .fold(0.0, (s, t) => s + t.amount);
  double pendingFees() {
    final now = DateTime.now();
    final m = monthKey(now);
    double total = 0;
    for (final s in studentList) {
      final p = paymentFor(s.id, m);
      if (p?.status != 'paid') total += dueForMonth(s, now);
    }
    return total;
  }

  // ---- writers ----
  Future<void> saveStudent(Student s) => students.put(s.id, s.toMap());
  Future<void> deleteStudent(String id) => students.delete(id);
  Future<void> saveLog(ClassLog l) => classlogs.put(l.id, l.toMap());
  Future<void> saveSchedule(ScheduleItem s) => schedules.put(s.id, s.toMap());
  Future<void> deleteSchedule(String id) => schedules.delete(id);
  Future<void> saveTxn(Txn t) => txns.put(t.id, t.toMap());
  Future<void> deleteTxn(String id) => txns.delete(id);
  Future<void> saveCategory(Category c) => categories.put(c.id, c.toMap());
  Future<void> saveExam(Exam e) => exams.put(e.id, e.toMap());
  Future<void> deleteExam(String id) => exams.delete(id);
  Future<void> saveJobTask(JobTask t) => jobtasks.put(t.id, t.toMap());
  Future<void> saveJobApp(JobApplication a) => jobapps.put(a.id, a.toMap());
  Future<void> deleteJobApp(String id) => jobapps.delete(id);
  Future<void> saveStudyLog(StudyLog s) => studylogs.put(s.id, s.toMap());
  Future<void> deleteStudyLog(String id) => studylogs.delete(id);
  Future<void> saveThesis(ThesisStage s) => thesis.put(s.id, s.toMap());
  Future<void> saveItem(ListItem i) => listitems.put(i.id, i.toMap());
  Future<void> deleteItem(String id) => listitems.delete(id);

  /// Mark a student's fee as paid for [month] and auto-create the income txn.
  Future<void> markFeePaid(Student s, DateTime month) async {
    final mk = monthKey(month);
    final amount = dueForMonth(s, month);
    final txn = Txn(
      id: newId(), type: 'income', category: 'Tuition', amount: amount,
      date: DateTime.now(), account: 'cash', note: s.name,
      sourceRef: 'payment:${s.id}:$mk',
    );
    await saveTxn(txn);
    final p = Payment(
      id: paymentFor(s.id, mk)?.id ?? newId(), studentId: s.id, month: mk,
      amount: amount, status: 'paid', paidAmount: amount, txnId: txn.id,
    );
    await payments.put(p.id, p.toMap());
  }

  /// Reverse a payment: delete linked income txn + reset status.
  Future<void> markFeeUnpaid(Payment p) async {
    if (p.txnId.isNotEmpty) await deleteTxn(p.txnId);
    await payments.put(p.id, Payment(
      id: p.id, studentId: p.studentId, month: p.month, amount: p.amount,
      status: 'pending',
    ).toMap());
  }

  // ---- reactive listenables (for AnimatedBuilder / ValueListenableBuilder) ----
  Listenable get studentsL => students.listenable();
  Listenable get logsL => classlogs.listenable();
  Listenable get schedulesL => schedules.listenable();
  Listenable get paymentsL => payments.listenable();
  Listenable get txnsL => txns.listenable();
  Listenable get categoriesL => categories.listenable();
  Listenable get examsL => exams.listenable();
  Listenable get jobtasksL => jobtasks.listenable();
  Listenable get jobappsL => jobapps.listenable();
  Listenable get studylogsL => studylogs.listenable();
  Listenable get tasksL => tasks.listenable();
  Listenable get scheddoneL => scheddone.listenable();
  Listenable get thesisL => thesis.listenable();
  Listenable get listitemsL => listitems.listenable();
  Listenable get settingsL => settings.listenable();

  // ---- backup / restore ----
  Map<String, dynamic> exportAll() {
    final out = <String, dynamic>{'_app': 'life_tracker_pro', '_version': 1};
    for (final name in _boxes) {
      final box = Hive.box(name);
      final m = <String, dynamic>{};
      for (final key in box.keys) {
        m['$key'] = box.get(key);
      }
      out[name] = m;
    }
    return out;
  }

  Future<void> importAll(Map data) async {
    for (final name in _boxes) {
      if (!data.containsKey(name)) continue;
      final m = data[name];
      if (m is! Map) continue;
      final box = Hive.box(name);
      await box.clear();
      for (final entry in m.entries) {
        final v = entry.value;
        await box.put(entry.key, v is Map ? Map<String, dynamic>.from(v) : v);
      }
    }
  }

  // ---- settings ----
  String? get pinHash => settings.get('pinHash') as String?;
  set pinHash(String? v) => settings.put('pinHash', v);
  ThemeMode get themeMode {
    switch (settings.get('themeMode') as String?) {
      case 'light': return ThemeMode.light;
      case 'system': return ThemeMode.system;
      default: return ThemeMode.dark;
    }
  }

  set themeMode(ThemeMode m) => settings.put('themeMode', m.name);
}
