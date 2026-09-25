import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';
import '../exams/exams_screen.dart';
import '../schedule/schedule_screen.dart';

/// Per-student card color (custom if set, else derived from the name).
Color studentColor(Student s) => s.colorValue != 0
    ? Color(s.colorValue)
    : AppColors.forIndex(s.name.isEmpty ? 0 : s.name.codeUnitAt(0) + s.name.length);

/// Avatar showing the student's photo if set, else a colored initial.
class StudentAvatar extends StatelessWidget {
  const StudentAvatar(this.student, {super.key, this.radius = 22});
  final Student student;
  final double radius;
  @override
  Widget build(BuildContext context) {
    if (student.photo.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(base64Decode(student.photo)));
    }
    final c = studentColor(student);
    return CircleAvatar(
      radius: radius,
      backgroundColor: c.withValues(alpha: 0.18),
      foregroundColor: c,
      child: Text(student.name.isEmpty ? '?' : student.name[0].toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: radius * 0.8)),
    );
  }
}

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});
  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  String _q = '';
  bool _showAll = false; // false = current students only
  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuition'),
        actions: [
          TextButton.icon(
              onPressed: () => context.push('/students/payments'),
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Pay')),
          TextButton.icon(
              onPressed: () => context.push('/students/exams'),
              icon: const Icon(Icons.event_note, size: 18),
              label: const Text('Exams')),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search students…', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _q = v.toLowerCase()),
              ),
            ),
            AnimatedBuilder(
              animation: repo.studentsL,
              builder: (context, _) {
                final all = repo.studentList;
                final current = all.where((s) => s.isCurrent).length;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: false, label: Text('Current ($current)'),
                            icon: const Icon(Icons.person, size: 18)),
                        ButtonSegment(value: true, label: Text('All students (${all.length})'),
                            icon: const Icon(Icons.groups, size: 18)),
                      ],
                      selected: {_showAll},
                      onSelectionChanged: (v) => setState(() => _showAll = v.first),
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([repo.studentsL, repo.schedulesL, repo.logsL]),
                builder: (context, _) {
                  final list = repo.studentList
                      .where((s) => (_showAll || s.isCurrent) && s.name.toLowerCase().contains(_q))
                      .toList()
                    // in "All", current students first, previous ones after
                    ..sort((a, b) => a.isCurrent == b.isCurrent ? 0 : (a.isCurrent ? -1 : 1));
                  if (list.isEmpty) {
                    final none = repo.studentList.isEmpty;
                    return EmptyState(
                      icon: Icons.people_outline,
                      message: _q.isNotEmpty
                          ? 'No match.'
                          : none
                              ? 'No students yet.\nAdd your first student.'
                              : 'No current students.\nOpen "All students" to see previous ones.',
                      cta: _q.isEmpty ? 'Add Student' : null,
                      onCta: () => context.push('/student-form'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (c, i) {
                      final s = list[i];
                      final subj = s.subjects.join(' + ');
                      final next = repo.nextClassFor(s.id);
                      final classes = repo.logsFor(s.id).length;
                      final last = repo.lastLog(s.id);
                      final card = PadCard(
                        tint: s.isCurrent ? studentColor(s) : null,
                        onTap: () => context.go('/students/${s.id}'),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            StudentAvatar(s),
                            Gap.m,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                  if (s.grade.isNotEmpty || subj.isNotEmpty)
                                    Text([s.grade, subj].where((e) => e.isNotEmpty).join(' · '),
                                        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                                ],
                              ),
                            ),
                            Text(taka(s.monthlyFee), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                          Gap.m,
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            if (!s.isCurrent)
                              InfoChip(Icons.history,
                                  s.leftDate == null ? 'Previous' : 'Previous · left ${fullDate(s.leftDate!)}',
                                  color: AppColors.expense),
                            InfoChip(Icons.menu_book, '$classes ${classes == 1 ? 'class' : 'classes'}', color: AppColors.primary),
                            if (!s.isCurrent)
                              const SizedBox.shrink()
                            else if (next != null)
                              InfoChip(Icons.schedule,
                                  'Next: ${weekdayNames[next.dayOfWeek]} ${minutesToTime(next.startMinutes)}',
                                  color: AppColors.savings)
                            else
                              const InfoChip(Icons.schedule, 'No class set', color: AppColors.warning),
                          ]),
                          if (last != null && last.topics.isNotEmpty) ...[
                            Gap.s,
                            Text('Last: ${last.topics}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
                          ],
                        ]),
                      );
                      return s.isCurrent ? card : Opacity(opacity: 0.6, child: card);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addStudent',
        onPressed: () => context.push('/student-form'),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add'),
      ),
    );
  }
}

