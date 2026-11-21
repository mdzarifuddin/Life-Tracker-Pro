// Life Tracker Pro data models — plain classes with Map (de)serialization for Hive.
// See docs/DATABASE.md for the field reference.

double _d(dynamic v) => (v == null) ? 0.0 : (v as num).toDouble();
int _i(dynamic v) => (v == null) ? 0 : (v as num).toInt();
String _s(dynamic v) => v?.toString() ?? '';
List<String> _ls(dynamic v) =>
    (v is List) ? v.map((e) => e.toString()).toList() : <String>[];

/// A day a student missed a class (batch attendance).
class Absence {
  final String id, studentId, date, batch; // date = 'yyyy-MM-dd'
  Absence({required this.id, required this.studentId, required this.date, this.batch = ''});
  Map<String, dynamic> toMap() =>
      {'id': id, 'studentId': studentId, 'date': date, 'batch': batch};
  factory Absence.fromMap(Map m) => Absence(
        id: _s(m['id']), studentId: _s(m['studentId']), date: _s(m['date']), batch: _s(m['batch']));
}

/// A weekly time a student is NOT available (school, private tutor, etc.).
class BusyTime {
  final String id, studentId, label;
  final List<int> days; // 0 = Monday .. 6 = Sunday
  final int startMinutes, endMinutes;
  BusyTime({required this.id, required this.studentId, this.label = '',
      this.days = const [], required this.startMinutes, required this.endMinutes});
  Map<String, dynamic> toMap() => {'id': id, 'studentId': studentId, 'label': label,
        'days': days, 'startMinutes': startMinutes, 'endMinutes': endMinutes};
  factory BusyTime.fromMap(Map m) => BusyTime(
        id: _s(m['id']), studentId: _s(m['studentId']), label: _s(m['label']),
        days: m['days'] is List ? (m['days'] as List).map(_i).toList() : const [],
        startMinutes: _i(m['startMinutes']), endMinutes: _i(m['endMinutes']));
}

/// A routine picture (class/exam timetable…) stored as base64.
class Routine {
  final String id, title, image;
  final String studentId; // '' = general; otherwise also shown in that student's profile
  final DateTime createdAt;
  Routine({required this.id, required this.title, required this.image, required this.createdAt,
      this.studentId = ''});
  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'image': image,
        'studentId': studentId, 'createdAt': createdAt.toIso8601String()};
  factory Routine.fromMap(Map m) => Routine(
        id: _s(m['id']), title: _s(m['title']), image: _s(m['image']), studentId: _s(m['studentId']),
        createdAt: DateTime.tryParse(_s(m['createdAt'])) ?? DateTime.now());
}

/// A parent/guardian contact of a student.
class Guardian {
  final String name, phone, relation;
  const Guardian({this.name = '', this.phone = '', this.relation = ''});
  Map<String, dynamic> toMap() => {'name': name, 'phone': phone, 'relation': relation};
  factory Guardian.fromMap(Map m) =>
      Guardian(name: _s(m['name']), phone: _s(m['phone']), relation: _s(m['relation']));
  bool get isEmpty => name.isEmpty && phone.isEmpty;
}

class Student {
  final String id, name, phone, grade, institution, batch, status;
  final double monthlyFee;
  final int classesPerMonth;
  final int defaultTimeMinutes;
  final int colorValue; // 0 = auto
  final List<String> subjects, weakSubjects, extraPhones, days;
  final String photo;
  final List<Guardian> guardians; // any number of guardians
  final String leftOn; // ISO date the student stopped ('' while current)
  /// Day of month a billing cycle starts (1 = calendar month; 17 = 17th to 16th).
  final int billingDay;
  /// The date picked in the form as "month starts on" ('' = calendar months).
  /// Its day-of-month is [billingDay]; the first cycle begins on this date.
  final String billingStart;
  /// Per-day system: [monthlyFee] is the fee for ONE class and the month's
  /// bill is that rate × classes taught (no fixed classes per month).
  final bool payPerClass;
  /// Fee plan versions (empty = the single plan implied by monthlyFee / classesPerMonth / payPerClass).
  final List<FeePlan> feePlans;

  Student({
    required this.id,
    required this.name,
    this.photo = '',
    this.phone = '',
    this.grade = '',
    this.institution = '',
    this.batch = '',
    this.status = 'active',
    this.monthlyFee = 0,
    this.classesPerMonth = 0,
    this.defaultTimeMinutes = 960, // 4:00 PM
    this.colorValue = 0,
    this.subjects = const [],
    this.weakSubjects = const [],
    this.extraPhones = const [],
    this.days = const [],
    this.guardians = const [],
    this.leftOn = '',
    this.billingDay = 1,
    this.billingStart = '',
    this.payPerClass = false,
    this.feePlans = const [],
  });

  DateTime? get billingStartDate => billingStart.isEmpty ? null : DateTime.tryParse(billingStart);

  /// Fee for a single class.
  double get perClassFee => payPerClass
      ? monthlyFee
      : (classesPerMonth > 0 ? monthlyFee / classesPerMonth : monthlyFee);

