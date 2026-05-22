// Mentora data models — plain classes with Map (de)serialization for Hive.
// See docs/DATABASE.md for the field reference.

double _d(dynamic v) => (v == null) ? 0.0 : (v as num).toDouble();
int _i(dynamic v) => (v == null) ? 0 : (v as num).toInt();
String _s(dynamic v) => v?.toString() ?? '';
List<String> _ls(dynamic v) =>
    (v is List) ? v.map((e) => e.toString()).toList() : <String>[];

class Student {
  final String id, name, phone, grade, institution, batch, status;
  final double monthlyFee;
  final int classesPerMonth;
  final int defaultTimeMinutes;
  final int colorValue; // 0 = auto
  final List<String> subjects, weakSubjects, extraPhones;
  final String guardianName, guardianPhone, photo;

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
    this.guardianName = '',
    this.guardianPhone = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'phone': phone, 'grade': grade,
        'institution': institution, 'batch': batch, 'status': status,
        'monthlyFee': monthlyFee, 'classesPerMonth': classesPerMonth,
        'defaultTimeMinutes': defaultTimeMinutes, 'colorValue': colorValue,
        'subjects': subjects, 'weakSubjects': weakSubjects, 'extraPhones': extraPhones,
        'guardianName': guardianName, 'guardianPhone': guardianPhone, 'photo': photo,
      };

  factory Student.fromMap(Map m) => Student(
        id: _s(m['id']), name: _s(m['name']), phone: _s(m['phone']),
        grade: _s(m['grade']), institution: _s(m['institution']),
        batch: _s(m['batch']), status: _s(m['status']).isEmpty ? 'active' : _s(m['status']),
        monthlyFee: _d(m['monthlyFee']), classesPerMonth: _i(m['classesPerMonth']),
        defaultTimeMinutes: m['defaultTimeMinutes'] == null ? 960 : _i(m['defaultTimeMinutes']),
        colorValue: _i(m['colorValue']),
        subjects: _ls(m['subjects']), weakSubjects: _ls(m['weakSubjects']),
        extraPhones: _ls(m['extraPhones']),
        guardianName: _s(m['guardianName']), guardianPhone: _s(m['guardianPhone']),
        photo: _s(m['photo']),
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

  ScheduleItem({
    required this.id,
    required this.studentId,
    required this.dayOfWeek,
    required this.startMinutes,
    this.durationMin = 60,
    this.location = '',
    this.title = '',
    this.reminderMin = 30,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'studentId': studentId, 'dayOfWeek': dayOfWeek,
        'startMinutes': startMinutes, 'durationMin': durationMin,
        'location': location, 'title': title, 'reminderMin': reminderMin,
      };

  factory ScheduleItem.fromMap(Map m) => ScheduleItem(
        id: _s(m['id']), studentId: _s(m['studentId']),
        dayOfWeek: _i(m['dayOfWeek']), startMinutes: _i(m['startMinutes']),
        durationMin: _i(m['durationMin']) == 0 ? 60 : _i(m['durationMin']),
        location: _s(m['location']), title: _s(m['title']), reminderMin: _i(m['reminderMin']),
      );

  bool get isPersonal => studentId.isEmpty;
  int get endMinutes => startMinutes + durationMin;
}

class Payment {
  final String id, studentId, month, status, txnId;
  final double amount, paidAmount;

  Payment({
    required this.id,
    required this.studentId,
    required this.month,
    this.amount = 0,
    this.status = 'pending',
    this.paidAmount = 0,
    this.txnId = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'studentId': studentId, 'month': month, 'status': status,
        'txnId': txnId, 'amount': amount, 'paidAmount': paidAmount,
      };

  factory Payment.fromMap(Map m) => Payment(
        id: _s(m['id']), studentId: _s(m['studentId']), month: _s(m['month']),
        status: _s(m['status']).isEmpty ? 'pending' : _s(m['status']),
        txnId: _s(m['txnId']), amount: _d(m['amount']),
        paidAmount: _d(m['paidAmount']),
      );
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
    this.account = 'cash',
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
        account: _s(m['account']).isEmpty ? 'cash' : _s(m['account']),
        note: _s(m['note']), sourceRef: _s(m['sourceRef']),
        amount: _d(m['amount']),
        date: DateTime.tryParse(_s(m['date'])) ?? DateTime.now(),
      );
}

class Category {
  final String id, name, type;
  final bool isDefault;
  Category({required this.id, required this.name, required this.type, this.isDefault = false});

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'type': type, 'isDefault': isDefault};
  factory Category.fromMap(Map m) => Category(
        id: _s(m['id']), name: _s(m['name']), type: _s(m['type']),
        isDefault: m['isDefault'] == true,
      );
}

class Exam {
  final String id, studentId, title, subject, examType, syllabus;
  final bool questionReady;
  final DateTime date;
  Exam({
    required this.id,
    this.studentId = '',
    required this.title,
    this.subject = '',
    this.examType = '',
    this.syllabus = '',
    this.questionReady = false,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'studentId': studentId, 'title': title, 'subject': subject,
        'examType': examType, 'syllabus': syllabus, 'questionReady': questionReady,
        'date': date.toIso8601String(),
      };
  factory Exam.fromMap(Map m) => Exam(
        id: _s(m['id']), studentId: _s(m['studentId']), title: _s(m['title']),
        subject: _s(m['subject']), examType: _s(m['examType']),
        syllabus: _s(m['syllabus']), questionReady: m['questionReady'] == true,
        date: DateTime.tryParse(_s(m['date'])) ?? DateTime.now(),
      );
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
