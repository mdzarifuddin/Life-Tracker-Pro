import 'dart:convert';

import 'bulk_classes_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';
import '../exams/exams_screen.dart';
import '../schedule/routines_screen.dart' show addRoutineFromGallery, RoutineViewer;
import 'batch_detail_screen.dart';
import 'busy_time.dart';
import 'batch_screen.dart';
import '../schedule/schedule_screen.dart';

part 'student_form.dart';
part 'class_log_form.dart';

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
    final Widget avatar;
    if (student.photo.isNotEmpty) {
      avatar = CircleAvatar(radius: radius, backgroundImage: MemoryImage(base64Decode(student.photo)));
    } else {
      final c = studentColor(student);
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: c.withValues(alpha: 0.18),
        foregroundColor: c,
        child: Text(student.name.isEmpty ? '?' : student.name[0].toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: radius * 0.8)),
      );
    }
    if (!student.isCurrent) return avatar;
    // green dot = currently active student
    final dot = (radius * 0.55).clamp(10.0, 18.0);
    return Stack(clipBehavior: Clip.none, children: [
      avatar,
      Positioned(
        right: -1, bottom: -1,
        child: Container(
          width: dot, height: dot,
          decoration: BoxDecoration(
            color: AppColors.income,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
          ),
        ),
      ),
    ]);
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
  String? _batch; // null = every batch
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
            AnimatedBuilder(
              animation: repo.studentsL,
              builder: (context, _) {
                final batches = repo.batchNames;
                if (batches.isEmpty) return const SizedBox.shrink();
                if (_batch != null && !batches.contains(_batch)) _batch = null;
                return SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('All batches'),
                          selected: _batch == null,
                          onSelected: (_) => setState(() => _batch = null)),
                      ),
                      for (final b in batches)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            avatar: const Icon(Icons.groups_2_outlined, size: 16),
                            label: Text(b),
                            selected: _batch == b,
                            onSelected: (_) => setState(() => _batch = _batch == b ? null : b)),
                        ),
                    ],
                  ),
                );
              },
            ),
            if (_batch != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: PadCard(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => BatchDetailScreen(batch: _batch!))),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.groups_2_outlined, color: AppColors.primary),
                    Gap.m,
                    Expanded(child: Text('Open batch · attendance, payments, members',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([repo.studentsL, repo.schedulesL, repo.logsL]),
                builder: (context, _) {
                  final list = repo.studentList
                      .where((s) => (_showAll || s.isCurrent) &&
                          (_batch == null || s.batch == _batch) &&
                          (s.name.toLowerCase().contains(_q) || s.batch.toLowerCase().contains(_q)))
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
                              ? 'No students yet.\nTap Add to create a student or a batch.'
                              : 'No current students.\nOpen "All students" to see previous ones.',
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
                            if (s.batch.isNotEmpty)
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => BatchDetailScreen(batch: s.batch))),
                                child: InfoChip(Icons.groups_2_outlined, s.batch, color: AppColors.primary)),
                            if (!s.isCurrent)
                              InfoChip(Icons.history,
                                  s.leftDate == null ? 'Previous' : 'Previous · left ${fullDate(s.leftDate!)}',
                                  color: AppColors.expense),
                            InfoChip(Icons.menu_book, '$classes ${classes == 1 ? 'class' : 'classes'}', color: AppColors.primary),
                            if (!s.isCurrent)
                              const SizedBox.shrink()
                            else if (next != null)
                              InfoChip(Icons.schedule,
                                  'Next: ${weekdayNames[next.dayOfWeek]}${next.isDated ? ' ${shortDate(next.dateOn!)}' : ''} ${minutesToTime(next.startMinutes)}',
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
                      return card;
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
        onPressed: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: const Text('Add Student'),
              subtitle: const Text('One student'),
              onTap: () { Navigator.pop(ctx); context.push('/student-form'); },
            ),
            ListTile(
              leading: const Icon(Icons.groups_2_outlined),
              title: const Text('Add Batch'),
              subtitle: const Text('A group: shared fee, days & time, many students'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BatchFormScreen()));
              },
            ),
            const SizedBox(height: 8),
          ])),
        ),
        icon: const Icon(Icons.add),
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
  DateTime? _monthSel; // cycle shown in the calendar/logs (null = current cycle)

  /// Routine pictures linked to this student (added here or from the Routines screen).
  Widget _routinesFor(BuildContext context, Repo repo, String sid) {
    final list = repo.routinesFor(sid);
    if (list.isEmpty) {
      return const PadCard(child: Text('No routine picture. Tap Add to pick one from your gallery.'));
    }
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final r = list[i];
          return GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => RoutineViewer(routine: r))),
            onLongPress: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text('Delete "${r.title}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true) await repo.deleteRoutine(r.id);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(children: [
                Image.memory(base64Decode(r.image), width: 150, height: 130, fit: BoxFit.cover,
                    gaplessPlayback: true),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  /// Weekly timetable summary + every class already booked for a date.
  Widget _scheduledFor(BuildContext context, WidgetRef ref, Repo repo, Student s) {
    final mine = repo.scheduleList.where((e) => e.studentId == s.id).toList();
    final weekly = mine.where((e) => !e.isDated).toList()
      ..sort((a, b) => a.dayOfWeek != b.dayOfWeek
          ? a.dayOfWeek.compareTo(b.dayOfWeek)
          : a.startMinutes.compareTo(b.startMinutes));
    final dated = repo.datedUpcoming.where((e) => e.studentId == s.id).toList();
    if (weekly.isEmpty && dated.isEmpty) {
      return const PadCard(child: Text('No classes scheduled. Tap Add to book dates.'));
    }
    Widget row(IconData icon, String title, ScheduleItem it) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.savings, size: 20),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${minutesToTime(it.startMinutes)} · ${it.durationMin} min'),
          onTap: () => openScheduleSheet(context, ref, existing: it),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => repo.deleteSchedule(it.id)),
        );
    return PadCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (weekly.isNotEmpty) ...[
        const Text('Every week', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final it in weekly) row(Icons.repeat, weekdayNames[it.dayOfWeek], it),
      ],
      if (dated.isNotEmpty) ...[
        if (weekly.isNotEmpty) const Divider(),
        const Text('Booked dates', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final it in dated)
          row(Icons.event, '${weekdayNames[it.dateOn!.weekday - 1]}, ${fullDate(it.dateOn!)}', it),
      ],
    ]));
  }

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
                Text(e.syllabus,
                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
              if (e.subjects.isNotEmpty) ...[
                const SizedBox(height: 8),
                ExamSyllabusView(exam: e),
              ],
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
          animation: Listenable.merge([repo.studentsL, repo.logsL, repo.paymentsL, repo.examsL, repo.schedulesL, repo.absencesL, repo.routinesL, repo.busytimesL]),
          builder: (context, _) {
            final s = repo.student(id);
            if (s == null) {
              return const Center(child: Text('Student not found'));
            }
            final logs = repo.logsFor(id);
            final last = repo.lastLog(id);
            final exams = repo.examsFor(id);
            final taughtKeys = logs.map((l) => dateKey(l.date)).toSet();
            final month = _monthSel ?? repo.currentCycleMonth(s);
            final cStart = repo.cycleStart(s, month), cEnd = repo.cycleEnd(s, month);
            final cycleName = s.billingDay == 1
                ? monthLabel(month)
                : '${shortDate(cStart)} – ${shortDate(cEnd)}';
            final monthLogs = logs
                .where((l) => !l.date.isBefore(cStart) && !l.date.isAfter(cEnd))
                .toList();
            final totalReceived = repo.paymentList
                .where((p) => p.studentId == id)
                .fold(0.0, (sum, p) => sum + p.paid);
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
                      Text(s.payPerClass ? 'Fee ${taka(s.monthlyFee)}/class' : 'Fee ${taka(s.monthlyFee)}/mo'),
                      if (s.payPerClass) ...[const SizedBox(width: 14),
                        const Icon(Icons.event_repeat, size: 16), const SizedBox(width: 4),
                        const Text('Per day')]
                      else if (s.classesPerMonth > 0) ...[const SizedBox(width: 14),
                        const Icon(Icons.event_repeat, size: 16), const SizedBox(width: 4),
                        Text('${s.classesPerMonth}/month')],
                    ]),
                    if (s.billingDay != 1) ...[Gap.s, Row(children: [
                      const Icon(Icons.today, size: 16), const SizedBox(width: 6),
                      Text('Month starts on the ${s.billingDay}${_ord(s.billingDay)}'),
                    ])],
                    if (s.days.isNotEmpty) ...[Gap.s, Row(children: [
                      const Icon(Icons.calendar_view_week, size: 16, color: AppColors.savings),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Days: ${weekdayNames.where((d) => s.days.contains(d)).join(', ')}',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                    ])],
                    for (final g in s.guardians.where((g) => g.phone.isNotEmpty)) ...[
                      Gap.s,
                      _PhoneRow(
                        label: [
                          g.relation.isNotEmpty ? g.relation : 'Guardian',
                          if (g.name.isNotEmpty) g.name,
                        ].join(' · '),
                        phone: g.phone),
                    ],
                    if (s.phone.isNotEmpty) ...[Gap.s, _PhoneRow(label: 'Student', phone: s.phone)],
                    for (final p in s.extraPhones) ...[Gap.s, _PhoneRow(label: 'Student', phone: p)],
                    Gap.m,
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      InfoChip(Icons.calendar_month, '${monthLogs.length} in $cycleName', color: AppColors.income),
                      InfoChip(Icons.menu_book, 'Total: ${logs.length} classes', color: AppColors.primary),
                    ]),
                    Gap.s,
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      InfoChip(Icons.hourglass_bottom, _studyingFor(s, logs), color: AppColors.savings),
                      InfoChip(Icons.payments, 'Received ${taka(totalReceived)}', color: AppColors.income),
                    ]),
                  ])),
                  Gap.l,
                  SizedBox(width: double.infinity, child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/class-log', extra: id),
                    icon: const Icon(Icons.edit_note), label: const Text('Log Class'))),
                  Gap.s,
                  Builder(builder: (context) {
                    final a = repo.feeAccount(s);
                    final over = a.isOverdue;
                    return PadCard(
                      onTap: () => context.push('/student-fees/$id'),
                      child: Row(children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            color: a.owed > 0.5 ? (over ? AppColors.expense : AppColors.warning) : AppColors.income),
                        Gap.m,
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Fees', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            a.owed > 0.5
                                ? (over ? 'Owes ${taka(a.owed)} · overdue ${a.overdueDays}d' : 'Owes ${taka(a.owed)}')
                                : a.credit > 0.5 ? 'Advance ${taka(a.credit)}' : 'All clear',
                            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
                        ])),
                        const Icon(Icons.chevron_right),
                      ]),
                    );
                  }),
                  Gap.l,
                  SectionTitle('Routine pictures', icon: Icons.photo_library_outlined, color: AppColors.savings,
                      trailing: TextButton.icon(
                          onPressed: () => addRoutineFromGallery(context, ref, studentId: id),
                          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                          label: const Text('Add'))),
                  _routinesFor(context, repo, id),
                  Gap.l,
                  SectionTitle('Busy times', icon: Icons.block, color: AppColors.warning,
                      trailing: TextButton.icon(
                          onPressed: () => showBusySheet(context, repo, id),
                          icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
                  BusyTimesList(repo: repo, studentId: id),
                  Gap.l,
                  SectionTitle('Scheduled classes', icon: Icons.event_available, color: AppColors.savings,
                      trailing: TextButton.icon(
                          onPressed: () => openScheduleSheet(context, ref, presetStudentId: id),
                          icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
                  _scheduledFor(context, ref, repo, s),
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
                    absentKeys: repo.absencesFor(id).map((a) => a.date).toSet(),
                    start: cStart,
                    end: cEnd,
                    label: cycleName,
                    onShift: (dir) => setState(() => _monthSel = DateTime(month.year, month.month + dir)),
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
                    child: Text('Tap a day to add/edit · use ‹ › to change month (logs follow)',
                        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                  ),
                  Gap.l,
                  SectionTitle('Exams', icon: Icons.event, color: AppColors.warning,
                      trailing: TextButton.icon(
                          onPressed: () => showExamSheet(context, studentId: id),
                          icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
                  if (exams.where((e) => !e.done).isEmpty)
                    const PadCard(child: Text('No upcoming exams. Tap Add to create one.'))
                  else
                    ...exams.where((e) => !e.done).map((e) => _examCard(repo, e)),
                  if (exams.any((e) => e.done)) ...[
                    Gap.l,
                    SectionTitle('Taken exams', icon: Icons.history, color: AppColors.income),
                    ...(exams.where((e) => e.done).toList()..sort((a, b) => b.date.compareTo(a.date)))
                        .map((e) => _examCard(repo, e, taken: true)),
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

/// Month calendar that highlights days a class was logged (green).
class _TaughtCalendar extends StatelessWidget {
  const _TaughtCalendar({
    required this.taughtKeys, required this.start, required this.end,
    required this.label, this.onShift, this.onTapDay, this.absentKeys = const {}});
  final Set<String> taughtKeys;
  final Set<String> absentKeys; // days missed (batch attendance)
  final DateTime start, end; // the student's billing month (e.g. 17 Mar – 16 Apr)
  final String label;
  final void Function(int)? onShift;
  final void Function(DateTime)? onTapDay;

  @override
  Widget build(BuildContext context) {
    final offset = start.weekday - 1; // Monday = 0
    final todayKey = dateKey(DateTime.now());
    final days = <DateTime>[];
    for (var d = DateTime(start.year, start.month, start.day);
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      days.add(d);
    }
    final count = days.where((d) => taughtKeys.contains(dateKey(d))).length;

    final cells = <Widget>[
      for (var i = 0; i < offset; i++) const SizedBox(),
    ];
    for (final date in days) {
      final key = dateKey(date);
      final taught = taughtKeys.contains(key);
      final absent = absentKeys.contains(key) && !taught;
      final isToday = key == todayKey;
      cells.add(GestureDetector(
        onTap: () => onTapDay?.call(date),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: taught ? AppColors.income : (absent ? AppColors.expense : Colors.transparent),
            shape: BoxShape.circle,
            border: isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: Text('${date.day}', style: TextStyle(
            color: (taught || absent) ? Colors.white : null,
            fontWeight: taught ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          )),
        ),
      ));
    }

    return PadCard(
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: () => onShift?.call(-1), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(label, textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700))),
          IconButton(onPressed: () => onShift?.call(1), icon: const Icon(Icons.chevron_right)),
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
          Text('Taught $count ${count == 1 ? 'day' : 'days'} · $label',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (days.any((d) => absentKeys.contains(dateKey(d)) && !taughtKeys.contains(dateKey(d)))) ...[
            const SizedBox(width: 10),
            Container(width: 12, height: 12,
                decoration: const BoxDecoration(color: AppColors.expense, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('Absent'),
          ],
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

String _ord(int n) => (n % 100 >= 11 && n % 100 <= 13)
    ? 'th'
    : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };

/// "Studying 3 mo 12 d (104 days)" — from the first class (or when the student was
/// added) up to today, or up to the day they left.
String _studyingFor(Student s, List<ClassLog> logs) {
  var start = s.createdAt;
  for (final l in logs) {
    if (l.date.isBefore(start)) start = l.date;
  }
  final end = s.isCurrent ? DateTime.now() : (s.leftDate ?? DateTime.now());
  final a = DateTime(start.year, start.month, start.day);
  final b = DateTime(end.year, end.month, end.day);
  final days = b.difference(a).inDays;
  if (days < 0) return 'Started ${fullDate(a)}';
  var months = (b.year - a.year) * 12 + b.month - a.month;
  if (b.day < a.day) months--;
  final rest = b.difference(DateTime(a.year, a.month + months, a.day)).inDays;
  final span = months > 0 ? '$months mo $rest d' : '$days d';
  return '${s.isCurrent ? 'Studying' : 'Studied'} $span ($days days)';
}
