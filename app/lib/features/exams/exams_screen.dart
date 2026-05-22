import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';

class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Tracker')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.examsL, repo.studentsL]),
          builder: (context, _) {
            final exams = repo.upcomingExams;
            if (exams.isEmpty) {
              return EmptyState(
                icon: Icons.event,
                message: 'No upcoming exams.',
                cta: 'Add Exam',
                onCta: () => showExamSheet(context),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: exams.map((e) {
                final st = e.studentId.isEmpty ? null : repo.student(e.studentId);
                final days = e.date.difference(DateTime.now()).inDays;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PadCard(
                    onTap: () => showExamSheet(context, existing: e),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.event, color: AppColors.warning),
                        ),
                        Gap.m,
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${e.title}${e.subject.isNotEmpty ? ' · ${e.subject}' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text([if (st != null) st.name, e.examType,
                                '${fullDate(e.date)} · ${TimeOfDay.fromDateTime(e.date).format(context)}']
                              .where((x) => x.isNotEmpty).join(' · '),
                              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                        ])),
                        Text(days <= 0 ? 'Today' : 'in $days d',
                            style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
                      ]),
                      if (e.syllabus.isNotEmpty) ...[
                        Gap.s,
                        Text('Syllabus: ${e.syllabus}',
                            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                      ],
                      Gap.s,
                      InfoChip(
                        e.questionReady ? Icons.check_circle : Icons.hourglass_bottom,
                        e.questionReady ? 'Question ready' : 'Question pending',
                        color: e.questionReady ? AppColors.income : AppColors.warning),
                    ]),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addExam',
        onPressed: () => showExamSheet(context),
        icon: const Icon(Icons.add), label: const Text('Exam'),
      ),
    );
  }
}

/// Opens the add/edit-exam sheet, optionally pre-linked to a student.
void showExamSheet(BuildContext context, {String? studentId, Exam? existing}) {
  showModalBottomSheet(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ExamSheet(presetStudentId: studentId, existing: existing),
    ),
  );
}

class _ExamSheet extends ConsumerStatefulWidget {
  const _ExamSheet({this.presetStudentId, this.existing});
  final String? presetStudentId;
  final Exam? existing;
  @override
  ConsumerState<_ExamSheet> createState() => _ExamSheetState();
}

class _ExamSheetState extends ConsumerState<_ExamSheet> {
  static const _commonSubjects = [
    'Bangla', 'English', 'Math', 'Higher Math', 'Physics', 'Chemistry',
    'Biology', 'ICT', 'GK', 'Accounting', 'Economics', 'General Science',
  ];
  final _title = TextEditingController();
  final _syllabus = TextEditingController();
  String? _subject;
  late final List<String> _subjectOpts = [..._commonSubjects];
  String _type = 'Monthly Test';
  String? _studentId;
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  bool _questionReady = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _subject = e.subject.isEmpty ? null : e.subject;
      if (e.subject.isNotEmpty && !_subjectOpts.contains(e.subject)) _subjectOpts.add(e.subject);
      _syllabus.text = e.syllabus;
      _type = e.examType.isEmpty ? 'Monthly Test' : e.examType;
      _studentId = e.studentId.isEmpty ? null : e.studentId;
      _date = e.date;
      _time = TimeOfDay(hour: e.date.hour, minute: e.date.minute);
      _questionReady = e.questionReady;
    } else {
      _studentId = widget.presetStudentId;
    }
  }

  Future<String?> _askCustom() {
    final c = TextEditingController();
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Custom subject'),
      content: TextField(controller: c, autofocus: true,
          decoration: const InputDecoration(hintText: 'Subject name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Add')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final students = repo.studentList;
    final editing = widget.existing != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(editing ? 'Edit Exam' : 'Add Exam',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Gap.m,
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title (e.g. HSC Model Test)')),
        Gap.s,
        DropdownButtonFormField<String>(
          initialValue: _subject,
          decoration: const InputDecoration(labelText: 'Subject'),
          items: [
            ..._subjectOpts.map((s) => DropdownMenuItem(value: s, child: Text(s))),
            const DropdownMenuItem(value: '__custom__', child: Text('➕ Custom…')),
          ],
          onChanged: (v) async {
            if (v == '__custom__') {
              final name = await _askCustom();
              if (name != null && name.isNotEmpty) {
                setState(() {
                  if (!_subjectOpts.contains(name)) _subjectOpts.add(name);
                  _subject = name;
                });
              }
            } else {
              setState(() => _subject = v);
            }
          },
        ),
        Gap.s,
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: const ['SSC', 'HSC', 'Monthly Test', 'Pre-Test', 'Model Test']
              .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => _type = v ?? 'Monthly Test'),
        ),
        Gap.s,
        DropdownButtonFormField<String>(
          initialValue: _studentId,
          decoration: const InputDecoration(labelText: 'Student (optional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('— none —')),
            ...students.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
          ],
          onChanged: (v) => setState(() => _studentId = v),
        ),
        Row(children: [
          Expanded(child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, size: 20),
            title: Text(fullDate(_date)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _date = d);
            },
          )),
          Expanded(child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time, size: 20),
            title: Text(_time.format(context)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          )),
        ]),
        TextField(controller: _syllabus, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Syllabus')),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _questionReady,
          title: const Text('Question ready'),
          onChanged: (v) => setState(() => _questionReady = v ?? false),
        ),
        Gap.s,
        FilledButton(
          onPressed: () async {
            if (_title.text.trim().isEmpty) return;
            final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
            await ref.read(repoProvider).saveExam(Exam(
              id: widget.existing?.id ?? newId(),
              title: _title.text.trim(),
              examType: _type, studentId: _studentId ?? '', date: dt,
              subject: _subject ?? '',
              syllabus: _syllabus.text.trim(), questionReady: _questionReady,
            ));
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(editing ? 'Update' : 'Save'),
        ),
        Gap.s,
      ]),
    );
  }
}