  /// The fee plan versions in effect, oldest first. A student saved before fee plans
  /// existed gets one plan built from the old fee fields.
  List<FeePlan> get plans {
    if (feePlans.isNotEmpty) return feePlans;
    final FeePlan p;
    if (payPerClass) {
      p = FeePlan(id: 'legacy', kind: FeePlan.perClass, amount: monthlyFee);
    } else {
      p = FeePlan(id: 'legacy', kind: FeePlan.monthly, amount: monthlyFee,
          classesPerCycle: classesPerMonth > 0 ? classesPerMonth : 0);
    }
    return [p];
  }

  /// This student with new plan versions; the old fee fields follow the latest one so
  /// cards and lists that still read them stay correct.
  Student withPlans(List<FeePlan> next) {
    final sorted = [...next]..sort((a, b) => a.from.compareTo(b.from));
    final last = sorted.isEmpty ? null : sorted.last;
    final m = {...toMap(), 'feePlans': sorted.map((p) => p.toMap()).toList()};
    if (last != null) {
      m['monthlyFee'] = last.kind == FeePlan.package ? last.perClassRate : last.amount;
      m['payPerClass'] = last.kind == FeePlan.perClass || last.kind == FeePlan.package;
      m['classesPerMonth'] = last.kind == FeePlan.monthly ? last.classesPerCycle : 0;
    }
    return Student.fromMap(m);
  }

  /// First guardian (kept for older code/backups).
  String get guardianName => guardians.isEmpty ? '' : guardians.first.name;
  String get guardianPhone => guardians.isEmpty ? '' : guardians.first.phone;

  /// 'active' = currently studying, 'previous' = stopped.
  bool get isCurrent => status != 'previous';
  DateTime? get leftDate => leftOn.isEmpty ? null : DateTime.tryParse(leftOn);

  Student withCurrent(bool current, {DateTime? on}) => Student.fromMap({
        ...toMap(),
        'status': current ? 'active' : 'previous',
        'leftOn': current ? '' : (on ?? DateTime.now()).toIso8601String().substring(0, 10),
      });

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'phone': phone, 'grade': grade,
        'institution': institution, 'batch': batch, 'status': status,
        'monthlyFee': monthlyFee, 'classesPerMonth': classesPerMonth,
        'defaultTimeMinutes': defaultTimeMinutes, 'colorValue': colorValue,
        'subjects': subjects, 'weakSubjects': weakSubjects, 'extraPhones': extraPhones,
        'days': days,
        'guardianName': guardianName, 'guardianPhone': guardianPhone, 'photo': photo,
        'guardians': guardians.map((g) => g.toMap()).toList(),
        'leftOn': leftOn, 'billingDay': billingDay, 'billingStart': billingStart, 'payPerClass': payPerClass,
        if (feePlans.isNotEmpty) 'feePlans': feePlans.map((p) => p.toMap()).toList(),
      };

  factory Student.fromMap(Map m) => Student(
        id: _s(m['id']), name: _s(m['name']), phone: _s(m['phone']),
        grade: _s(m['grade']), institution: _s(m['institution']),
        batch: _s(m['batch']), status: _s(m['status']).isEmpty ? 'active' : _s(m['status']),
        monthlyFee: _d(m['monthlyFee']), classesPerMonth: _i(m['classesPerMonth']),
        defaultTimeMinutes: m['defaultTimeMinutes'] == null ? 960 : _i(m['defaultTimeMinutes']),
        colorValue: _i(m['colorValue']),
        subjects: _ls(m['subjects']), weakSubjects: _ls(m['weakSubjects']),
        extraPhones: _ls(m['extraPhones']), days: _ls(m['days']),
        guardians: m['guardians'] is List
            ? (m['guardians'] as List).whereType<Map>().map(Guardian.fromMap).toList()
            : (_s(m['guardianName']).isEmpty && _s(m['guardianPhone']).isEmpty
                ? const <Guardian>[]
                : [Guardian(name: _s(m['guardianName']), phone: _s(m['guardianPhone']))]),
        photo: _s(m['photo']),
        leftOn: _s(m['leftOn']),
        payPerClass: m['payPerClass'] == true,
        feePlans: m['feePlans'] is List
            ? (m['feePlans'] as List).whereType<Map>().map(FeePlan.fromMap).toList()
            : const [],
        billingStart: _s(m['billingStart']),
        billingDay: (_i(m['billingDay']) < 1 || _i(m['billingDay']) > 31) ? 1 : _i(m['billingDay']),
      );

  /// Creation time decoded from the id (newId() = microseconds_random).
  DateTime get createdAt {
    final head = int.tryParse(id.split('_').first);
    return head == null ? DateTime(2000) : DateTime.fromMicrosecondsSinceEpoch(head);
  }
}

class ClassLog {
  final String id, studentId, topics, homework, remarks, nextPlan, learned, notDone, subject;
  final DateTime date;
  final int performance;

