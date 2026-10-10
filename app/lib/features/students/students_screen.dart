import 'dart:convert';

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
import 'batch_screen.dart';
import '../payments/payments_screen.dart' show showFeeSheet, feeStatusColor, feeStatusLabel, cycleLabel;
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

  /// Every billing month the student has been with you: classes, due, paid, status.
  Widget _monthHistory(BuildContext context, WidgetRef ref, Repo repo, Student s, List<ClassLog> logs) {
    var start = s.createdAt;
    for (final l in logs) {
      if (l.date.isBefore(start)) start = l.date;
    }
    if (s.billingStartDate != null) start = s.billingStartDate!;
    final first = repo.cycleMonthOf(s, start);
    final last = s.isCurrent
        ? repo.currentCycleMonth(s)
        : repo.cycleMonthOf(s, s.leftDate ?? DateTime.now());
    final months = <DateTime>[];
    for (var m = last; !m.isBefore(first) && months.length < 60; m = DateTime(m.year, m.month - 1)) {
      months.add(m);
    }
    if (months.isEmpty) return const PadCard(child: Text('No months yet.'));
    return PadCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(children: [
        for (final m in months)
          Builder(builder: (context) {
            final st = repo.payState(s, m);
            final classes = repo.classesInMonth(s, m);
            final color = feeStatusColor(st.status);
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              onTap: () => showFeeSheet(context, ref, s, m),
              title: Text(monthLabel(m), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '$classes ${classes == 1 ? 'class' : 'classes'} · due ${taka(st.due)}'
                  '${st.carry > 0.5 ? ' + ${taka(st.carry)} previous' : ''} · paid ${taka(st.paid)}'
                  '${s.billingDay != 1 ? '\n${cycleLabel(repo, s, m)}' : ''}'),
              isThreeLine: s.billingDay != 1,
              trailing: Chip(
                label: Text(feeStatusLabel(st.status),
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                backgroundColor: color, visualDensity: VisualDensity.compact),
            );
          }),
      ]),
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
          animation: Listenable.merge([repo.studentsL, repo.logsL, repo.paymentsL, repo.examsL, repo.schedulesL, repo.absencesL, repo.routinesL]),
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
            final cycle = repo.currentCycleMonth(s);
            final fee = repo.payState(s, cycle);
            final totalReceived = repo.paymentList
                .where((p) => p.studentId == id)
                .fold(0.0, (sum, p) => sum + p.paid);
            final paid = fee.status == 'paid';
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
                  Row(children: [
                    Expanded(child: FilledButton.tonalIcon(
                      onPressed: () => context.push('/class-log', extra: id),
                      icon: const Icon(Icons.edit_note), label: const Text('Log Class'))),
                    Gap.m,
                    Expanded(child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: feeStatusColor(fee.status)),
                      onPressed: () => showFeeSheet(context, ref, s, cycle),
                      icon: Icon(paid ? Icons.check_circle : Icons.attach_money),
                      label: Text(paid ? 'Fee Paid' : fee.status == 'partial' ? 'Partial' : 'Collect Fee'))),
                  ]),
                  Gap.l,
                  SectionTitle('Routine pictures', icon: Icons.photo_library_outlined, color: AppColors.savings,
                      trailing: TextButton.icon(
                          onPressed: () => addRoutineFromGallery(context, ref, studentId: id),
                          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                          label: const Text('Add'))),
                  _routinesFor(context, repo, id),
                  Gap.l,
                  const SectionTitle('Month by month', icon: Icons.calendar_month, color: AppColors.primary),
                  _monthHistory(context, ref, repo, s, logs),
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

/// Editable controllers for one guardian row in the student form.
class _GuardianEntry {
  _GuardianEntry([Guardian? g])
      : name = TextEditingController(text: g?.name ?? ''),
        phone = TextEditingController(text: g?.phone ?? ''),
        relation = TextEditingController(text: g?.relation ?? '');
  final TextEditingController name, phone, relation;
  Guardian get value => Guardian(
      name: name.text.trim(), phone: phone.text.trim(), relation: relation.text.trim());
  void dispose() {
    name.dispose();
    phone.dispose();
    relation.dispose();
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
    'Math', 'Higher Math', 'Physics', 'Chemistry', 'ICT',
  ];
  static const _perMonthOptions = [4, 8, 12, 16, 20, 24, 30];
  DateTime? _billingStart; // picked "month starts on" date
  bool _payPerClass = false;

