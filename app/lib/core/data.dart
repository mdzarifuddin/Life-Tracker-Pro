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
    'categories', 'accounts', 'routines', 'absences', 'exams', 'jobtasks', 'jobapps', 'studylogs', 'tasks',
    'scheddone', 'thesis', 'listitems', 'settings',
  ];

  late final Box students = Hive.box('students');
  late final Box classlogs = Hive.box('classlogs');
  late final Box schedules = Hive.box('schedules');
  late final Box payments = Hive.box('payments');
  late final Box txns = Hive.box('txns');
  late final Box categories = Hive.box('categories');
  late final Box accounts = Hive.box('accounts');
  late final Box routines = Hive.box('routines');
  late final Box absences = Hive.box('absences');
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

  /// Default finance categories: name → icon key (see kCategoryIcons).
  static const _defaultExpense = {
    'Food': 'restaurant', 'Eating Out': 'fastfood', 'Bazar': 'basket',
    'Transport': 'bus', 'Rickshaw/CNG': 'rickshaw', 'Tuition Travel': 'train',
    'Fuel': 'fuel', 'House Rent': 'house', 'Electricity': 'electricity',
    'Gas': 'gas', 'Water': 'water', 'Internet': 'wifi',
    'Mobile Recharge': 'phone', 'Bills': 'bill', 'Books': 'book',
    'Stationery': 'pen', 'Education': 'school', 'Family': 'family',
    'Medical': 'medical', 'Toiletry': 'soap', 'Clothes': 'clothes',
    'Shopping': 'bag', 'Entertainment': 'movie', 'Sports': 'sports',
    'Travel': 'flight', 'Gifts': 'gift', 'Charity': 'charity',
    'Personal Care': 'salon', 'Electronics': 'devices', 'Repairs': 'repair',
    'Loan/EMI': 'loan', 'Govt Job': 'govt', 'Thesis': 'thesis',
    'Software': 'code', 'Subscriptions': 'subscription', 'Investment': 'invest',
    'Other': 'other',
  };
  static const _defaultIncome = {
    'Tuition': 'teach', 'Freelancing': 'laptop', 'Scholarship': 'award',
    'Gift': 'gift', 'Salary': 'salary', 'Business': 'store',
    'Bonus': 'bonus', 'Rent Income': 'house', 'Profit/Interest': 'invest',
    'Refund': 'refund', 'Sales': 'sell', 'Other': 'other',
  };

  void _seed() {
    // First launch seeds everything; older installs get the newer defaults once.
    if (settings.get('catsV2') != true) {
      final existing = _all(categories, Category.fromMap)
          .map((c) => '${c.type}|${c.name.toLowerCase()}')
          .toSet();
      void add(String type, Map<String, String> defaults) {
        defaults.forEach((name, icon) {
          if (existing.contains('$type|${name.toLowerCase()}')) return;
          final m = Category(id: newId(), name: name, type: type, icon: icon, isDefault: true);
          categories.put(m.id, m.toMap());
        });
      }
      add('expense', _defaultExpense);
      add('income', _defaultIncome);
      settings.put('catsV2', true);
    }
    _migrate();
  }

  /// One-time data upgrades. Safe to run again: also called after restoring a backup
  /// made by an older version of the app.
  void _migrate() {
    if (settings.get('bazarRename') != true) {
      // "Grocery" is now "Bazar": rename the category and everything using it.
      for (final c in _all(categories, Category.fromMap)) {
        if (c.name != 'Grocery') continue;
        final clash = _all(categories, Category.fromMap)
            .any((o) => o.type == c.type && o.name == 'Bazar');
        if (clash) {
          categories.delete(c.id);
        } else {
          categories.put(c.id, Category(id: c.id, name: 'Bazar', type: c.type,
              icon: c.icon, isDefault: c.isDefault).toMap());
        }
      }
      for (final t in _all(txns, Txn.fromMap).where((t) => t.category == 'Grocery')) {
        txns.put(t.id, Txn(id: t.id, type: t.type, category: 'Bazar', amount: t.amount,
            date: t.date, account: t.account, note: t.note, sourceRef: t.sourceRef).toMap());
      }
      for (final i in _all(listitems, ListItem.fromMap).where((i) => i.category == 'Grocery')) {
        listitems.put(i.id, ListItem(id: i.id, listType: i.listType, name: i.name, qty: i.qty,
            category: 'Bazar', priority: i.priority, note: i.note, estPrice: i.estPrice,
            isBought: i.isBought).toMap());
      }
      settings.put('bazarRename', true);
    }
    if (settings.get('noCashV1') != true) {
      // No built-in Cash account any more: its records become "no account" and the
      // account is removed (only when it has no sub-accounts of its own).
      if (accounts.containsKey('cash') && _all(accounts, FinAccount.fromMap).every((a) => a.parentId != 'cash')) {
        for (final t in _all(txns, Txn.fromMap).where((t) => t.account == 'cash')) {
          txns.put(t.id, Txn(id: t.id, type: t.type, category: t.category, amount: t.amount,
              date: t.date, account: '', note: t.note, sourceRef: t.sourceRef).toMap());
        }
        accounts.delete('cash');
      }
      settings.put('noCashV1', true);
    }
    // Records whose account is missing (e.g. restored from an old backup): bring back
    // the old built-in wallets that are in use, anything else becomes "no account".
    const legacy = {'bkash': ('bKash', 'phone'), 'nagad': ('Nagad', 'phone'), 'bank': ('Bank', 'bank')};
    for (final t in _all(txns, Txn.fromMap)) {
      if (t.account.isEmpty || accounts.containsKey(t.account)) continue;
      final l = legacy[t.account];
      if (l != null) {
        accounts.put(t.account, FinAccount(id: t.account, name: l.$1, icon: l.$2).toMap());
      } else {
        txns.put(t.id, Txn(id: t.id, type: t.type, category: t.category, amount: t.amount,
            date: t.date, account: '', note: t.note, sourceRef: t.sourceRef).toMap());
      }
    }
    if (settings.get('payInstV1') != true) {
      for (final p in _all(payments, Payment.fromMap)) {
        final raw = payments.get(p.id);
        // already in the new format (has its own installments list) -> leave alone
        if (raw is Map && raw.containsKey('installments')) continue;
        if (p.paidAmount <= 0 || p.installments.isEmpty) continue;
        final txn = txns.get(p.txnId);
        final date = txn == null ? DateTime.now() : Txn.fromMap(txn as Map).date;
        final fixed = Payment(
          id: p.id, studentId: p.studentId, month: p.month, amount: p.amount,
          status: p.status, paidAmount: p.paidAmount, txnId: p.txnId,
          installments: [PayInstallment(id: p.id, amount: p.paidAmount, date: date, txnId: p.txnId)]);
        payments.put(p.id, fixed.toMap());
      }
      settings.put('payInstV1', true);
    }
  }


  // ---- typed readers ----
  List<T> _all<T>(Box b, T Function(Map) f) =>
      b.values.map((e) => f(e as Map)).toList();

  List<Student> get studentList =>
      _all(students, Student.fromMap)..sort((a, b) => a.name.compareTo(b.name));
  List<Student> get currentStudents => studentList.where((s) => s.isCurrent).toList();

  /// Students for a picker: current ones, plus [keepId] if it is a previous student.
  List<Student> pickableStudents([String? keepId]) =>
      studentList.where((s) => s.isCurrent || s.id == keepId).toList();

  /// Distinct batch names in use.
  List<String> get batchNames =>
      (studentList.map((s) => s.batch).where((b) => b.isNotEmpty).toSet().toList()..sort());

  Student? student(String id) =>
      students.containsKey(id) ? Student.fromMap(students.get(id) as Map) : null;
  List<ClassLog> logsFor(String sid) =>
      _all(classlogs, ClassLog.fromMap).where((e) => e.studentId == sid).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  ClassLog? lastLog(String sid) {
    final l = logsFor(sid);
    return l.isEmpty ? null : l.first;
  }

  /// Billing cycle for [month]: from the student's billing day to the day before
  /// the next one (billing day 1 = the calendar month).
  DateTime cycleStart(Student s, DateTime month) {
    final last = DateTime(month.year, month.month + 1, 0).day; // short months
    return DateTime(month.year, month.month, s.billingDay > last ? last : s.billingDay);
  }

  DateTime cycleEnd(Student s, DateTime month) {
    final next = cycleStart(s, DateTime(month.year, month.month + 1));
    return DateTime(next.year, next.month, next.day - 1, 23, 59, 59);
  }

  /// The cycle (identified by its starting month) that contains [d].
  DateTime cycleMonthOf(Student s, DateTime d) {
    final m = DateTime(d.year, d.month);
    return d.isBefore(cycleStart(s, m)) ? DateTime(d.year, d.month - 1) : m;
  }

  /// The cycle that contains today.
  DateTime currentCycleMonth(Student s) => cycleMonthOf(s, DateTime.now());

  int classesInMonth(Student s, DateTime month) {
    final a = cycleStart(s, month), b = cycleEnd(s, month);
    return logsFor(s.id).where((l) => !l.date.isBefore(a) && !l.date.isAfter(b)).length;
  }

  /// Fee due for a month = per-class rate × classes taught (flat fee if classes/month unset).
  double dueForMonth(Student s, DateTime month) {
    final custom = paymentFor(s.id, monthKey(month))?.customDue;
    if (custom != null) return custom; // fee set by hand for this month
    if (s.payPerClass) return s.monthlyFee * classesInMonth(s, month);
    if (s.classesPerMonth <= 0) return s.monthlyFee;
    return (s.monthlyFee / s.classesPerMonth) * classesInMonth(s, month);
  }

  /// The soonest upcoming class for a student (weekly or booked for a date).
  ScheduleItem? nextClassFor(String sid) => _nextClass(sid)?.$1;
  DateTime? nextClassTime(String sid) => _nextClass(sid)?.$2;

  (ScheduleItem, DateTime)? _nextClass(String sid) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    (ScheduleItem, DateTime)? best;
    for (final s in scheduleList.where((e) => e.studentId == sid)) {
      DateTime when;
      if (s.isDated) {
        final d = s.dateOn;
        if (d == null) continue;
        when = DateTime(d.year, d.month, d.day).add(Duration(minutes: s.startMinutes));
        if (when.isBefore(now)) continue;
      } else {
        var dayDelta = (s.dayOfWeek - (now.weekday - 1)) % 7;
        if (dayDelta < 0) dayDelta += 7;
        when = today.add(Duration(days: dayDelta, minutes: s.startMinutes));
        if (when.isBefore(now)) when = when.add(const Duration(days: 7));
      }
      if (best == null || when.isBefore(best.$2)) best = (s, when);
    }
    return best;
  }

  List<Exam> examsFor(String sid) =>
      examList.where((e) => e.studentId == sid).toList();

  /// Students relevant to a given month: those created on/before that month's end.
  /// (Current/future months show all; past months hide later-added students.)
  /// Previous students still appear for months up to the one they left in.
  List<Student> studentsForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return studentList.where((s) {
      if (s.createdAt.isAfter(end)) return false;
      if (s.isCurrent) return true;
      final left = s.leftDate ?? DateTime.now();
      return !left.isBefore(start);
    }).toList();
  }

  /// Weekly schedule; classes of previous students are hidden.
  List<ScheduleItem> get scheduleList {
    final previous = studentList.where((s) => !s.isCurrent).map((s) => s.id).toSet();
    return _all(schedules, ScheduleItem.fromMap)
        .where((e) => !previous.contains(e.studentId))
        .toList();
  }
  /// Weekly (repeating) classes on a weekday (0 = Monday).
  List<ScheduleItem> scheduleForDay(int day) =>
      scheduleList.where((e) => !e.isDated && e.dayOfWeek == day).toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  /// Everything happening on a calendar date: weekly classes + ones booked for it.
  List<ScheduleItem> scheduleOnDate(DateTime d) {
    final key = dateKey(d);
    return scheduleList
        .where((e) => e.isDated ? e.onDate == key : e.dayOfWeek == d.weekday - 1)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  /// Classes booked for specific dates, today onward, in date/time order.
  List<ScheduleItem> get datedUpcoming {
    final t = DateTime.now();
    final today = dateKey(DateTime(t.year, t.month, t.day));
    return scheduleList.where((e) => e.isDated && e.onDate.compareTo(today) >= 0).toList()
      ..sort((a, b) {
        final c = a.onDate.compareTo(b.onDate);
        return c != 0 ? c : a.startMinutes.compareTo(b.startMinutes);
      });
  }

  /// Returns ids of schedule items that overlap another on the same day.
  Set<String> get conflictIds {
    final out = <String>{};
    void check(List<ScheduleItem> items) {
      for (var i = 0; i < items.length; i++) {
        for (var j = i + 1; j < items.length; j++) {
          if (items[i].startMinutes < items[j].endMinutes &&
              items[j].startMinutes < items[i].endMinutes) {
            out..add(items[i].id)..add(items[j].id);
          }
        }
      }
    }
    for (var d = 0; d < 7; d++) {
      check(scheduleForDay(d));
    }
    for (final k in datedUpcoming.map((e) => e.onDate).toSet()) {
      check(scheduleOnDate(DateTime.parse(k)));
    }
    return out;
  }

  List<Txn> get txnList =>
      _all(txns, Txn.fromMap)..sort((a, b) => b.date.compareTo(a.date));
  List<Txn> txnsForMonth(DateTime m) => txnList
      .where((t) => t.date.year == m.year && t.date.month == m.month)
      .toList();

  // ---- batch attendance ----
  List<Absence> absencesFor(String sid) =>
      _all(absences, Absence.fromMap).where((a) => a.studentId == sid).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  List<Absence> get absenceList =>
      _all(absences, Absence.fromMap)..sort((a, b) => b.date.compareTo(a.date));
  Future<void> saveAbsence(Absence a) => absences.put(a.id, a.toMap());
  Future<void> deleteAbsence(String id) => absences.delete(id);

  /// Members of a batch (current and previous), current first.
  List<Student> batchMembers(String batch) => studentList.where((s) => s.batch == batch).toList()
    ..sort((a, b) => a.isCurrent == b.isCurrent ? a.name.compareTo(b.name) : (a.isCurrent ? -1 : 1));

  /// Mark who was present/absent in [batch] on [day]. Present students get a class
  /// log (marked 'batch_' so it can be safely replaced); absent ones an absence record.
  Future<void> saveBatchAttendance(String batch, DateTime day, Set<String> absentIds,
      List<Student> members, {String subject = '', String topics = ''}) async {
    final key = dateKey(day);
    for (final s in members) {
      final logs = logsFor(s.id).where((l) => dateKey(l.date) == key).toList();
      final prior = absenceList.where((a) => a.studentId == s.id && a.date == key).toList();
      if (absentIds.contains(s.id)) {
        for (final l in logs.where((l) => l.id.startsWith('batch_'))) {
          await classlogs.delete(l.id);
        }
        if (prior.isEmpty) {
          await saveAbsence(Absence(id: newId(), studentId: s.id, date: key, batch: batch));
        }
      } else {
        for (final a in prior) {
          await deleteAbsence(a.id);
        }
        if (logs.isEmpty) {
          await saveLog(ClassLog(
            id: 'batch_${newId()}', studentId: s.id,
            date: DateTime(day.year, day.month, day.day, s.defaultTimeMinutes ~/ 60, s.defaultTimeMinutes % 60),
            subject: subject, topics: topics));
        }
      }
    }
  }

  // ---- routine pictures ----
  List<Routine> get routineList =>
      _all(routines, Routine.fromMap)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  List<Routine> routinesFor(String sid) => routineList.where((r) => r.studentId == sid).toList();
  Future<void> saveRoutine(Routine r) => routines.put(r.id, r.toMap());
  Future<void> deleteRoutine(String id) => routines.delete(id);

  // ---- finance accounts ----
  List<FinAccount> get accountList => _all(accounts, FinAccount.fromMap);
  List<FinAccount> get mainAccounts => accountList.where((a) => a.isMain).toList();
  List<FinAccount> subsOf(String id) => accountList.where((a) => a.parentId == id).toList();
  FinAccount? accountById(String id) =>
      accounts.containsKey(id) ? FinAccount.fromMap(accounts.get(id) as Map) : null;

  /// "Bank › DBBL" for a sub-account, plain name for a main one.
  String accountName(String id) {
    if (id.isEmpty) return 'No account';
    final a = accountById(id);
    if (a == null) return id;
    final p = a.isMain ? null : accountById(a.parentId);
    return p == null ? a.name : '${p.name} › ${a.name}';
  }

  /// The account itself plus all its sub-accounts.
  Set<String> accountIdsUnder(String id) =>
      {id, ...subsOf(id).map((a) => a.id)};

  double accountBalance(String id) {
    final ids = accountIdsUnder(id);
    return txnList.where((t) => ids.contains(t.account)).fold(0.0,
        (s, t) => s + (t.type == 'income' ? t.amount : -t.amount));
  }

  /// Ids of "separate" accounts (main account switched off for the total + its subs).
  Set<String> get separateAccountIds => {
        for (final m in mainAccounts.where((m) => !m.inTotal)) ...accountIdsUnder(m.id),
      };

  /// Records that count toward the All-accounts total.
  List<Txn> get totalTxns {
    final sep = separateAccountIds;
    return sep.isEmpty ? txnList : txnList.where((t) => !sep.contains(t.account)).toList();
  }

  Future<void> saveAccount(FinAccount a) => accounts.put(a.id, a.toMap());

  /// Deleting a sub-account moves its records to the main account.
  /// A main account can only go when it has no records and no sub-accounts.
  /// Returns an error message, or null on success.
  Future<String?> deleteAccount(String id) async {
    final a = accountById(id);
    if (a == null) return null;
    if (a.isMain) {
      if (subsOf(id).isNotEmpty) return 'Delete its sub-accounts first';
      if (txnList.any((t) => t.account == id)) return 'This account has records';
    } else {
      for (final t in txnList.where((t) => t.account == id)) {
        await saveTxn(Txn(
          id: t.id, type: t.type, category: t.category, amount: t.amount,
          date: t.date, account: a.parentId, note: t.note, sourceRef: t.sourceRef));
      }
    }
    await accounts.delete(id);
    return null;
  }

  List<Category> categoriesOf(String type) =>
      _all(categories, Category.fromMap).where((c) => c.type == type).toList();

  List<Exam> get examList =>
      _all(exams, Exam.fromMap)..sort((a, b) => a.date.compareTo(b.date));
  List<Exam> get upcomingExams => examList
      .where((e) => !e.done && e.date.isAfter(DateTime.now().subtract(const Duration(days: 1))))
      .toList();

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
  double incomeThisMonth() => txnsForMonth(DateTime.now()).where((t) => !separateAccountIds.contains(t.account)).toList()
      .where((t) => t.type == 'income')
      .fold(0.0, (s, t) => s + t.amount);
  double expenseThisMonth() => txnsForMonth(DateTime.now()).where((t) => !separateAccountIds.contains(t.account)).toList()
      .where((t) => t.type == 'expense')
      .fold(0.0, (s, t) => s + t.amount);
  double pendingFees() {
    double total = 0;
    for (final s in studentsForMonth(DateTime.now())) {
      total += payState(s, currentCycleMonth(s)).remaining;
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
  Future<void> deleteThesis(String id) => thesis.delete(id);
  Future<void> saveItem(ListItem i) => listitems.put(i.id, i.toMap());
  Future<void> deleteItem(String id) => listitems.delete(id);

  /// Fee position for the cycle starting in [month].
  ///  - [due]: this month's own fee
  ///  - [carry]: what was left unpaid (or paid in advance, if negative) in all earlier months
  ///  - [total]: carry + due, what is payable now
  ///  - [paid]: paid in this month's sheet
  /// Unpaid or part-paid months therefore roll into the next month automatically.
  ({double due, double paid, double carry, double total, double remaining, String status})
      payState(Student s, DateTime month) {
    final dates = logsFor(s.id).map((l) => l.date).toList();
    final pays = <String, Payment>{
      for (final p in paymentList.where((p) => p.studentId == s.id)) p.month: p,
    };
    double dueOf(DateTime m) {
      final custom = pays[monthKey(m)]?.customDue;
      if (custom != null) return custom;
      final a = cycleStart(s, m), b = cycleEnd(s, m);
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
    for (var m = cycleMonthOf(s, start); m.isBefore(month) && n < 120;
        m = DateTime(m.year, m.month + 1), n++) {
      carry += dueOf(m) - (pays[monthKey(m)]?.paid ?? 0);
    }
    final due = dueOf(month);
    final paid = pays[monthKey(month)]?.paid ?? 0;
    final total = carry + due;
    final left = total - paid;
    final remaining = left < 0 ? 0.0 : left;
    final status = remaining <= 0.5 && (paid > 0 || (due > 0 && total <= 0.5))
        ? 'paid'
        : paid > 0 ? 'partial' : 'pending';
    return (due: due, paid: paid, carry: carry, total: total, remaining: remaining, status: status);
  }

  /// Record a full or partial payment on [date]; also creates the income record.
  Future<void> addPayment(Student s, DateTime month, double amount, DateTime date,
      {String account = '', int classes = 0}) async {
    final mk = monthKey(month);
    final txn = Txn(
      id: newId(), type: 'income', category: 'Tuition', amount: amount,
      date: date, account: account, note: s.name,
      sourceRef: 'payment:${s.id}:$mk',
    );
    await saveTxn(txn);
    final old = paymentFor(s.id, mk);
    await _savePayment(Payment(
      id: old?.id ?? newId(), studentId: s.id, month: mk, amount: dueForMonth(s, month),
      installments: [
        ...?old?.installments,
        PayInstallment(id: newId(), amount: amount, date: date, txnId: txn.id, account: account, classes: classes),
      ],
      customDue: old?.customDue,
    ), s, month);
  }

  /// Remove one payment (and its income record).
  Future<void> removeInstallment(Payment p, String installmentId) async {
    final inst = p.installments.firstWhere((i) => i.id == installmentId);
    if (inst.txnId.isNotEmpty) await deleteTxn(inst.txnId);
    final s = student(p.studentId);
    final month = DateTime.parse('${p.month}-01');
    await _savePayment(Payment(
      id: p.id, studentId: p.studentId, month: p.month, amount: p.amount,
      installments: p.installments.where((i) => i.id != installmentId).toList(),
      customDue: p.customDue,
    ), s, month);
  }

  Future<void> _savePayment(Payment p, Student? s, DateTime month) {
    final paid = p.paid;
    final due = s == null ? p.amount : dueForMonth(s, month);
    final status = paid <= 0 ? 'pending' : paid >= due - 0.5 ? 'paid' : 'partial';
    return payments.put(p.id, Payment(
      id: p.id, studentId: p.studentId, month: p.month, amount: due, status: status,
      paidAmount: paid, installments: p.installments, customDue: p.customDue,
    ).toMap());
  }

  /// Set (or clear with null) the fee for one month by hand.
  Future<void> setCustomDue(Student s, DateTime month, double? due) {
    final mk = monthKey(month);
    final old = paymentFor(s.id, mk);
    return _savePayment(Payment(
      id: old?.id ?? newId(), studentId: s.id, month: mk, amount: old?.amount ?? 0,
      installments: old?.installments ?? const [], customDue: due,
    ), s, month);
  }

  // ---- reactive listenables (for AnimatedBuilder / ValueListenableBuilder) ----
  Listenable get studentsL => students.listenable();
  Listenable get logsL => classlogs.listenable();
  Listenable get schedulesL => schedules.listenable();
  Listenable get paymentsL => payments.listenable();
  Listenable get txnsL => txns.listenable();
  Listenable get categoriesL => categories.listenable();
  Listenable get accountsL => accounts.listenable();
  Listenable get routinesL => routines.listenable();
  Listenable get absencesL => absences.listenable();
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
    final out = <String, dynamic>{'_app': 'life_tracker_pro', '_version': 2};
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
    // An older backup has none of the newer upgrades applied: run them on the restored data.
    for (final f in ['bazarRename', 'noCashV1', 'payInstV1']) {
      await settings.delete(f);
    }
    _migrate();
  }

  // ---- settings ----
  /// Expense categories shown around the donut, in order (empty = automatic).
  List<String> get chartCats =>
      ((settings.get('chartCats') as List?) ?? const []).map((e) => '$e').toList();
  set chartCats(List<String> v) => settings.put('chartCats', v);

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