class StudentDetailScreen extends ConsumerStatefulWidget {
  const StudentDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Widget _examCard(Repo repo, Exam e, {bool taken = false}) {
    final days = e.date.difference(DateTime.now()).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PadCard(
        tint: taken ? AppColors.income : null,
        onTap: () => showExamSheet(context, existing: e),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(width: 30, height: 30, child: Checkbox(
                value: e.done, activeColor: AppColors.income,
                onChanged: (_) => repo.saveExam(e.copyWith(done: !e.done)))),
            const SizedBox(width: 8),
            Expanded(child: Text('${e.title}${e.subject.isNotEmpty ? ' · ${e.subject}' : ''}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                    decoration: taken ? TextDecoration.lineThrough : null))),
            if (!taken) Text(days <= 0 ? 'Today' : 'in $days d',
                style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 38, top: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text([
                if (e.examType.isNotEmpty) e.examType,
                '${fullDate(e.date)} · ${TimeOfDay.fromDateTime(e.date).format(context)}',
                if (e.durationMin > 0) '${e.durationMin} min',
                e.questionReady ? 'Q ready' : 'Q pending',
              ].join(' · '), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
              if (e.syllabus.isNotEmpty)
                Text('Syllabus: ${e.syllabus}',
                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final id = widget.id;
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.studentsL, repo.logsL, repo.paymentsL, repo.examsL]),
          builder: (context, _) {
            final s = repo.student(id);
            if (s == null) {
              return const Center(child: Text('Student not found'));
            }
            final logs = repo.logsFor(id);
            final last = repo.lastLog(id);
            final exams = repo.examsFor(id);
            final taughtKeys = logs.map((l) => dateKey(l.date)).toSet();
            final monthLogs = logs
                .where((l) => l.date.year == _month.year && l.date.month == _month.month)
                .toList();
            final monthExams = exams
                .where((e) => e.date.year == _month.year && e.date.month == _month.month)
                .toList();
            final m = monthKey(DateTime.now());
            final pay = repo.paymentFor(id, m);
            final paid = pay?.status == 'paid';
            return CustomScrollView(slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                title: Text(s.name),
                actions: [
                  IconButton(icon: const Icon(Icons.add_alarm),
                      tooltip: 'Schedule class',
                      onPressed: () => openScheduleSheet(context, ref, presetStudentId: id)),
                  IconButton(
                      icon: Icon(s.isCurrent ? Icons.person_off_outlined : Icons.person_add_alt_1),
                      tooltip: s.isCurrent ? 'Mark as previous' : 'Mark as current',
                      onPressed: () => setStudentCurrent(context, ref, s, !s.isCurrent)),
                  IconButton(icon: const Icon(Icons.edit),
                      tooltip: 'Edit student',
                      onPressed: () => context.push('/student-form', extra: id)),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  PadCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      StudentAvatar(s, radius: 26),
                      Gap.m,
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text([s.grade, s.institution].where((e) => e.isNotEmpty).join(' · '),
                            style: TextStyle(color: Theme.of(context).hintColor)),
                      ])),
                    ]),
                    if (s.subjects.isNotEmpty) ...[Gap.m, Wrap(spacing: 6, runSpacing: 6,
                        children: s.subjects.map((e) => Chip(label: Text(e), visualDensity: VisualDensity.compact)).toList())],
                    Gap.m,
                    Row(children: [
                      const Icon(Icons.payments, size: 18), const SizedBox(width: 6),
                      Text('Fee ${taka(s.monthlyFee)}/mo'),
                      if (s.classesPerMonth > 0) ...[const SizedBox(width: 14),
                        const Icon(Icons.event_repeat, size: 16), const SizedBox(width: 4),
                        Text('${s.classesPerMonth}/month')],
                    ]),
                    if (s.days.isNotEmpty) ...[Gap.s, Row(children: [
                      const Icon(Icons.calendar_view_week, size: 16, color: AppColors.savings),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Days: ${weekdayNames.where((d) => s.days.contains(d)).join(', ')}',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                    ])],
                    if (s.guardianPhone.isNotEmpty) ...[Gap.s, _PhoneRow(label: 'Guardian', phone: s.guardianPhone)],
                    if (s.phone.isNotEmpty) ...[Gap.s, _PhoneRow(label: 'Student', phone: s.phone)],
                    for (final p in s.extraPhones) ...[Gap.s, _PhoneRow(label: 'Other', phone: p)],
                    Gap.m,
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      InfoChip(Icons.calendar_month, '${monthLogs.length} in ${monthLabel(_month)}', color: AppColors.income),
                      InfoChip(Icons.menu_book, 'Total: ${logs.length} classes', color: AppColors.primary),
                    ]),
                  ])),
                  Gap.l,
                  Row(children: [
                    Expanded(child: FilledButton.tonalIcon(
                      onPressed: () => context.push('/class-log', extra: id),
                      icon: const Icon(Icons.edit_note), label: const Text('Log Class'))),
                    Gap.m,
                    Expanded(child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: paid ? AppColors.income : AppColors.warning),
                      onPressed: () async {
                        if (paid) {
                          await repo.markFeeUnpaid(pay!);
                        } else {
                          await repo.markFeePaid(s, DateTime.now());
                        }
                      },
                      icon: Icon(paid ? Icons.check_circle : Icons.attach_money),
                      label: Text(paid ? 'Fee Paid' : 'Mark Paid'))),
                  ]),
                  Gap.l,
                  const SectionTitle('Last Class Summary'),
                  PadCard(child: last == null
                      ? const Text('No classes logged yet.')
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(fullDate(last.date), style: TextStyle(color: Theme.of(context).hintColor)),
                          if (last.topics.isNotEmpty) ...[Gap.s, Text('Topics: ${last.topics}')],
                          if (last.homework.isNotEmpty) ...[Gap.xs, Text('Homework: ${last.homework}')],
                          Gap.s,
                          Text('Performance: ${last.performance}/10',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ])),
                  Gap.l,
                  SectionTitle('Attendance Calendar', icon: Icons.event_available, color: AppColors.income),
                  _TaughtCalendar(
                    taughtKeys: taughtKeys,
                    month: _month,
                    onMonthChanged: (mo) => setState(() => _month = mo),
                    onTapDay: (day) {
                      final match = logs.where((l) => dateKey(l.date) == dateKey(day)).toList();
                      if (match.isNotEmpty) {
                        context.push('/class-log', extra: match.first);
                      } else {
                        context.push('/class-log', extra: {'studentId': id, 'date': day});
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text('Tap a day to add/edit · use ‹ › to change month (logs & exams follow)',
                        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                  ),
                  Gap.l,
                  SectionTitle('Exams', icon: Icons.event, color: AppColors.warning,
                      trailing: TextButton.icon(
                          onPressed: () => showExamSheet(context, studentId: id),
                          icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
                  if (monthExams.where((e) => !e.done).isEmpty)
                    const PadCard(child: Text('No upcoming exams this month.'))
                  else
                    ...monthExams.where((e) => !e.done).map((e) => _examCard(repo, e)),
                  if (monthExams.any((e) => e.done)) ...[
                    Gap.l,
                    SectionTitle('Taken exams', icon: Icons.history, color: AppColors.income),
                    ...monthExams.where((e) => e.done).map((e) => _examCard(repo, e, taken: true)),
                  ],
                  Gap.l,
                  SectionTitle('Class Logs (${monthLogs.length})'),
                  if (monthLogs.isEmpty) const PadCard(child: Text('No logs this month.'))
                  else ...monthLogs.map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PadCard(
                          onTap: () => context.push('/class-log', extra: l),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(
                                  '${fullDate(l.date)}${l.subject.isNotEmpty ? ' · ${l.subject}' : ''} · ${TimeOfDay.fromDateTime(l.date).format(context)}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600))),
                              Text('${l.performance}/10', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              Icon(Icons.edit, size: 15, color: Theme.of(context).hintColor),
                            ]),
                            if (l.topics.isNotEmpty) ...[const SizedBox(height: 4), Text('Covered: ${l.topics}')],
                            if (l.homework.isNotEmpty)
                              Text('HW: ${l.homework}', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                            if (l.learned.isNotEmpty)
                              Text('Learned: ${l.learned}', style: const TextStyle(color: AppColors.income, fontSize: 13)),
                            if (l.notDone.isNotEmpty)
                              Text('Pending: ${l.notDone}', style: const TextStyle(color: AppColors.expense, fontSize: 13)),
                            if (l.nextPlan.isNotEmpty)
                              Text('Next: ${l.nextPlan}', style: const TextStyle(color: AppColors.savings, fontSize: 13)),
                          ])),
                      )),
                ])),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class StudentFormScreen extends ConsumerStatefulWidget {
  const StudentFormScreen({super.key, this.id});
  final String? id;
  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends ConsumerState<StudentFormScreen> {
  static const _classOptions = [
    'Class 6', 'Class 7', 'Class 8', 'SSC (Class 9)', 'SSC (Class 10)',
    'HSC 1st Year', 'HSC 2nd Year', 'Admission', 'Honors', 'Other',
  ];
  static const _subjectPreset = [
    'Bangla', 'English', 'Math', 'Higher Math', 'Physics', 'Chemistry',
    'Biology', 'ICT', 'GK', 'Accounting', 'Economics', 'General Science',
  ];
  static const _perMonthOptions = [4, 8, 12, 16, 20, 24, 30];

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _institution = TextEditingController();
  final _fee = TextEditingController();
  final _guardian = TextEditingController();
  final _guardianPhone = TextEditingController();
  final List<TextEditingController> _extraPhones = [];

  String? _grade;
  int _perMonth = 8;
  int _colorValue = 0;
  String _photo = '';
  TimeOfDay _defaultTime = const TimeOfDay(hour: 16, minute: 0);
  final _subjects = <String>{};
  final _days = <String>{};
  List<String> _classList = [];
  List<String> _subjectOptions = [];
  Student? _existing;
  bool _current = true;

  @override
  void initState() {
    super.initState();
    _classList = [..._classOptions];
    _subjectOptions = [..._subjectPreset];
    if (widget.id != null) {
      final s = ref.read(repoProvider).student(widget.id!);
      if (s != null) {
        _existing = s;
        _current = s.isCurrent;
        _name.text = s.name;
        _phone.text = s.phone;
        _institution.text = s.institution;
        _fee.text = s.monthlyFee == 0 ? '' : s.monthlyFee.toStringAsFixed(0);
        _guardian.text = s.guardianName;
        _guardianPhone.text = s.guardianPhone;
        for (final p in s.extraPhones) {
          _extraPhones.add(TextEditingController(text: p));
        }
        _photo = s.photo;
        _perMonth = s.classesPerMonth == 0 ? 8 : s.classesPerMonth;
        _defaultTime = TimeOfDay(hour: s.defaultTimeMinutes ~/ 60, minute: s.defaultTimeMinutes % 60);
        _colorValue = s.colorValue;
        _days.addAll(s.days);
        if (s.grade.isNotEmpty) {
          if (!_classList.contains(s.grade)) _classList.insert(_classList.length - 1, s.grade);
          _grade = s.grade;
        }
        _subjects.addAll(s.subjects);
        for (final sub in s.subjects) {
          if (!_subjectOptions.contains(sub)) _subjectOptions.add(sub);
        }
      }
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name is required')));
      return;
    }
    final s = Student(
      id: widget.id ?? newId(),
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      grade: _grade ?? '',
      institution: _institution.text.trim(),
      monthlyFee: double.tryParse(_fee.text.trim()) ?? 0,
      classesPerMonth: _perMonth,
      defaultTimeMinutes: _defaultTime.hour * 60 + _defaultTime.minute,
      colorValue: _colorValue,
      photo: _photo,
      subjects: _subjects.toList(),
      days: weekdayNames.where((d) => _days.contains(d)).toList(),
      weakSubjects: const [],
      extraPhones: _extraPhones.map((c) => c.text.trim()).where((x) => x.isNotEmpty).toList(),
      guardianName: _guardian.text.trim(),
      guardianPhone: _guardianPhone.text.trim(),
      batch: _existing?.batch ?? '',
      status: _current ? 'active' : 'previous',
      leftOn: _current
          ? ''
          : (_existing?.leftOn.isNotEmpty ?? false)
              ? _existing!.leftOn
              : DateTime.now().toIso8601String().substring(0, 10),
    );
    await ref.read(repoProvider).saveStudent(s);
    if (mounted) context.pop();
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 70);
    if (x != null) {
      final bytes = await x.readAsBytes();
      setState(() => _photo = base64Encode(bytes));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'Add Student' : 'Edit Student')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(child: GestureDetector(
            onTap: _pickPhoto,
            child: CircleAvatar(
              radius: 46,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: _photo.isEmpty ? null : MemoryImage(base64Decode(_photo)),
              child: _photo.isEmpty
                  ? const Icon(Icons.add_a_photo, color: AppColors.primary, size: 28)
                  : null,
            ),
          )),
          if (_photo.isNotEmpty)
            Center(child: TextButton(
                onPressed: () => setState(() => _photo = ''), child: const Text('Remove photo'))),
          Gap.m,
          _text(_name, 'Name *'),
          if (_existing != null) ...[
            Gap.s,
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Currently studying'),
              subtitle: Text(_current
                  ? 'Shown in Tuition, schedule and fees'
                  : 'Previous student: hidden from Tuition list and schedule'),
              value: _current,
              onChanged: (v) => setState(() => _current = v),
            ),
          ],
          Gap.m,
          DropdownButtonFormField<String>(
            initialValue: _grade,
            decoration: const InputDecoration(labelText: 'Class'),
            items: _classList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _grade = v),
          ),
          Gap.m,
          _text(_institution, 'Institution'),
          Gap.l,
          _chips('Subjects', _subjects),
          Gap.l,
          DropdownButtonFormField<int>(
            initialValue: _perMonth,
            decoration: const InputDecoration(labelText: 'Classes per month'),
            items: _perMonthOptions.map((n) =>
                DropdownMenuItem(value: n, child: Text('$n classes / month'))).toList(),
            onChanged: (v) => setState(() => _perMonth = v ?? 8),
          ),
          Gap.s,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: const Text('Default class time'),
            subtitle: Text(_defaultTime.format(context)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _defaultTime);
              if (t != null) setState(() => _defaultTime = t);
            },
          ),
          Gap.m,
          const Align(alignment: Alignment.centerLeft,
              child: Text('Class days', style: TextStyle(fontWeight: FontWeight.w600))),
          Gap.s,
          Wrap(spacing: 8, runSpacing: 8, children: weekdayNames.map((d) => FilterChip(
                label: Text(d),
                selected: _days.contains(d),
                onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
              )).toList()),
          Gap.m,
          const Text('Card colour', style: TextStyle(fontWeight: FontWeight.w600)),
          Gap.s,
          Wrap(spacing: 10, runSpacing: 10, children: [
            _swatch(0),
            ...AppColors.palette.map((c) => _swatch(c.toARGB32(), color: c)),
          ]),
          Gap.m,
          _text(_fee, 'Monthly fee (৳)', number: true),
          Gap.m,
          _text(_phone, 'Student phone', number: true),
          Gap.m,
          _text(_guardian, 'Guardian name'),
          Gap.m,
          _text(_guardianPhone, 'Guardian phone', number: true),
          Gap.m,
          const Align(alignment: Alignment.centerLeft,
              child: Text('Other numbers', style: TextStyle(fontWeight: FontWeight.w600))),
          for (var i = 0; i < _extraPhones.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _extraPhones[i],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.+ ]'))],
                  decoration: const InputDecoration(labelText: 'Number'))),
                IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.expense),
                    onPressed: () => setState(() => _extraPhones.removeAt(i))),
              ]),
            ),
          Align(alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _extraPhones.add(TextEditingController())),
              icon: const Icon(Icons.add), label: const Text('Add number'))),
          Gap.l,
          FilledButton(onPressed: _save, child: const Text('Save Student')),
        ]),
      ),
    );
  }

  Widget _chips(String label, Set<String> selected) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Gap.s,
        Wrap(spacing: 8, runSpacing: 8, children: [
          ..._subjectOptions.map((sub) => FilterChip(
                label: Text(sub),
                selected: selected.contains(sub),
                onSelected: (v) => setState(() => v ? selected.add(sub) : selected.remove(sub)),
              )),
          ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: const Text('Custom'),
            onPressed: () => _addCustom(selected),
          ),
        ]),
      ]);

  Future<void> _addCustom(Set<String> selected) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Add subject'),
      content: TextField(controller: controller, autofocus: true,
          decoration: const InputDecoration(hintText: 'Subject name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Add')),
      ],
    ));
    if (name != null && name.isNotEmpty) {
      setState(() {
        if (!_subjectOptions.contains(name)) _subjectOptions.add(name);
        selected.add(name);
      });
    }
  }

  Widget _text(TextEditingController c, String label, {bool number = false}) => TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.+ ]'))] : null,
        decoration: InputDecoration(labelText: label),
      );

  Widget _swatch(int val, {Color? color}) {
    final sel = _colorValue == val;
    return GestureDetector(
      onTap: () => setState(() => _colorValue = val),
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: sel ? (color ?? AppColors.primary) : Colors.transparent, width: 3),
        ),
        alignment: Alignment.center,
        child: color == null
            ? const Icon(Icons.auto_awesome, size: 16)
            : (sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null),
      ),
    );
  }
}

