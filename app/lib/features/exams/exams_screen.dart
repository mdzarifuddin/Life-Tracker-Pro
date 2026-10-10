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
                        SizedBox(width: 32, height: 32, child: Checkbox(
                            value: e.done, activeColor: AppColors.income,
                            onChanged: (_) => repo.saveExam(e.copyWith(done: !e.done)))),
                        const SizedBox(width: 6),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (st != null)
                            Text(st.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          Text('${e.title}${e.subject.isNotEmpty ? ' · ${e.subject}' : ''}',
                              style: TextStyle(
                                  fontWeight: st != null ? FontWeight.w500 : FontWeight.w700,
                                  fontSize: st != null ? 13 : 15,
                                  color: st != null ? Theme.of(context).hintColor : null)),
                        ])),
                        Text(days <= 0 ? 'Today' : 'in $days d',
                            style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 6),
                      Text([
                        if (e.examType.isNotEmpty) e.examType,
                        '${fullDate(e.date)} · ${TimeOfDay.fromDateTime(e.date).format(context)}',
                        if (e.durationMin > 0) '${e.durationMin} min',
                      ].join(' · '), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                      if (e.syllabus.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(e.syllabus,
                            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                      ],
                      if (e.subjects.isNotEmpty) ...[
                        Gap.s,
                        ExamSyllabusView(exam: e),
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

/// Per-subject syllabus: progress, and tappable topics (tap = covered / not yet).
class ExamSyllabusView extends ConsumerWidget {
  const ExamSyllabusView({super.key, required this.exam});
  final Exam exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var si = 0; si < exam.subjects.length; si++) ...[
        Builder(builder: (context) {
          final sub = exam.subjects[si];
          final total = sub.topics.length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(total == 0 ? 'no syllabus' : '${sub.doneCount}/$total done · ${sub.leftCount} left',
                    style: TextStyle(
                        fontSize: 12,
                        color: total > 0 && sub.leftCount == 0 ? AppColors.income : AppColors.warning,
                        fontWeight: FontWeight.w600)),
              ]),
              if (total > 0) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: sub.doneCount / total, minHeight: 5,
                    color: AppColors.income,
                    backgroundColor: AppColors.income.withValues(alpha: 0.15)),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 0, children: [
                  for (var ti = 0; ti < total; ti++)
                    FilterChip(
                      label: Text(sub.topics[ti].title, style: const TextStyle(fontSize: 12)),
                      selected: sub.topics[ti].done,
                      showCheckmark: true,
                      checkmarkColor: AppColors.income,
                      selectedColor: AppColors.income.withValues(alpha: 0.18),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) => repo.saveExam(exam.withTopicToggled(si, ti)),
                    ),
                ]),
              ],
            ]),
          );
        }),
      ],
    ]);
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
    'Biology', 'ICT', 'General Science',
  ];
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _subjects = <_SubjectDraft>[];
  String _type = 'Monthly Test';
  String? _studentId;
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  bool _questionReady = false;
  int _duration = 0;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      for (final s in e.subjects) {
        _subjects.add(_SubjectDraft(s.name, [...s.topics]));
      }
      _notes.text = e.syllabus;
      _type = e.examType.isEmpty ? 'Monthly Test' : e.examType;
      _studentId = e.studentId.isEmpty ? null : e.studentId;
      _date = e.date;
      _time = TimeOfDay(hour: e.date.hour, minute: e.date.minute);
      _questionReady = e.questionReady;
      _duration = e.durationMin;
    } else {
      _studentId = widget.presetStudentId;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    for (final s in _subjects) {
      s.input.dispose();
    }
    super.dispose();
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

  Future<void> _addSubject() async {
    final taken = _subjects.map((s) => s.name).toSet();
    final repoStudent = _studentId == null ? null : ref.read(repoProvider).student(_studentId!);
    final options = <String>{...?repoStudent?.subjects, ..._commonSubjects}
        .where((n) => !taken.contains(n)).toList();
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: [
        for (final n in options) ListTile(title: Text(n), onTap: () => Navigator.pop(ctx, n)),
        ListTile(
          leading: const Icon(Icons.add), title: const Text('Custom…'),
          onTap: () => Navigator.pop(ctx, '__custom__')),
      ])),
    );
    if (picked == null) return;
    final name = picked == '__custom__' ? await _askCustom() : picked;
    if (name == null || name.isEmpty || taken.contains(name)) return;
    setState(() => _subjects.add(_SubjectDraft(name, [])));
  }

  void _addTopics(_SubjectDraft sub) {
    // comma / new-line separated, so several can be typed at once
    final parts = sub.input.text.split(RegExp(r'[,\n]')).map((t) => t.trim()).where((t) => t.isNotEmpty);
    if (parts.isEmpty) return;
    setState(() {
      for (final p in parts) {
        if (!sub.topics.any((t) => t.title == p)) sub.topics.add(SyllabusTopic(p));
      }
      sub.input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final students = repo.pickableStudents(_studentId);
    final editing = widget.existing != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(editing ? 'Edit Exam' : 'Add Exam',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Gap.m,
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title (e.g. HSC Model Test)')),
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
        Gap.s,
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: const ['SSC', 'HSC', 'Monthly Test', 'Pre-Test', 'Model Test']
              .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => _type = v ?? 'Monthly Test'),
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
        Row(children: [
          const Expanded(child: Text('Subjects & syllabus', style: TextStyle(fontWeight: FontWeight.w700))),
          TextButton.icon(
            onPressed: _addSubject,
            icon: const Icon(Icons.add, size: 18), label: const Text('Subject')),
        ]),
        if (_subjects.isEmpty)
          Text('Add each subject and list its syllabus topics to track what is done and left.',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
        for (final sub in _subjects)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 10),
            decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('${sub.topics.where((t) => t.done).length}/${sub.topics.length} done',
                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                IconButton(
                  tooltip: 'Remove subject',
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.expense, size: 20),
                  onPressed: () => setState(() => _subjects.remove(sub))),
              ]),
              Wrap(spacing: 6, runSpacing: 0, children: [
                for (var i = 0; i < sub.topics.length; i++)
                  InputChip(
                    label: Text(sub.topics[i].title, style: const TextStyle(fontSize: 12)),
                    selected: sub.topics[i].done,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => setState(() => sub.topics[i] = sub.topics[i].toggled()),
                    onDeleted: () => setState(() => sub.topics.removeAt(i)),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextField(
                  controller: sub.input,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Add topics (comma separated)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add), onPressed: () => _addTopics(sub))),
                  onSubmitted: (_) => _addTopics(sub),
                ),
              ),
            ]),
          ),
        Gap.s,
        TextField(controller: _notes, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Other notes (optional)')),
        Gap.s,
        DropdownButtonFormField<int>(
          initialValue: _duration,
          decoration: const InputDecoration(labelText: 'Exam duration'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Not set')),
            DropdownMenuItem(value: 30, child: Text('30 min')),
            DropdownMenuItem(value: 45, child: Text('45 min')),
            DropdownMenuItem(value: 60, child: Text('1 hour')),
            DropdownMenuItem(value: 90, child: Text('1.5 hour')),
            DropdownMenuItem(value: 120, child: Text('2 hour')),
            DropdownMenuItem(value: 180, child: Text('3 hour')),
          ],
          onChanged: (v) => setState(() => _duration = v ?? 0),
        ),
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
            for (final s in _subjects) {
              _addTopics(s); // pick up text typed but not added yet
            }
            final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
            await ref.read(repoProvider).saveExam(Exam(
              id: widget.existing?.id ?? newId(),
              title: _title.text.trim(),
              examType: _type, studentId: _studentId ?? '', date: dt,
              subjects: _subjects.map((s) => ExamSubject(s.name, [...s.topics])).toList(),
              syllabus: _notes.text.trim(), questionReady: _questionReady,
              durationMin: _duration, done: widget.existing?.done ?? false,
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

class _SubjectDraft {
  _SubjectDraft(this.name, this.topics);
  final String name;
  final List<SyllabusTopic> topics;
  final input = TextEditingController();
}
