import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';

class JobPrepScreen extends ConsumerWidget {
  const JobPrepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Govt Job Prep')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.jobtasksL, repo.jobappsL, repo.studylogsL]),
          builder: (context, _) {
            final tasks = repo.jobTaskList;
            final apps = repo.jobAppList;
            final nextExam = repo.nextJobExam;
            final now = DateTime.now();
            final wkStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
            final wkEnd = wkStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
            final (wMcq, wMin) = repo.studyTotals(wkStart, wkEnd);
            final (mMcq, mMin) = repo.studyTotals(
                DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0, 23, 59, 59));
            final slogs = repo.studyLogs;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                if (nextExam != null && nextExam.examDate != null)
                  HeroHeader(
                    gradient: AppColors.savingsGrad,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.event_available, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Next Exam', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
                      ]),
                      const SizedBox(height: 8),
                      Text(nextExam.title,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('${fullDate(nextExam.examDate!)} · in ${nextExam.examDate!.difference(DateTime.now()).inDays} days',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
                    ]),
                  ),
                Gap.l,
                Row(children: [
                  Expanded(child: GradientStatCard(label: 'This week · ${wMin}m', value: '$wMcq MCQ', gradient: AppColors.savingsGrad, icon: Icons.view_week)),
                  Gap.m,
                  Expanded(child: GradientStatCard(label: 'This month · ${mMin}m', value: '$mMcq MCQ', gradient: AppColors.primaryGrad, icon: Icons.calendar_month)),
                ]),
                Gap.l,
                SectionTitle('Study Log', icon: Icons.history_edu, color: AppColors.savings,
                    trailing: TextButton.icon(onPressed: () => showStudySheet(context),
                        icon: const Icon(Icons.add, size: 18), label: const Text('Log'))),
                if (slogs.isEmpty)
                  const PadCard(child: Text('No study logged yet. Tap "Log" to add a session.'))
                else
                  ...slogs.take(20).map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PadCard(
                          onTap: () => showStudySheet(context, existing: s),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            CircleAvatar(
                              backgroundColor: AppColors.savings.withValues(alpha: 0.15),
                              foregroundColor: AppColors.savings,
                              child: Text('${s.date.day}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Gap.m,
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.subject.isEmpty ? 'Study' : s.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text([shortDate(s.date), if (s.note.isNotEmpty) s.note].join(' · '),
                                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                            ])),
                            Text([if (s.mcq > 0) '${s.mcq} MCQ', if (s.minutes > 0) '${s.minutes}m'].join(' · '),
                                style: const TextStyle(color: AppColors.savings, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      )),
                Gap.l,
                SectionTitle('Daily Study', icon: Icons.menu_book, color: AppColors.savings,
                    trailing: tasks.isEmpty ? null : TextButton(
                        onPressed: () => _resetDaily(repo, tasks),
                        child: const Text('Reset'))),
                if (tasks.isEmpty)
                  PadCard(child: Column(children: [
                    const Text('Set daily MCQ targets per subject.'),
                    Gap.m,
                    FilledButton.tonal(
                      onPressed: () async {
                        for (final s in const ['Bangla', 'English', 'Math', 'GK', 'ICT']) {
                          await repo.saveJobTask(JobTask(id: newId(), subject: s, target: 1000));
                        }
                      },
                      child: const Text('Add default subjects'),
                    ),
                  ]))
                else
                  ...tasks.map((t) {
                    final pct = t.target == 0 ? 0 : ((t.completed / t.target) * 100).round().clamp(0, 100);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PadCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ProgressRow(label: t.subject, percent: pct, color: AppColors.savings),
                        Gap.s,
                        Row(children: [
                          Text('${t.completed} / ${t.target} MCQ', style: TextStyle(color: Theme.of(context).hintColor)),
                          const Spacer(),
                          IconButton.filledTonal(
                            onPressed: () => repo.saveJobTask(JobTask(
                                id: t.id, subject: t.subject, target: t.target,
                                completed: (t.completed - 25).clamp(0, t.target))),
                            icon: const Icon(Icons.remove)),
                          Gap.s,
                          IconButton.filledTonal(
                            onPressed: () => repo.saveJobTask(JobTask(
                                id: t.id, subject: t.subject, target: t.target,
                                completed: (t.completed + 25).clamp(0, t.target))),
                            icon: const Icon(Icons.add)),
                        ]),
                      ])),
                    );
                  }),
                Gap.l,
                SectionTitle('Job Applications', icon: Icons.work_outline, color: AppColors.primary),
                if (apps.isEmpty)
                  const PadCard(child: Text('No applications yet. Tap + to add one.'))
                else
                  ...apps.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PadCard(
                          onTap: () => showJobAppSheet(context, existing: a),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              SizedBox(
                                width: 30, height: 30,
                                child: Checkbox(value: a.done,
                                    onChanged: (_) => repo.saveJobApp(a.copyWith(done: !a.done))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(a.title, style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15,
                                  decoration: a.done ? TextDecoration.lineThrough : null,
                                  color: a.done ? Theme.of(context).hintColor : null))),
                              _statusChip(a.status),
                            ]),
                            if (a.organization.isNotEmpty)
                              Text(a.organization, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                            Gap.s,
                            Wrap(spacing: 8, runSpacing: 6, children: [
                              if (a.deadline != null)
                                InfoChip(Icons.event_busy, 'Apply by ${shortDate(a.deadline!)}', color: AppColors.expense),
                              if (a.examDate != null)
                                InfoChip(Icons.event, 'Exam ${shortDate(a.examDate!)}', color: AppColors.warning),
                            ]),
                          ]),
                        ),
                      )),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addJobApp',
        onPressed: () => showJobAppSheet(context),
        icon: const Icon(Icons.add), label: const Text('Application'),
      ),
    );
  }

  void _resetDaily(Repo repo, List<JobTask> tasks) {
    for (final t in tasks) {
      repo.saveJobTask(JobTask(id: t.id, subject: t.subject, target: t.target, completed: 0));
    }
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'Applied' => AppColors.savings,
      'Exam' => AppColors.warning,
      'Result' => AppColors.income,
      _ => AppColors.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

void showJobAppSheet(BuildContext context, {JobApplication? existing}) {
  showModalBottomSheet(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _JobAppSheet(existing: existing),
    ),
  );
}