  Future<void> _customPerMonth() async {
    final c = TextEditingController(text: '$_perMonth');
    final n = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Classes per month'),
      content: TextField(controller: c, autofocus: true, keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'e.g. 10')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(c.text.trim()) ?? 0;
            Navigator.pop(ctx, v > 0 && v <= 60 ? v : null);
          },
          child: const Text('Set')),
      ],
    ));
    if (n != null) setState(() => _perMonth = n);
  }

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _institution = TextEditingController();
  final _fee = TextEditingController();
  final _batch = TextEditingController();
  final List<_GuardianEntry> _guardians = [];
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
        _batch.text = s.batch;
        _institution.text = s.institution;
        _fee.text = s.monthlyFee == 0 ? '' : s.monthlyFee.toStringAsFixed(0);
        for (final g in s.guardians) {
          _guardians.add(_GuardianEntry(g));
        }
        for (final p in s.extraPhones) {
          _extraPhones.add(TextEditingController(text: p));
        }
        _photo = s.photo;
        _perMonth = s.classesPerMonth == 0 ? 8 : s.classesPerMonth;
        _billingStart = s.billingStartDate;
        _payPerClass = s.payPerClass;
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
    if (_guardians.isEmpty) _guardians.add(_GuardianEntry());
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
      billingDay: _billingStart?.day ?? 1,
      billingStart: _billingStart == null ? '' : dateKey(_billingStart!),
      payPerClass: _payPerClass,
      defaultTimeMinutes: _defaultTime.hour * 60 + _defaultTime.minute,
      colorValue: _colorValue,
      photo: _photo,
      subjects: _subjects.toList(),
      days: weekdayNames.where((d) => _days.contains(d)).toList(),
      weakSubjects: const [],
      extraPhones: _extraPhones.map((c) => c.text.trim()).where((x) => x.isNotEmpty).toList(),
      guardians: _guardians.map((g) => g.value).where((g) => !g.isEmpty).toList(),
      batch: _batch.text.trim(),
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
          Gap.m,
          _text(_batch, 'Batch (optional)'),
          if (ref.read(repoProvider).batchNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 0, children: [
                for (final b in ref.read(repoProvider).batchNames)
                  ActionChip(
                    label: Text(b),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: () => setState(() => _batch.text = b)),
              ]),
            ),
          Gap.l,
          _chips('Subjects', _subjects),
          Gap.l,
          DropdownButtonFormField<int>(
            key: ValueKey(_payPerClass),
            initialValue: _payPerClass ? -2 : _perMonth,
            decoration: const InputDecoration(labelText: 'Classes per month'),
            items: [
              ...({..._perMonthOptions, _perMonth}.toList()..sort()).map((n) =>
                  DropdownMenuItem(value: n, child: Text('$n classes / month'))),
              const DropdownMenuItem(value: -1, child: Text('Custom…')),
              const DropdownMenuItem(value: -2, child: Text('Per day (pay per class)')),
            ],
            onChanged: (v) {
              if (v == -1) {
                _customPerMonth();
              } else if (v == -2) {
                setState(() => _payPerClass = true);
              } else {
                setState(() { _payPerClass = false; _perMonth = v ?? 8; });
              }
            },
          ),
          Gap.m,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_repeat),
            title: const Text('Month starts on'),
            subtitle: Text(_billingStart == null
                ? '1st of every month (calendar month)'
                : '${fullDate(_billingStart!)} · every month from the ${_billingStart!.day}${_ord(_billingStart!.day)}'),
            trailing: _billingStart == null
                ? const Icon(Icons.calendar_today, size: 20)
                : IconButton(
                    tooltip: 'Use calendar month',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _billingStart = null)),
            onTap: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: _billingStart ?? DateTime.now(),
                  firstDate: DateTime(2020), lastDate: DateTime(2100),
                  helpText: 'Pick the day this student\'s month starts');
              if (d != null) setState(() => _billingStart = DateTime(d.year, d.month, d.day));
            },
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
          // all seven days in a single row
          Row(children: weekdayNames.map((d) => Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FilterChip(
                  label: SizedBox(width: double.infinity,
                      child: Text(d, textAlign: TextAlign.center, maxLines: 1,
                          style: const TextStyle(fontSize: 12))),
                  labelPadding: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  selected: _days.contains(d),
                  onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
                ),
              ))).toList()),
          Gap.m,
          const Text('Card colour', style: TextStyle(fontWeight: FontWeight.w600)),
          Gap.s,
          _colorGrid(),
          Gap.m,
          _text(_fee, _payPerClass ? 'Fee per class (৳)' : 'Monthly fee (৳)', number: true),
          Gap.m,
          _text(_phone, 'Student phone', number: true,
              onPickContact: () => _pickContact(_phone, nameTo: _name)),
          Gap.m,
          for (var i = 0; i < _guardians.length; i++) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
              decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Row(children: [
                  Text('Guardian ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Remove guardian',
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.expense),
                    onPressed: () => setState(() => _guardians.removeAt(i).dispose())),
                ]),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(children: [
                    _text(_guardians[i].name, 'Name'),
                    Gap.s,
                    _text(_guardians[i].relation, 'Relation (Father, Mother…)'),
                    Gap.s,
                    _text(_guardians[i].phone, 'Phone', number: true,
                        onPickContact: () => _pickContact(_guardians[i].phone, nameTo: _guardians[i].name)),
                  ]),
                ),
              ]),
            ),
          ],
          Align(alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _guardians.add(_GuardianEntry())),
              icon: const Icon(Icons.add), label: const Text('Add guardian'))),
          Gap.m,
          const Align(alignment: Alignment.centerLeft,
              child: Text('More student numbers', style: TextStyle(fontWeight: FontWeight.w600))),
          for (var i = 0; i < _extraPhones.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _extraPhones[i],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.+ ]'))],
                  decoration: InputDecoration(
                    labelText: 'Number',
                    suffixIcon: IconButton(
                      tooltip: 'Pick from contacts',
                      icon: const Icon(Icons.contacts_outlined),
                      onPressed: () => _pickContact(_extraPhones[i]))))),
                IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.expense),
                    onPressed: () => setState(() => _extraPhones.removeAt(i))),
              ]),
            ),
          Align(alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _extraPhones.add(TextEditingController())),
              icon: const Icon(Icons.add), label: const Text('Add student number'))),
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

  /// Pick a phone number from the device contacts (no permission needed:
  /// the system picker returns only the chosen contact). Fills [nameTo] when empty.
  Future<void> _pickContact(TextEditingController phone, {TextEditingController? nameTo}) async {
    try {
      final c = await FlutterNativeContactPicker().selectPhoneNumber();
      final number = (c?.selectedPhoneNumber ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
      if (number.isEmpty) return;
      setState(() {
        phone.text = number;
        if (nameTo != null && nameTo.text.trim().isEmpty) nameTo.text = c?.fullName ?? '';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open contacts')));
      }
    }
  }

  Widget _text(TextEditingController c, String label,
          {bool number = false, VoidCallback? onPickContact}) =>
      TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.+ ]'))] : null,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onPickContact == null
              ? null
              : IconButton(
                  tooltip: 'Pick from contacts',
                  icon: const Icon(Icons.contacts_outlined),
                  onPressed: onPickContact),
        ),
      );

  /// Built-in card colours (13 + the custom picker = two full rows of 7).
  static const _cardColors = <Color>[
    Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF43F5E), Color(0xFFF59E0B),
    Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF14B8A6),
    Color(0xFFF97316), Color(0xFF06B6D4), Color(0xFF84CC16), Color(0xFF0EA5E9),
    Color(0xFFB45309),
  ];

  Widget _colorGrid() {
    final cells = <Widget>[
      _customSwatch(),
      for (final c in _cardColors) _swatch(c),
    ];
    return Column(children: [
      for (var r = 0; r < cells.length; r += 7)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            for (var k = r; k < r + 7; k++)
              Expanded(child: Center(child: k < cells.length ? cells[k] : const SizedBox())),
          ]),
        ),
    ]);
  }

  bool get _isCustomColor =>
      _colorValue != 0 && !_cardColors.any((c) => c.toARGB32() == _colorValue);

  /// First swatch: opens the colour picker. Shows the chosen custom colour once set.
  Widget _customSwatch() {
    final custom = _isCustomColor ? Color(_colorValue) : null;
    return GestureDetector(
      onTap: () async {
        final c = await showDialog<Color>(
            context: context,
            builder: (_) => _ColorPickerDialog(initial: custom ?? _cardColors.first));
        if (c != null) setState(() => _colorValue = c.toARGB32());
      },
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: custom == null
              ? const SweepGradient(colors: [
                  Colors.red, Colors.yellow, Colors.green, Colors.cyan,
                  Colors.blue, Colors.purple, Colors.red])
              : null,
          color: custom,
          border: Border.all(color: custom != null ? Colors.white : Colors.transparent, width: 3),
          boxShadow: custom != null ? [BoxShadow(color: custom, blurRadius: 0, spreadRadius: 1)] : null,
        ),
        alignment: Alignment.center,
        child: Icon(custom == null ? Icons.colorize : Icons.check, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _swatch(Color color) {
    final val = color.toARGB32();
    final sel = _colorValue == val;
    return GestureDetector(
      // tap the selected colour again to go back to automatic
      onTap: () => setState(() => _colorValue = sel ? 0 : val),
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 3),
          boxShadow: sel ? [BoxShadow(color: color, blurRadius: 0, spreadRadius: 1)] : null,
        ),
        alignment: Alignment.center,
        child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
      ),
    );
  }
}