  ClassLog({
    required this.id,
    required this.studentId,
    required this.date,
    this.subject = '',
    this.topics = '',
    this.homework = '',
    this.remarks = '',
    this.nextPlan = '',
    this.learned = '',
    this.notDone = '',
    this.performance = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'studentId': studentId, 'date': date.toIso8601String(),
        'subject': subject, 'topics': topics, 'homework': homework, 'remarks': remarks,
        'nextPlan': nextPlan, 'learned': learned, 'notDone': notDone,
        'performance': performance,
      };

  factory ClassLog.fromMap(Map m) => ClassLog(
        id: _s(m['id']), studentId: _s(m['studentId']),
        date: DateTime.tryParse(_s(m['date'])) ?? DateTime.now(),
        subject: _s(m['subject']),
        topics: _s(m['topics']), homework: _s(m['homework']),
        remarks: _s(m['remarks']), nextPlan: _s(m['nextPlan']),
        learned: _s(m['learned']), notDone: _s(m['notDone']),
        performance: _i(m['performance']),
      );
}

class ScheduleItem {
  final String id, studentId, location, title;
  final int dayOfWeek, startMinutes, durationMin, reminderMin;
  /// 'yyyy-MM-dd' for a one-off class booked in advance; '' = repeats every week.
  final String onDate;

  ScheduleItem({
    required this.id,
    required this.studentId,
    required this.dayOfWeek,
    required this.startMinutes,
    this.durationMin = 60,
    this.location = '',
    this.title = '',
    this.reminderMin = 30,
    this.onDate = '',
  });

  bool get isDated => onDate.isNotEmpty;
  DateTime? get dateOn => isDated ? DateTime.tryParse(onDate) : null;

  Map<String, dynamic> toMap() => {
        'id': id, 'studentId': studentId, 'dayOfWeek': dayOfWeek, 'onDate': onDate,
        'startMinutes': startMinutes, 'durationMin': durationMin,
        'location': location, 'title': title, 'reminderMin': reminderMin,
      };

  factory ScheduleItem.fromMap(Map m) => ScheduleItem(
        id: _s(m['id']), studentId: _s(m['studentId']),
        dayOfWeek: _i(m['dayOfWeek']), startMinutes: _i(m['startMinutes']),
        durationMin: _i(m['durationMin']) == 0 ? 60 : _i(m['durationMin']),
        location: _s(m['location']), title: _s(m['title']), reminderMin: _i(m['reminderMin']),
        onDate: _s(m['onDate']),
      );

  bool get isPersonal => studentId.isEmpty;
  int get endMinutes => startMinutes + durationMin;
}

/// One version of how a student is charged. A student can have several, each
/// starting from a month, so changing a fee never rewrites earlier months.
class FeePlan {
  static const monthly = 'monthly', perClass = 'perClass', package = 'package', fixed = 'fixed';

  final String id, from, kind, label;
  /// 'yyyy-MM' of the first cycle this version applies to ('' = from the beginning).
  /// monthly: the monthly fee · perClass: rate per class · package: price of one
  /// package · fixed: a one-time amount.
  final double amount, discountPct, discountFlat;
  /// monthly only: > 0 = fee is pro-rated by classes taught (fee / n x classes), 0 = flat.
  final int classesPerCycle;
  /// package only: classes in one package.
  final int packageSize;
  /// 0 = last day of the cycle, 1..31 = that day of the cycle, null = use the setting.
  final int? dueDay;
  final int? graceDays;
  /// null = use the setting, 0 = no late fee, > 0 = flat late fee per overdue cycle.
  final double? lateFee;

  const FeePlan({
    required this.id,
    this.from = '',
    this.kind = monthly,
    this.label = '',
    this.amount = 0,
    this.classesPerCycle = 0,
    this.packageSize = 0,
    this.discountPct = 0,
    this.discountFlat = 0,
    this.dueDay,
    this.graceDays,
    this.lateFee,
  });

  FeePlan copyWith({
    String? id, String? from, String? kind, String? label, double? amount,
    int? classesPerCycle, int? packageSize, double? discountPct, double? discountFlat,
    int? dueDay, int? graceDays, double? lateFee,
    bool clearDueDay = false, bool clearGrace = false, bool clearLate = false,
  }) =>
      FeePlan(
        id: id ?? this.id, from: from ?? this.from, kind: kind ?? this.kind,
        label: label ?? this.label, amount: amount ?? this.amount,
        classesPerCycle: classesPerCycle ?? this.classesPerCycle,
        packageSize: packageSize ?? this.packageSize,
        discountPct: discountPct ?? this.discountPct,
        discountFlat: discountFlat ?? this.discountFlat,
        dueDay: clearDueDay ? null : (dueDay ?? this.dueDay),
        graceDays: clearGrace ? null : (graceDays ?? this.graceDays),
        lateFee: clearLate ? null : (lateFee ?? this.lateFee),
      );