class _JobAppSheet extends ConsumerStatefulWidget {
  const _JobAppSheet({this.existing});
  final JobApplication? existing;
  @override
  ConsumerState<_JobAppSheet> createState() => _JobAppSheetState();
}

class _JobAppSheetState extends ConsumerState<_JobAppSheet> {
  final _title = TextEditingController();
  final _org = TextEditingController();
  String _status = 'To Apply';
  DateTime? _deadline, _examDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _org.text = e.organization;
      _status = e.status;
      _deadline = e.deadline;
      _examDate = e.examDate;
    }
  }

  Future<DateTime?> _pick(DateTime? init) => showDatePicker(
      context: context, initialDate: init ?? DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2100));

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(editing ? 'Edit Application' : 'Add Application',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.expense),
              onPressed: () {
                ref.read(repoProvider).deleteJobApp(widget.existing!.id);
                Navigator.pop(context);
              }),
        ]),
        Gap.s,
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Post / title (e.g. BCS, Bank SO)')),
        Gap.s,
        TextField(controller: _org, decoration: const InputDecoration(labelText: 'Organization')),
        Gap.s,
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: const ['To Apply', 'Applied', 'Exam', 'Result']
              .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _status = v ?? 'To Apply'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_busy),
          title: const Text('Apply deadline'),
          subtitle: Text(_deadline == null ? 'Not set' : fullDate(_deadline!)),
          onTap: () async { final d = await _pick(_deadline); if (d != null) setState(() => _deadline = d); },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: const Text('Exam date'),
          subtitle: Text(_examDate == null ? 'Not set' : fullDate(_examDate!)),
          onTap: () async { final d = await _pick(_examDate); if (d != null) setState(() => _examDate = d); },
        ),
        Gap.m,
        FilledButton(
          onPressed: () async {
            if (_title.text.trim().isEmpty) return;
            await ref.read(repoProvider).saveJobApp(JobApplication(
              id: widget.existing?.id ?? newId(),
              title: _title.text.trim(), organization: _org.text.trim(),
              status: _status, deadline: _deadline, examDate: _examDate,
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

void showStudySheet(BuildContext context, {StudyLog? existing}) {
  showModalBottomSheet(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _StudySheet(existing: existing),
    ),
  );
}

class _StudySheet extends ConsumerStatefulWidget {
  const _StudySheet({this.existing});
  final StudyLog? existing;
  @override
  ConsumerState<_StudySheet> createState() => _StudySheetState();
}

class _StudySheetState extends ConsumerState<_StudySheet> {
  static const _subjects = ['Bangla', 'English', 'Math', 'GK', 'ICT', 'General', 'Other'];
  String _subject = 'Math';
  final _mcq = TextEditingController();
  final _minutes = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _subject = _subjects.contains(e.subject) ? e.subject : 'Other';
      _mcq.text = e.mcq == 0 ? '' : '${e.mcq}';
      _minutes.text = e.minutes == 0 ? '' : '${e.minutes}';
      _note.text = e.note;
      _date = e.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(editing ? 'Edit Study' : 'Log Study',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.expense),
              onPressed: () {
                ref.read(repoProvider).deleteStudyLog(widget.existing!.id);
                Navigator.pop(context);
              }),
        ]),
        Gap.s,
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today),
          title: const Text('Date'),
          subtitle: Text(fullDate(_date)),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date,
                firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => _date = d);
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: _subject,
          decoration: const InputDecoration(labelText: 'Subject'),
          items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _subject = v ?? 'Math'),
        ),
        Gap.s,
        Row(children: [
          Expanded(child: TextField(controller: _mcq, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'MCQ done'))),
          Gap.s,
          Expanded(child: TextField(controller: _minutes, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Minutes'))),
        ]),
        Gap.s,
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
        Gap.l,
        FilledButton(
          onPressed: () async {
            await ref.read(repoProvider).saveStudyLog(StudyLog(
              id: widget.existing?.id ?? newId(), date: _date, subject: _subject,
              mcq: int.tryParse(_mcq.text.trim()) ?? 0,
              minutes: int.tryParse(_minutes.text.trim()) ?? 0,
              note: _note.text.trim(),
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