/// Simple colour picker: hue / saturation / brightness sliders + hex code.
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});
  final Color initial;
  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final _hex = TextEditingController(text: _hexOf(widget.initial));

  static String _hexOf(Color c) =>
      (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  void _set(HSVColor h) {
    setState(() => _hsv = h);
    _hex.text = _hexOf(h.toColor());
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return AlertDialog(
      title: const Text('Custom colour'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 56, decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12))),
        const SizedBox(height: 8),
        Slider(
          value: _hsv.hue, min: 0, max: 360,
          activeColor: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
          onChanged: (v) => _set(_hsv.withHue(v))),
        Slider(
          value: _hsv.saturation, min: 0, max: 1,
          onChanged: (v) => _set(_hsv.withSaturation(v))),
        Slider(
          value: _hsv.value, min: 0, max: 1,
          onChanged: (v) => _set(_hsv.withValue(v))),
        TextField(
          controller: _hex,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]'))],
          decoration: const InputDecoration(prefixText: '# ', labelText: 'Hex code', counterText: ''),
          onChanged: (v) {
            if (v.length == 6) {
              setState(() => _hsv = HSVColor.fromColor(Color(0xFF000000 | int.parse(v, radix: 16))));
            }
          },
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, color), child: const Text('Use')),
      ],
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
      appBar: AppBar(title: Text(editing ? 'Edit Class Log' : 'Log Class'), toolbarHeight: 48),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), children: [
          DropdownButtonFormField<String>(
            initialValue: _studentId,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Student', isDense: true),
            items: students.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
            onChanged: (v) => setState(() => _studentId = v),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(fullDate(_date)),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _date,
                    firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setState(() => _date = d);
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.access_time, size: 16),
              label: Text(_time.format(context)),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
            )),
          ]),
          const SizedBox(height: 6),
          if (subjOpts.isNotEmpty) ...[
            Wrap(spacing: 6, runSpacing: 0, children: subjOpts.map((s) => FilterChip(
                  label: Text(s), selected: _logSubjects.contains(s),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (v) => setState(() => v ? _logSubjects.add(s) : _logSubjects.remove(s)),
                )).toList()),
            const SizedBox(height: 8),
          ],
          _field(_topics, 'Today covered (topics)'),
          Wrap(spacing: 6, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Homework:', style: TextStyle(fontWeight: FontWeight.w600)),
            for (final h in const ['MCQ', 'CQ', 'Exercise', 'Page', 'Practice', 'Memorize', 'Worksheet'])
              FilterChip(
                label: Text(h),
                selected: _hwTypes.contains(h),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (v) => setState(() => v ? _hwTypes.add(h) : _hwTypes.remove(h))),
          ]),
          const SizedBox(height: 8),
          _field(_homework, 'Homework details (e.g. page 29-48)'),
          _field(_learned, 'What student learned / could do'),
          _field(_notDone, 'Not done / weak points'),
          _field(_nextPlan, 'Next class plan'),
          Row(children: [
            Text('Performance ${_perf.round()}/10', style: const TextStyle(fontWeight: FontWeight.w600)),
            Expanded(child: Slider(value: _perf, min: 0, max: 10, divisions: 10,
                label: '${_perf.round()}', onChanged: (v) => setState(() => _perf = v))),
          ]),
          _field(_remarks, "Today's comment"),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: FilledButton(onPressed: _save, child: Text(editing ? 'Update Log' : 'Save Log')),
        ),
      ),
    );
  }

  /// Compact field: one line that grows up to 3 as you type.
  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(controller: c, minLines: 1, maxLines: 3,
            decoration: InputDecoration(labelText: label, isDense: true)),
      );
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