  /// Per-class equivalent, for cards and quick previews.
  double get perClassRate {
    switch (kind) {
      case perClass: return amount;
      case package: return packageSize > 0 ? amount / packageSize : amount;
      case monthly: return classesPerCycle > 0 ? amount / classesPerCycle : amount;
      default: return amount;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id, 'from': from, 'kind': kind, 'label': label, 'amount': amount,
        'classesPerCycle': classesPerCycle, 'packageSize': packageSize,
        'discountPct': discountPct, 'discountFlat': discountFlat,
        'dueDay': dueDay, 'graceDays': graceDays, 'lateFee': lateFee,
      };

  factory FeePlan.fromMap(Map m) {
    final k = _s(m['kind']);
    return FeePlan(
      id: _s(m['id']), from: _s(m['from']),
      kind: const [monthly, perClass, package, fixed].contains(k) ? k : monthly,
      label: _s(m['label']), amount: _d(m['amount']),
      classesPerCycle: _i(m['classesPerCycle']), packageSize: _i(m['packageSize']),
      discountPct: _d(m['discountPct']), discountFlat: _d(m['discountFlat']),
      dueDay: m['dueDay'] == null ? null : _i(m['dueDay']),
      graceDays: m['graceDays'] == null ? null : _i(m['graceDays']),
      lateFee: m['lateFee'] == null ? null : _d(m['lateFee']),
    );
  }
}

/// A one-off change to one cycle's bill: a discount / waiver, or an extra charge.
class FeeAdjustment {
  static const discount = 'discount', charge = 'charge', waiver = 'waiver';
  final String id, kind, label, note;
  final double amount; // always positive; [kind] says which way it goes
  final DateTime date;
  const FeeAdjustment({required this.id, required this.kind, required this.amount,
      required this.date, this.label = '', this.note = ''});

  /// Effect on the bill: + for a charge, − for a discount or waiver.
  double get signed => kind == charge ? amount : -amount;

  Map<String, dynamic> toMap() => {'id': id, 'kind': kind, 'label': label, 'note': note,
        'amount': amount, 'date': date.toIso8601String()};
  factory FeeAdjustment.fromMap(Map m) => FeeAdjustment(
        id: _s(m['id']),
        kind: const [discount, charge, waiver].contains(_s(m['kind'])) ? _s(m['kind']) : charge,
        label: _s(m['label']), note: _s(m['note']), amount: _d(m['amount']).abs(),
        date: DateTime.tryParse(_s(m['date'])) ?? DateTime.now());
}

/// How a payment was made (Cash, bKash…). Fully editable in the fee settings.
class PayMethod {
  final String id, name, icon;
  final bool needsRef, enabled;
  const PayMethod({required this.id, required this.name, this.icon = 'cash',
      this.needsRef = false, this.enabled = true});
  PayMethod copyWith({String? name, String? icon, bool? needsRef, bool? enabled}) => PayMethod(
      id: id, name: name ?? this.name, icon: icon ?? this.icon,
      needsRef: needsRef ?? this.needsRef, enabled: enabled ?? this.enabled);
  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'icon': icon, 'needsRef': needsRef, 'enabled': enabled};
  factory PayMethod.fromMap(Map m) => PayMethod(
      id: _s(m['id']), name: _s(m['name']), icon: _s(m['icon']).isEmpty ? 'cash' : _s(m['icon']),
      needsRef: m['needsRef'] == true, enabled: m['enabled'] != false);
}

/// Everything about fees the user can customise. Stored as one map in the settings box.
class FeeSettings {
  static const defaultReminder =
      'Assalamu alaikum {guardian}, {student}\'s tuition fee of {amount} for {month} '
      'is due{overdue}. Please pay when convenient. Thank you. – {tutor}';

  final int defaultDueDay, defaultGraceDays, dueSoonDays;
  final bool lateFeeOn;
  final double lateFeeAmount;
  final List<PayMethod> methods;
  final String defaultMethod;
  final List<String> chargeTypes;
  final List<FeePlan> templates;
  final String tutorName, receiptHeader, receiptFooter, reminderTemplate;

  const FeeSettings({
    this.defaultDueDay = 0,
    this.defaultGraceDays = 5,
    this.dueSoonDays = 7,
    this.lateFeeOn = false,
    this.lateFeeAmount = 100,
    this.methods = defaultMethods,
    this.defaultMethod = 'cash',
    this.chargeTypes = const ['Admission', 'Exam fee', 'Books', 'Materials', 'Transport'],
    this.templates = const [],
    this.tutorName = '',
    this.receiptHeader = '',
    this.receiptFooter = 'Thank you!',
    this.reminderTemplate = defaultReminder,
  });

  static const defaultMethods = <PayMethod>[
    PayMethod(id: 'cash', name: 'Cash', icon: 'cash'),
    PayMethod(id: 'bkash', name: 'bKash', icon: 'phone', needsRef: true),
    PayMethod(id: 'nagad', name: 'Nagad', icon: 'phone', needsRef: true),
    PayMethod(id: 'rocket', name: 'Rocket', icon: 'phone', needsRef: true),
    PayMethod(id: 'bank', name: 'Bank', icon: 'bank', needsRef: true),
  ];