class ClassLogFormScreen extends ConsumerStatefulWidget {
  const ClassLogFormScreen({super.key, this.studentId, this.existing, this.presetDate});
  final String? studentId;
  final ClassLog? existing;
  final DateTime? presetDate;
  @override
  ConsumerState<ClassLogFormScreen> createState() => _ClassLogFormScreenState();
}

class _ClassLogFormScreenState extends ConsumerState<ClassLogFormScreen> {
  String? _studentId;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  final _logSubjects = <String>{};
  final _hwTypes = <String>{};
  final _topics = TextEditingController();
  final _homework = TextEditingController();
  final _nextPlan = TextEditingController();
  final _learned = TextEditingController();
  final _notDone = TextEditingController();
  final _remarks = TextEditingController();
  double _perf = 7;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _studentId = e.studentId;
      _date = e.date;
      _time = TimeOfDay(hour: e.date.hour, minute: e.date.minute);
      _logSubjects.addAll(e.subject.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty));
      _topics.text = e.topics;
      _homework.text = e.homework;
      _nextPlan.text = e.nextPlan;
      _learned.text = e.learned;
      _notDone.text = e.notDone;
      _remarks.text = e.remarks;
      _perf = e.performance.toDouble();
    } else {
      _studentId = widget.studentId;
      if (widget.presetDate != null) _date = widget.presetDate!;
    }
  }

  Future<void> _save() async {
    final repo = ref.read(repoProvider);
    if (_studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a student')));
      return;
    }
    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    await repo.saveLog(ClassLog(
      id: widget.existing?.id ?? newId(),
      studentId: _studentId!, date: dt,
      subject: _logSubjects.join(', '),
      topics: _topics.text.trim(),
      homework: [..._hwTypes, if (_homework.text.trim().isNotEmpty) _homework.text.trim()].join(', '),
      nextPlan: _nextPlan.text.trim(), learned: _learned.text.trim(),
      notDone: _notDone.text.trim(), remarks: _remarks.text.trim(),
      performance: _perf.round(),
    ));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final students = repo.pickableStudents(_studentId);
    final subjOpts = (_studentId == null ? null : repo.student(_studentId!))?.subjects ?? const <String>[];
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Class Log' : 'Log Class')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<String>(
            initialValue: _studentId,
            decoration: const InputDecoration(labelText: 'Student'),
            items: students.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
            onChanged: (v) => setState(() => _studentId = v),
          ),
          Gap.m,
          Row(children: [
            Expanded(child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(fullDate(_date)),
              trailing: const Icon(Icons.calendar_today, size: 20),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date,
                    firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setState(() => _date = d);
              },
            )),
            Expanded(child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Time'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.access_time, size: 20),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
            )),
          ]),
          Gap.s,
          if (subjOpts.isNotEmpty) ...[
            const Align(alignment: Alignment.centerLeft,
                child: Text('Subjects taught', style: TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: subjOpts.map((s) => FilterChip(
                  label: Text(s), selected: _logSubjects.contains(s),
                  onSelected: (v) => setState(() => v ? _logSubjects.add(s) : _logSubjects.remove(s)),
                )).toList()),
            const SizedBox(height: 12),
          ],
          _field(_topics, 'Today covered (topics)', lines: 2),
          const Align(alignment: Alignment.centerLeft,
              child: Text('Homework', style: TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final h in const ['MCQ', 'CQ', 'Exercise', 'Page', 'Practice', 'Memorize', 'Worksheet'])
              FilterChip(
                label: Text(h),
                selected: _hwTypes.contains(h),
                onSelected: (v) => setState(() => v ? _hwTypes.add(h) : _hwTypes.remove(h))),
          ]),
          const SizedBox(height: 6),
          _field(_homework, 'Homework details (e.g. page 29-48)', lines: 2),
          _field(_learned, 'What student learned / could do', lines: 2),
          _field(_notDone, 'Not done / weak points', lines: 2),
          _field(_nextPlan, 'Next class plan', lines: 2),
          Gap.s,
          Text('Performance: ${_perf.round()}/10', style: const TextStyle(fontWeight: FontWeight.w600)),
          Slider(value: _perf, min: 0, max: 10, divisions: 10,
              label: '${_perf.round()}', onChanged: (v) => setState(() => _perf = v)),
          _field(_remarks, "Today's comment"),
          Gap.l,
          FilledButton(onPressed: _save, child: Text(editing ? 'Update Log' : 'Save Log')),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, maxLines: lines,
            decoration: InputDecoration(labelText: label)),
      );
}