  List<PayMethod> get activeMethods => methods.where((m) => m.enabled).toList();
  PayMethod? methodById(String id) {
    for (final m in methods) {
      if (m.id == id) return m;
    }
    return null;
  }

  FeeSettings copyWith({
    int? defaultDueDay, int? defaultGraceDays, int? dueSoonDays, bool? lateFeeOn,
    double? lateFeeAmount, List<PayMethod>? methods, String? defaultMethod,
    List<String>? chargeTypes, List<FeePlan>? templates, String? tutorName,
    String? receiptHeader, String? receiptFooter, String? reminderTemplate,
  }) =>
      FeeSettings(
        defaultDueDay: defaultDueDay ?? this.defaultDueDay,
        defaultGraceDays: defaultGraceDays ?? this.defaultGraceDays,
        dueSoonDays: dueSoonDays ?? this.dueSoonDays,
        lateFeeOn: lateFeeOn ?? this.lateFeeOn,
        lateFeeAmount: lateFeeAmount ?? this.lateFeeAmount,
        methods: methods ?? this.methods,
        defaultMethod: defaultMethod ?? this.defaultMethod,
        chargeTypes: chargeTypes ?? this.chargeTypes,
        templates: templates ?? this.templates,
        tutorName: tutorName ?? this.tutorName,
        receiptHeader: receiptHeader ?? this.receiptHeader,
        receiptFooter: receiptFooter ?? this.receiptFooter,
        reminderTemplate: reminderTemplate ?? this.reminderTemplate,
      );

  Map<String, dynamic> toMap() => {
        'v': 1,
        'defaultDueDay': defaultDueDay, 'defaultGraceDays': defaultGraceDays,
        'dueSoonDays': dueSoonDays, 'lateFeeOn': lateFeeOn, 'lateFeeAmount': lateFeeAmount,
        'methods': methods.map((m) => m.toMap()).toList(), 'defaultMethod': defaultMethod,
        'chargeTypes': chargeTypes, 'templates': templates.map((t) => t.toMap()).toList(),
        'tutorName': tutorName, 'receiptHeader': receiptHeader,
        'receiptFooter': receiptFooter, 'reminderTemplate': reminderTemplate,
      };

  factory FeeSettings.fromMap(Map m) {
    const d = FeeSettings();
    final methods = m['methods'] is List
        ? (m['methods'] as List).whereType<Map>().map(PayMethod.fromMap).toList()
        : <PayMethod>[];
    return FeeSettings(
      defaultDueDay: m['defaultDueDay'] == null ? d.defaultDueDay : _i(m['defaultDueDay']).clamp(0, 31),
      defaultGraceDays: m['defaultGraceDays'] == null ? d.defaultGraceDays : _i(m['defaultGraceDays']).clamp(0, 90),
      dueSoonDays: m['dueSoonDays'] == null ? d.dueSoonDays : _i(m['dueSoonDays']).clamp(0, 60),
      lateFeeOn: m['lateFeeOn'] == true,
      lateFeeAmount: m['lateFeeAmount'] == null ? d.lateFeeAmount : _d(m['lateFeeAmount']),
      methods: methods.isEmpty ? defaultMethods : methods,
      defaultMethod: _s(m['defaultMethod']).isEmpty ? d.defaultMethod : _s(m['defaultMethod']),
      chargeTypes: m['chargeTypes'] is List ? _ls(m['chargeTypes']) : d.chargeTypes,
      templates: m['templates'] is List
          ? (m['templates'] as List).whereType<Map>().map(FeePlan.fromMap).toList()
          : const [],
      tutorName: _s(m['tutorName']), receiptHeader: _s(m['receiptHeader']),
      receiptFooter: m['receiptFooter'] == null ? d.receiptFooter : _s(m['receiptFooter']),
      reminderTemplate: _s(m['reminderTemplate']).isEmpty ? d.reminderTemplate : _s(m['reminderTemplate']),
    );
  }
}

/// One payment toward a month's fee (full or partial), with its own date.
class PayInstallment {
  final String id, txnId, account;
  final double amount;
  final DateTime date;
  final int classes; // classes this payment covers (0 = just an amount)
  /// [PayMethod] id ('' = not recorded), reference (bKash trx id…), free note, receipt number.
  final String method, ref, note;
  final int receiptNo; // 0 = made before receipts existed
  PayInstallment({required this.id, required this.amount, required this.date,
      this.txnId = '', this.account = '', this.classes = 0,
      this.method = '', this.ref = '', this.note = '', this.receiptNo = 0});