/// Month calendar that highlights days a class was logged (green).
class _TaughtCalendar extends StatelessWidget {
  const _TaughtCalendar({required this.taughtKeys, required this.month, this.onMonthChanged, this.onTapDay});
  final Set<String> taughtKeys;
  final DateTime month;
  final void Function(DateTime)? onMonthChanged;
  final void Function(DateTime)? onTapDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1; // Monday = 0
    final todayKey = dateKey(DateTime.now());
    final monthCount = taughtKeys.where((k) => k.startsWith(monthKey(month))).length;

    final cells = <Widget>[
      for (var i = 0; i < offset; i++) const SizedBox(),
    ];
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      final key = dateKey(date);
      final taught = taughtKeys.contains(key);
      final isToday = key == todayKey;
      cells.add(GestureDetector(
        onTap: () => onTapDay?.call(date),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: taught ? AppColors.income : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: Text('$d', style: TextStyle(
            color: taught ? Colors.white : null,
            fontWeight: taught ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          )),
        ),
      ));
    }

    return PadCard(
      child: Column(children: [
        Row(children: [
          IconButton(
              onPressed: () => onMonthChanged?.call(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(monthLabel(month), textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700))),
          IconButton(
              onPressed: () => onMonthChanged?.call(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right)),
        ]),
        Row(children: weekdayNames
            .map((w) => Expanded(child: Center(child: Text(w,
                style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)))))
            .toList()),
        Gap.s,
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
        Gap.s,
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 12, height: 12,
              decoration: const BoxDecoration(color: AppColors.income, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Taught $monthCount ${monthCount == 1 ? 'day' : 'days'} in ${monthLabel(month)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

// Phone row with call / SMS / WhatsApp actions.
class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.label, required this.phone});
  final String label, phone;

  String get _wa {
    var n = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (n.startsWith('+')) n = n.substring(1);
    if (n.startsWith('0')) n = '88$n';
    return n;
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open ${uri.scheme}')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No app available')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Icon(Icons.phone, size: 16),
      const SizedBox(width: 6),
      Expanded(child: Text('$label: $phone',
          maxLines: 1, overflow: TextOverflow.ellipsis)),
      IconButton(visualDensity: VisualDensity.compact, tooltip: 'Call',
          icon: const Icon(Icons.call, color: AppColors.income, size: 20),
          onPressed: () => _launch(context, Uri(scheme: 'tel', path: phone))),
      IconButton(visualDensity: VisualDensity.compact, tooltip: 'SMS',
          icon: const Icon(Icons.sms, color: AppColors.savings, size: 20),
          onPressed: () => _launch(context, Uri(scheme: 'sms', path: phone))),
      IconButton(visualDensity: VisualDensity.compact, tooltip: 'WhatsApp',
          icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
          onPressed: () => _launch(context, Uri.parse('https://wa.me/$_wa'))),
    ]);
  }
}

/// Marks a student current/previous, with an Undo snackbar.
Future<void> setStudentCurrent(BuildContext context, WidgetRef ref, Student s, bool current) async {
  final repo = ref.read(repoProvider);
  await repo.saveStudent(s.withCurrent(current));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(current
          ? '${s.name} is a current student again'
          : '${s.name} moved to previous students'),
      // auto-hide even though it has an action (Flutter persists those by default)
      persist: false,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
          label: 'UNDO', textColor: AppColors.primary, onPressed: () => repo.saveStudent(s)),
    ));
}