  Map<String, dynamic> toMap() => {
        'id': id, 'amount': amount, 'date': date.toIso8601String(),
        'txnId': txnId, 'account': account, 'classes': classes,
        'method': method, 'ref': ref, 'note': note, 'receiptNo': receiptNo,
      };
  factory PayInstallment.fromMap(Map m) => PayInstallment(
        id: _s(m['id']), amount: _d(m['amount']),
        date: DateTime.tryParse(_s(m['date'])) ?? DateTime.now(),
        txnId: _s(m['txnId']), account: _s(m['account']),
        classes: _i(m['classes']),
        method: _s(m['method']), ref: _s(m['ref']), note: _s(m['note']),
        receiptNo: _i(m['receiptNo']),
      );
}

class Payment {
  final String id, studentId, month, status, txnId;
  final double amount, paidAmount;
  final List<PayInstallment> installments;
  /// Fee set by hand for this one month (null = worked out from classes / monthly fee).
  final double? customDue;
  /// One-off discounts / waivers / extra charges for this cycle.
  final List<FeeAdjustment> adjustments;
  /// The late fee of this cycle is forgiven.
  final bool lateFeeWaived;
  /// ISO timestamps of reminders sent for this cycle.
  final List<String> reminded;
  final String note;

  Payment({
    required this.id,
    required this.studentId,
    required this.month,
    this.amount = 0,
    this.status = 'pending',
    this.paidAmount = 0,
    this.txnId = '',
    this.installments = const [],
    this.customDue,
    this.adjustments = const [],
    this.lateFeeWaived = false,
    this.reminded = const [],
    this.note = '',
  });

  /// Sum of all installments.
  double get paid => installments.fold(0.0, (s, i) => s + i.amount);

  Payment copyWith({
    double? amount, String? status, double? paidAmount,
    List<PayInstallment>? installments, double? customDue, bool clearCustomDue = false,
    List<FeeAdjustment>? adjustments, bool? lateFeeWaived, List<String>? reminded, String? note,
  }) =>
      Payment(
        id: id, studentId: studentId, month: month, txnId: txnId,
        amount: amount ?? this.amount, status: status ?? this.status,
        paidAmount: paidAmount ?? this.paidAmount,
        installments: installments ?? this.installments,
        customDue: clearCustomDue ? null : (customDue ?? this.customDue),
        adjustments: adjustments ?? this.adjustments,
        lateFeeWaived: lateFeeWaived ?? this.lateFeeWaived,
        reminded: reminded ?? this.reminded,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'studentId': studentId, 'month': month, 'status': status,
        'txnId': txnId, 'amount': amount, 'paidAmount': paidAmount,
        'installments': installments.map((i) => i.toMap()).toList(),
        'customDue': customDue,
        'adjustments': adjustments.map((a) => a.toMap()).toList(),
        'lateFeeWaived': lateFeeWaived, 'reminded': reminded, 'note': note,
      };

  factory Payment.fromMap(Map m) {
    final raw = m['installments'];
    var inst = raw is List
        ? raw.whereType<Map>().map(PayInstallment.fromMap).toList()
        : <PayInstallment>[];
    // Legacy single "mark paid" record.
    if (raw is! List && _d(m['paidAmount']) > 0) {
      inst = [PayInstallment(id: _s(m['id']), amount: _d(m['paidAmount']),
          date: DateTime.now(), txnId: _s(m['txnId']))];
    }
    return Payment(
      id: _s(m['id']), studentId: _s(m['studentId']), month: _s(m['month']),
      status: _s(m['status']).isEmpty ? 'pending' : _s(m['status']),
      txnId: _s(m['txnId']), amount: _d(m['amount']),
      paidAmount: _d(m['paidAmount']), installments: inst,
      customDue: m['customDue'] == null ? null : _d(m['customDue']),
      adjustments: m['adjustments'] is List
          ? (m['adjustments'] as List).whereType<Map>().map(FeeAdjustment.fromMap).toList()
          : const [],
      lateFeeWaived: m['lateFeeWaived'] == true,
      reminded: _ls(m['reminded']),
      note: _s(m['note']),
    );
  }
}

class Txn {
  final String id, type, category, account, note, sourceRef;
  final double amount;
  final DateTime date;

  Txn({
    required this.id,
    required this.type, // income | expense
    required this.category,
    required this.amount,
    required this.date,
    this.account = '',
    this.note = '',
    this.sourceRef = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'type': type, 'category': category, 'account': account,
        'note': note, 'sourceRef': sourceRef, 'amount': amount,
        'date': date.toIso8601String(),
      };

  factory Txn.fromMap(Map m) => Txn(
        id: _s(m['id']), type: _s(m['type']), category: _s(m['category']),
        account: _s(m['account']),
        note: _s(m['note']), sourceRef: _s(m['sourceRef']),
        amount: _d(m['amount']),
        date: DateTime.tryParse(_s(m['date'])) ?? DateTime.now(),
      );
}

/// A finance account. Main accounts have an empty [parentId]; sub-accounts
/// point at their main account (one level deep).
class FinAccount {
  final String id, name, icon, parentId;
  /// false = a separate account: its records are NOT added to the All-accounts total.
  final bool inTotal;
  FinAccount({required this.id, required this.name, this.icon = 'wallet', this.parentId = '', this.inTotal = true});

  bool get isMain => parentId.isEmpty;

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'icon': icon, 'parentId': parentId, 'inTotal': inTotal};
  factory FinAccount.fromMap(Map m) => FinAccount(
        inTotal: m['inTotal'] != false,
        id: _s(m['id']), name: _s(m['name']),
        icon: _s(m['icon']).isEmpty ? 'wallet' : _s(m['icon']),
        parentId: _s(m['parentId']),
      );
}

class Category {
  final String id, name, type;
  final String icon; // key in the built-in icon set ('' = pick by name)
  final bool isDefault;
  Category({required this.id, required this.name, required this.type, this.icon = '', this.isDefault = false});

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'type': type, 'icon': icon, 'isDefault': isDefault};
  factory Category.fromMap(Map m) => Category(
        id: _s(m['id']), name: _s(m['name']), type: _s(m['type']),
        icon: _s(m['icon']),
        isDefault: m['isDefault'] == true,
      );
}

/// One syllabus item of an exam subject, tick it off when covered.
class SyllabusTopic {
  final String title;
  final bool done;
  const SyllabusTopic(this.title, {this.done = false});
  Map<String, dynamic> toMap() => {'title': title, 'done': done};
  factory SyllabusTopic.fromMap(Map m) => SyllabusTopic(_s(m['title']), done: m['done'] == true);
  SyllabusTopic toggled() => SyllabusTopic(title, done: !done);
}

/// A subject in an exam together with its syllabus checklist.
class ExamSubject {
  final String name;
  final List<SyllabusTopic> topics;
  const ExamSubject(this.name, [this.topics = const []]);

  int get doneCount => topics.where((t) => t.done).length;
  int get leftCount => topics.length - doneCount;

  Map<String, dynamic> toMap() => {'name': name, 'topics': topics.map((t) => t.toMap()).toList()};
  factory ExamSubject.fromMap(Map m) => ExamSubject(
        _s(m['name']),
        m['topics'] is List
            ? (m['topics'] as List).whereType<Map>().map(SyllabusTopic.fromMap).toList()
            : const [],
      );
}

class Exam {
  final String id, studentId, title, examType, syllabus;
  final List<ExamSubject> subjects;
  final bool questionReady, done;
  final int durationMin;
  final DateTime date;
  Exam({
    required this.id,
    this.studentId = '',
    required this.title,
    this.subjects = const [],
    this.examType = '',
    this.syllabus = '', // free-form notes
    this.questionReady = false,
    this.done = false,
    this.durationMin = 0,
    required this.date,
  });

  /// "Math + Physics".
  String get subject => subjects.map((s) => s.name).join(' + ');
  int get topicCount => subjects.fold(0, (a, s) => a + s.topics.length);
  int get topicsDone => subjects.fold(0, (a, s) => a + s.doneCount);

  Map<String, dynamic> toMap() => {
        'id': id, 'studentId': studentId, 'title': title,
        'subjects': subjects.map((s) => s.toMap()).toList(),
        'examType': examType, 'syllabus': syllabus, 'questionReady': questionReady,
        'done': done, 'durationMin': durationMin, 'date': date.toIso8601String(),
      };
  factory Exam.fromMap(Map m) {
    List<ExamSubject> subs;
    var notes = _s(m['syllabus']);
    if (m['subjects'] is List) {
      subs = (m['subjects'] as List).whereType<Map>().map(ExamSubject.fromMap).toList();
    } else if (_s(m['subject']).isNotEmpty) {
      // older single-subject exam: its syllabus text becomes the topic list
      final topics = notes
          .split(RegExp(r'[,;\n]'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .map(SyllabusTopic.new)
          .toList();
      subs = [ExamSubject(_s(m['subject']), topics)];
      notes = '';
    } else {
      subs = const [];
    }
    return Exam(
      id: _s(m['id']), studentId: _s(m['studentId']), title: _s(m['title']),
      subjects: subs, examType: _s(m['examType']), syllabus: notes,
      questionReady: m['questionReady'] == true,
      done: m['done'] == true, durationMin: _i(m['durationMin']),
      date: DateTime.tryParse(_s(m['date'])) ?? DateTime.now(),
    );
  }

  Exam copyWith({bool? done, List<ExamSubject>? subjects}) => Exam(
        id: id, studentId: studentId, title: title, subjects: subjects ?? this.subjects,
        examType: examType, syllabus: syllabus, questionReady: questionReady,
        done: done ?? this.done, durationMin: durationMin, date: date);

  /// Tick / untick one syllabus topic.
  Exam withTopicToggled(int subjectIndex, int topicIndex) => copyWith(subjects: [
        for (var i = 0; i < subjects.length; i++)
          i != subjectIndex
              ? subjects[i]
              : ExamSubject(subjects[i].name, [
                  for (var j = 0; j < subjects[i].topics.length; j++)
                    j == topicIndex ? subjects[i].topics[j].toggled() : subjects[i].topics[j],
                ]),
      ]);
}

class JobTask {
  final String id, subject;
  final int target, completed;
  JobTask({required this.id, required this.subject, this.target = 0, this.completed = 0});

  Map<String, dynamic> toMap() =>
      {'id': id, 'subject': subject, 'target': target, 'completed': completed};
  factory JobTask.fromMap(Map m) => JobTask(
        id: _s(m['id']), subject: _s(m['subject']),
        target: _i(m['target']), completed: _i(m['completed']),
      );
}

class PersonalTask {
  final String id, title, note, priority;
  final DateTime due;
  final bool done;
  PersonalTask({
    required this.id,
    required this.title,
    required this.due,
    this.note = '',
    this.priority = 'med',
    this.done = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'title': title, 'note': note, 'priority': priority,
        'due': due.toIso8601String(), 'done': done,
      };
  factory PersonalTask.fromMap(Map m) => PersonalTask(
        id: _s(m['id']), title: _s(m['title']), note: _s(m['note']),
        priority: _s(m['priority']).isEmpty ? 'med' : _s(m['priority']),
        due: DateTime.tryParse(_s(m['due'])) ?? DateTime.now(),
        done: m['done'] == true,
      );

  int get priorityRank => priority == 'high' ? 0 : priority == 'med' ? 1 : 2;

  PersonalTask copyWith({bool? done}) => PersonalTask(
        id: id, title: title, due: due, note: note, priority: priority,
        done: done ?? this.done);
}

class StudyLog {
  final String id, subject, note;
  final DateTime date;
  final int mcq, minutes;
  StudyLog({
    required this.id,
    required this.date,
    this.subject = '',
    this.mcq = 0,
    this.minutes = 0,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'date': date.toIso8601String(), 'subject': subject,
        'mcq': mcq, 'minutes': minutes, 'note': note,
      };
  factory StudyLog.fromMap(Map m) => StudyLog(
        id: _s(m['id']),
        date: DateTime.tryParse(_s(m['date'])) ?? DateTime.now(),
        subject: _s(m['subject']), mcq: _i(m['mcq']), minutes: _i(m['minutes']),
        note: _s(m['note']),
      );
}

class JobApplication {
  final String id, title, organization, status;
  final DateTime? deadline, examDate;
  final bool done;
  JobApplication({
    required this.id,
    required this.title,
    this.organization = '',
    this.status = 'To Apply',
    this.deadline,
    this.examDate,
    this.done = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'title': title, 'organization': organization, 'status': status,
        'deadline': deadline?.toIso8601String() ?? '',
        'examDate': examDate?.toIso8601String() ?? '',
        'done': done,
      };
  factory JobApplication.fromMap(Map m) => JobApplication(
        id: _s(m['id']), title: _s(m['title']), organization: _s(m['organization']),
        status: _s(m['status']).isEmpty ? 'To Apply' : _s(m['status']),
        deadline: DateTime.tryParse(_s(m['deadline'])),
        examDate: DateTime.tryParse(_s(m['examDate'])),
        done: m['done'] == true,
      );

  JobApplication copyWith({bool? done}) => JobApplication(
        id: id, title: title, organization: organization, status: status,
        deadline: deadline, examDate: examDate, done: done ?? this.done);
}

class ThesisStage {
  final String id, stage, notes;
  final int progress, order;
  ThesisStage({required this.id, required this.stage, this.progress = 0, this.notes = '', this.order = 0});

  Map<String, dynamic> toMap() =>
      {'id': id, 'stage': stage, 'progress': progress, 'notes': notes, 'order': order};
  factory ThesisStage.fromMap(Map m) => ThesisStage(
        id: _s(m['id']), stage: _s(m['stage']), progress: _i(m['progress']),
        notes: _s(m['notes']), order: _i(m['order']),
      );
}

class ListItem {
  final String id, listType, name, qty, category, priority, note;
  final double estPrice;
  final bool isBought;
  ListItem({
    required this.id,
    required this.listType, // bazar | future
    required this.name,
    this.qty = '',
    this.category = '',
    this.priority = 'med',
    this.note = '',
    this.estPrice = 0,
    this.isBought = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'listType': listType, 'name': name, 'qty': qty,
        'category': category, 'priority': priority, 'note': note,
        'estPrice': estPrice, 'isBought': isBought,
      };
  factory ListItem.fromMap(Map m) => ListItem(
        id: _s(m['id']), listType: _s(m['listType']), name: _s(m['name']),
        qty: _s(m['qty']), category: _s(m['category']),
        priority: _s(m['priority']).isEmpty ? 'med' : _s(m['priority']),
        note: _s(m['note']), estPrice: _d(m['estPrice']), isBought: m['isBought'] == true,
      );

  int get priorityRank => priority == 'high' ? 0 : priority == 'med' ? 1 : 2;

  ListItem copyWith({bool? isBought}) => ListItem(
        id: id, listType: listType, name: name, qty: qty, category: category,
        priority: priority, note: note, estPrice: estPrice, isBought: isBought ?? this.isBought,
      );
}
