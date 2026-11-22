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
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';
import '../exams/exams_screen.dart';
import '../schedule/routines_screen.dart' show addRoutineFromGallery, RoutineViewer;
import 'batch_detail_screen.dart';
import 'busy_time.dart';
import 'mark_paid_sheet.dart';
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
        title: Text(tr('Tuition')),
        actions: [
          TextButton.icon(
              onPressed: () => context.push('/students/payments'),
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: Text(tr('Pay'))),
          TextButton.icon(
              onPressed: () => context.push('/students/history'),
              icon: const Icon(Icons.history, size: 18),
              label: Text(tr('History'))),
          TextButton.icon(
              onPressed: () => context.push('/students/exams'),
              icon: const Icon(Icons.event_note, size: 18),
              label: Text(tr('Exams'))),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: tr('Search students…'), prefixIcon: const Icon(Icons.search)),
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
                        ButtonSegment(value: false, label: Text(tr('Current ({n})', {'n': current})),
                            icon: const Icon(Icons.person, size: 18)),
                        ButtonSegment(value: true, label: Text(tr('All students ({n})', {'n': all.length})),
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
                          label: Text(tr('All batches')),
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
                    Expanded(child: Text(tr('Open batch · attendance, payments, members'),
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
                          ? tr('No match.')
                          : none
                              ? tr('No students yet.\nTap Add to create a student or a batch.')
                              : tr('No current students.\nOpen "All students" to see previous ones.'),
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
                                  s.leftDate == null ? tr('Previous') : tr('Previous · left {d}', {'d': fullDate(s.leftDate!)}),
                                  color: AppColors.expense),
                            InfoChip(Icons.menu_book, tr(classes == 1 ? '{n} class' : '{n} classes', {'n': classes}), color: AppColors.primary),
                            if (!s.isCurrent)
                              const SizedBox.shrink()
                            else if (next != null)
                              InfoChip(Icons.schedule,
                                  tr('Next: {t}', {'t': '${weekdayNames[next.dayOfWeek]}${next.isDated ? ' ${shortDate(next.dateOn!)}' : ''} ${minutesToTime(next.startMinutes)}'}),
                                  color: AppColors.savings)
                            else
                              InfoChip(Icons.schedule, tr('No class set'), color: AppColors.warning),
                          ]),
                          if (last != null && last.topics.isNotEmpty) ...[
                            Gap.s,
                            Text(tr('Last: {t}', {'t': last.topics}),
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
              title: Text(tr('Add Student')),
              subtitle: Text(tr('One student')),
              onTap: () { Navigator.pop(ctx); context.push('/student-form'); },
            ),
            ListTile(
              leading: const Icon(Icons.groups_2_outlined),
              title: Text(tr('Add Batch')),
              subtitle: Text(tr('A group: shared fee, days & time, many students')),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BatchFormScreen()));
              },
            ),
            const SizedBox(height: 8),
          ])),
        ),
        icon: const Icon(Icons.add),
        label: Text(tr('Add')),
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
  int _tab = 0; // 0 Overview · 1 Classes · 2 Payments · 3 Info
  bool _showTaken = false; // taken exams expanded
  bool _showTitle = false; // name in the app bar once the header scrolls away
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > 140;
      if (show != _showTitle) setState(() => _showTitle = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// Every saved phone number with a label (guardians first).
  List<(String, String)> _phonesOf(Student s) => [
        for (final g in s.guardians.where((g) => g.phone.isNotEmpty))
          ([g.relation.isNotEmpty ? g.relation : 'Guardian', if (g.name.isNotEmpty) g.name].join(' · '),
              g.phone),
        if (s.phone.isNotEmpty) ('Student', s.phone),
        for (final p in s.extraPhones.where((p) => p.isNotEmpty)) ('Student', p),
      ];

  /// Runs [run] with a phone number; asks which one when there are several.
  Future<void> _withPhone(List<(String, String)> phones, void Function(String) run) async {
    if (phones.length == 1) return run(phones.first.$2);
    final p = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in phones)
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: Text(e.$1),
            subtitle: Text(e.$2),
            onTap: () => Navigator.pop(c, e.$2)),
        Gap.s,
      ])),
    );
    if (p != null && mounted) run(p);
  }

  final _topKey = GlobalKey(); // header + actions + tiles, above the sticky tabs

  void _setTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    // when the tabs are pinned, show the new tab from its start
    final box = _topKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    final top = box.size.height + 12; // + the sliver's top/bottom padding
    if (_scroll.offset > top) _scroll.jumpTo(top);
  }

  Widget _empty(IconData icon, String text, {String? cta, VoidCallback? onCta}) {
    final hint = Theme.of(context).hintColor;
    return PadCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(children: [
        Icon(icon, color: hint, size: 22),
        Gap.m,
        Expanded(child: Text(text, style: TextStyle(color: hint))),
        if (cta != null) TextButton(onPressed: onCta, child: Text(cta)),
      ]),
    );
  }

  /// Label → value row used in the info / fee cards.
  Widget _kv(String k, String v, {Color? color, bool bold = false, VoidCallback? onTap}) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13.5)),
        Gap.l,
        Expanded(child: Text(v, textAlign: TextAlign.end,
            style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: bold ? 15 : 14, color: color))),
        if (onTap != null) Icon(Icons.chevron_right, size: 18, color: Theme.of(context).hintColor),
      ]),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }

  String _whenLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    final t = minutesToTime(d.hour * 60 + d.minute);
    if (diff == 0) return 'Today $t';
    if (diff == 1) return 'Tomorrow $t';
    return '${weekdayNames[d.weekday - 1]} ${shortDate(d)} · $t';
  }

  /// Gradient profile header: big avatar, name, class/institution, status pills.
  Widget _header(Student s) {
    final sub = [s.grade, s.institution].where((e) => e.isNotEmpty).join(' · ');
    Widget pill(IconData icon, String text, {VoidCallback? onTap}) {
      final p = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      );
      return onTap == null ? p : GestureDetector(onTap: onTap, child: p);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGrad,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: StudentAvatar(s, radius: 34),
        ),
        Gap.l,
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800, height: 1.15)),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5)),
          ],
          Gap.s,
          Wrap(spacing: 6, runSpacing: 6, children: [
            pill(s.isCurrent ? Icons.check_circle : Icons.history,
                s.isCurrent
                    ? 'Current'
                    : (s.leftDate == null ? 'Previous' : 'Left ${shortDate(s.leftDate!)}')),
            pill(Icons.payments_outlined,
                s.payPerClass ? '${taka(s.monthlyFee)}/class' : '${taka(s.monthlyFee)}/mo'),
            if (s.batch.isNotEmpty)
              pill(Icons.groups_2_outlined, s.batch,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => BatchDetailScreen(batch: s.batch)))),
          ]),
        ])),
      ]),
    );
  }

  /// Tidy row of the most-used actions.
  Widget _quickActions(Repo repo, Student s, List<(String, String)> phones) {
    Widget act(IconData icon, String label, Color c, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: c, size: 22),
                ),
                const SizedBox(height: 6),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
    return PadCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(children: [
        if (phones.isNotEmpty) ...[
          act(Icons.call, 'Call', AppColors.income,
              () => _withPhone(phones, (p) => _launchUri(context, Uri(scheme: 'tel', path: p)))),
          act(Icons.chat, 'WhatsApp', _waGreen,
              () => _withPhone(phones, (p) => _launchUri(context, Uri.parse('https://wa.me/${_waNumber(p)}')))),
          act(Icons.sms_outlined, 'SMS', AppColors.savings,
              () => _withPhone(phones, (p) => _launchUri(context, Uri(scheme: 'sms', path: p)))),
        ],
        act(Icons.edit_note, 'Log class', AppColors.primary,
            () => context.push('/class-log', extra: s.id)),
        act(Icons.price_check, 'Mark paid', paidClassColor, () => showMarkPaidSheet(context, repo, s)),
        if (phones.isEmpty)
          act(Icons.add_alarm, 'Schedule', AppColors.warning,
              () => openScheduleSheet(context, ref, presetStudentId: s.id)),
        act(Icons.edit_outlined, 'Edit', AppColors.info, () => context.push('/student-form', extra: s.id)),
      ]),
    );
  }

  /// One class log: date block, subject/time, paid status, notes. Swipe right toggles paid.
  Widget _logCard(Repo repo, Student s, ClassLog l, {bool swipe = true}) {
    final hint = Theme.of(context).hintColor;
    final paid = l.isPaid;
    final accent = paid ? paidClassColor : AppColors.warning;
    final d = l.date;
    Widget line(String k, String v, Color c) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$k  ', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12.5)),
            TextSpan(text: v, style: const TextStyle(fontSize: 13.5)),
          ])),
        );
    final card = PadCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/class-log', extra: l),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Column(children: [
            Text(weekdayNames[d.weekday - 1].toUpperCase(),
                style: TextStyle(color: accent, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            Text('${d.day}', style: TextStyle(color: accent, fontSize: 21, fontWeight: FontWeight.w800, height: 1.15)),
            Text(_mon[d.month - 1], style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
        Gap.m,
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l.subject.isNotEmpty ? l.subject : 'Class',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            paid
                ? const InfoChip(Icons.check_circle, 'Paid', color: paidClassColor)
                : const InfoChip(Icons.schedule, 'Unpaid', color: AppColors.warning),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.access_time, size: 13, color: hint),
            const SizedBox(width: 4),
            Text(TimeOfDay.fromDateTime(d).format(context), style: TextStyle(color: hint, fontSize: 12.5)),
            const SizedBox(width: 10),
            const Icon(Icons.star_rounded, size: 15, color: Color(0xFFC3C6FF)),
            const SizedBox(width: 2),
            Text('${l.performance}/10', style: const TextStyle(
                color: Color(0xFFC3C6FF), fontWeight: FontWeight.w700, fontSize: 12.5)),
            const Spacer(),
            Icon(Icons.edit_outlined, size: 15, color: hint),
          ]),
          if (l.topics.isNotEmpty) line('Covered', l.topics, AppColors.primary),
          if (l.homework.isNotEmpty) line('HW', l.homework, hint),
          if (l.learned.isNotEmpty) line('Learned', l.learned, AppColors.income),
          if (l.notDone.isNotEmpty) line('Pending', l.notDone, AppColors.expense),
          if (l.nextPlan.isNotEmpty) line('Next', l.nextPlan, AppColors.savings),
          if (l.remarks.isNotEmpty) line('Note', l.remarks, hint),
        ])),
      ]),
    );
    if (!swipe) return card;
    final to = paid ? AppColors.warning : paidClassColor;
    return Dismissible(
      key: ValueKey('log-${l.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
            color: to.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Icon(paid ? Icons.undo : Icons.price_check, color: to),
          Gap.s,
          Text(paid ? 'Mark unpaid' : 'Mark paid',
              style: TextStyle(color: to, fontWeight: FontWeight.w700)),
        ]),
      ),
      confirmDismiss: (_) async {
        await repo.setLogPaid(s, l, !paid);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(paid ? 'Payment undone' : 'Marked paid')));
        }
        return false; // keep the card; it just changes colour
      },
      child: card,
    );
  }

  /// "Due now" card for the selected cycle (with ‹ › to move between cycles).
  Widget _payCard(Student s, DateTime month, String cycleName,
      ({double due, double paid, double carry, double total, double remaining, String status}) ps) {
    final hint = Theme.of(context).hintColor;
    final clear = ps.remaining <= 0.5;
    final nothing = ps.total <= 0.5 && ps.paid <= 0;
    final (statusText, statusColor, statusIcon) = nothing
        ? ('Nothing due', hint, Icons.remove_circle_outline)
        : switch (ps.status) {
            'paid' => ('Paid', AppColors.income, Icons.check_circle),
            'partial' => ('Partly paid', AppColors.warning, Icons.timelapse),
            _ => ('Pending', AppColors.expense, Icons.error_outline),
          };
    final progress = ps.total <= 0 ? (ps.paid > 0 ? 1.0 : 0.0) : (ps.paid / ps.total).clamp(0.0, 1.0);
    return PadCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconButton(icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _monthSel = DateTime(month.year, month.month - 1))),
        Expanded(child: Column(children: [
          Text('DUE NOW', style: TextStyle(color: hint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          Text(cycleName, style: const TextStyle(fontWeight: FontWeight.w700)),
        ])),
        IconButton(icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _monthSel = DateTime(month.year, month.month + 1))),
      ]),
      Gap.s,
      Center(child: Text(taka(ps.remaining), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
          color: clear ? AppColors.income : AppColors.expense))),
      Gap.xs,
      Center(child: InfoChip(statusIcon, statusText, color: statusColor)),
      Gap.l,
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          backgroundColor: AppColors.income.withValues(alpha: 0.15),
          valueColor: const AlwaysStoppedAnimation(AppColors.income),
        ),
      ),
      Gap.s,
      _kv('Fee this cycle', taka(ps.due)),
      if (ps.carry.abs() > 0.5)
        _kv(ps.carry > 0 ? 'Carried from before' : 'Advance from before', taka(ps.carry.abs()),
            color: ps.carry > 0 ? AppColors.expense : AppColors.income),
      _kv('Paid this cycle', taka(ps.paid), color: AppColors.income),
      const Divider(height: 12),
      _kv('Total payable', taka(ps.total), bold: true),
    ]));
  }

  /// Routine pictures linked to this student (added here or from the Routines screen).
  Widget _routinesFor(BuildContext context, Repo repo, String sid) {
    final list = repo.routinesFor(sid);
    if (list.isEmpty) {
      return _empty(Icons.photo_outlined, 'No routine picture yet.');
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
      return _empty(Icons.event_busy_outlined, 'No classes scheduled.');
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
    return AnimatedBuilder(
      animation: Listenable.merge([repo.studentsL, repo.logsL, repo.paymentsL, repo.examsL, repo.schedulesL, repo.absencesL, repo.routinesL, repo.busytimesL]),
      builder: (context, _) {
        final s = repo.student(id);
        if (s == null) {
          return const Scaffold(body: SafeArea(child: Center(child: Text('Student not found'))));
        }
        final hint = Theme.of(context).hintColor;
        final logs = repo.logsFor(id);
        final last = repo.lastLog(id);
        final exams = repo.examsFor(id);
        final phones = _phonesOf(s);
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
        final ps = repo.payState(s, month);
        final paidN = monthLogs.where((l) => l.isPaid).length;
        final unpaidAll = logs.where((l) => !l.isPaid).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final nextAt = s.isCurrent ? repo.nextClassTime(id) : null;
        final upcoming = exams.where((e) => !e.done).toList();
        final taken = exams.where((e) => e.done).toList()..sort((a, b) => b.date.compareTo(a.date));
        final nextExam = (upcoming.where((e) => !e.date.isBefore(DateTime.now())).toList()
              ..sort((a, b) => a.date.compareTo(b.date)))
            .firstOrNull;

        // ---------- tab contents ----------
        final overview = <Widget>[
          SectionTitle('Last class', icon: Icons.history_edu, color: AppColors.primary,
              trailing: logs.isEmpty ? null : TextButton(
                  onPressed: () => _setTab(1), child: const Text('All classes'))),
          if (last == null)
            _empty(Icons.edit_note, 'No classes logged yet.',
                cta: 'Log class', onCta: () => context.push('/class-log', extra: id))
          else
            _logCard(repo, s, last),
          Gap.l,
          SectionTitle('Scheduled classes', icon: Icons.event_available, color: AppColors.savings,
              trailing: TextButton.icon(
                  onPressed: () => openScheduleSheet(context, ref, presetStudentId: id),
                  icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
          _scheduledFor(context, ref, repo, s),
          Gap.l,
          SectionTitle('Exams', icon: Icons.event, color: AppColors.warning,
              trailing: TextButton.icon(
                  onPressed: () => showExamSheet(context, studentId: id),
                  icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
          if (upcoming.isEmpty)
            _empty(Icons.event_note_outlined, 'No upcoming exams.')
          else
            ...upcoming.map((e) => _examCard(repo, e)),
          if (taken.isNotEmpty) ...[
            Gap.s,
            PadCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              onTap: () => setState(() => _showTaken = !_showTaken),
              child: Row(children: [
                const IconBadge(icon: Icons.history, color: AppColors.income, size: 30),
                Gap.m,
                Expanded(child: Text('Taken exams (${taken.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
                Icon(_showTaken ? Icons.expand_less : Icons.expand_more, color: hint),
              ]),
            ),
            if (_showTaken) ...[
              Gap.s,
              ...taken.map((e) => _examCard(repo, e, taken: true)),
            ],
          ],
        ];

        final classes = <Widget>[
          SectionTitle('Attendance', icon: Icons.calendar_month, color: AppColors.income),
          _TaughtCalendar(
            taughtKeys: taughtKeys,
            paidKeys: {for (final l in logs) if (l.isPaid) dateKey(l.date)},
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
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text('Tap a day to add/edit · ‹ › changes the month (logs follow)',
                style: TextStyle(color: hint, fontSize: 12)),
          ),
          Gap.l,
          SectionTitle('Class logs · ${monthLogs.length}', icon: Icons.menu_book, color: AppColors.primary,
              trailing: TextButton.icon(
                  onPressed: () => showMarkPaidSheet(context, repo, s),
                  icon: const Icon(Icons.price_check, size: 18),
                  label: const Text('Mark paid'))),
          if (monthLogs.isEmpty)
            _empty(Icons.edit_note, 'No classes in $cycleName.',
                cta: 'Log class', onCta: () => context.push('/class-log', extra: id))
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Tap to edit · swipe right to mark paid / unpaid',
                  style: TextStyle(color: hint, fontSize: 12)),
            ),
            for (final l in monthLogs)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: _logCard(repo, s, l)),
          ],
        ];

        final payments = <Widget>[
          Gap.s,
          _payCard(s, month, cycleName, ps),
          Gap.m,
          Row(children: [
            Expanded(child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: paidClassColor,
                  minimumSize: const Size.fromHeight(48)),
              onPressed: () => showMarkPaidSheet(context, repo, s),
              icon: const Icon(Icons.price_check),
              label: const Text('Mark classes paid'))),
            Gap.s,
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => context.push('/students/history'),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('History')),
          ]),
          Gap.l,
          SectionTitle('Unpaid classes · ${unpaidAll.length}', icon: Icons.pending_actions,
              color: AppColors.warning),
          if (unpaidAll.isEmpty)
            _empty(Icons.check_circle_outline, logs.isEmpty ? 'No classes logged yet.' : 'Every class is paid.')
          else
            PadCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final (i, l) in unpaidAll.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.radio_button_unchecked, color: AppColors.warning),
                    title: Text(fullDate(l.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      weekdayNames[l.date.weekday - 1],
                      TimeOfDay.fromDateTime(l.date).format(context),
                      if (l.subject.isNotEmpty) l.subject,
                      taka(s.perClassFee),
                    ].join(' · ')),
                    onTap: () => context.push('/class-log', extra: l),
                    trailing: TextButton(
                      onPressed: () => repo.setLogPaid(s, l, true),
                      child: const Text('Mark paid')),
                  ),
                ],
              ]),
            ),
          Gap.l,
          SectionTitle('Fee plan', icon: Icons.receipt_long, color: AppColors.savings),
          PadCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: [
              _kv('Fee', s.payPerClass ? '${taka(s.monthlyFee)} per class' : '${taka(s.monthlyFee)} per month'),
              if (!s.payPerClass && s.classesPerMonth > 0) ...[
                _kv('Classes / month', '${s.classesPerMonth}'),
                _kv('Per class', taka(s.perClassFee)),
              ],
              _kv('Month starts', s.billingDay == 1 ? 'Calendar month' : '${s.billingDay}${_ord(s.billingDay)} of each month'),
              const Divider(height: 12),
              _kv('Total received', taka(totalReceived), color: AppColors.income, bold: true),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text('Tuition payments stay in student records only (not in Finance).',
                style: TextStyle(color: hint, fontSize: 12)),
          ),
        ];

        final days = weekdayNames.where((d) => s.days.contains(d)).join(', ');
        final info = <Widget>[
          SectionTitle('Contacts', icon: Icons.contact_phone_outlined, color: AppColors.income),
          if (phones.isEmpty)
            _empty(Icons.phone_disabled_outlined, 'No phone numbers saved.',
                cta: 'Edit', onCta: () => context.push('/student-form', extra: id))
          else
            PadCard(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Column(children: [
                for (final (i, p) in phones.indexed) ...[
                  if (i > 0) const Divider(height: 8),
                  _PhoneRow(label: p.$1, phone: p.$2),
                ],
              ]),
            ),
          Gap.l,
          SectionTitle('Profile', icon: Icons.person_outline, color: AppColors.primary),
          PadCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (s.grade.isNotEmpty) _kv('Class', s.grade),
              if (s.institution.isNotEmpty) _kv('Institution', s.institution),
              if (s.batch.isNotEmpty)
                _kv('Batch', s.batch, onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BatchDetailScreen(batch: s.batch)))),
              if (days.isNotEmpty) _kv('Days', days),
              _kv('With you', _studyingFor(s, logs)),
              _kv('Total classes', '${logs.length}'),
              if (!s.isCurrent && s.leftDate != null) _kv('Left on', fullDate(s.leftDate!)),
              if (s.subjects.isNotEmpty) ...[
                Gap.s,
                Text('Subjects', style: TextStyle(color: hint, fontSize: 13.5)),
                Gap.s,
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in s.subjects) InfoChip(Icons.menu_book, e, color: AppColors.primary),
                ]),
              ],
              if (s.weakSubjects.isNotEmpty) ...[
                Gap.m,
                Text('Needs focus', style: TextStyle(color: hint, fontSize: 13.5)),
                Gap.s,
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in s.weakSubjects) InfoChip(Icons.flag_outlined, e, color: AppColors.expense),
                ]),
              ],
              Gap.s,
            ]),
          ),
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
        ];

        // ---------- at-a-glance tiles ----------
        final dueClear = ps.remaining <= 0.5;
        final tiles = Column(children: [
          Row(children: [
            Expanded(child: _StatTile(
              icon: Icons.menu_book, color: AppColors.primary,
              value: '${monthLogs.length}',
              label: monthLogs.length == 1 ? 'Class' : 'Classes',
              sub: cycleName,
              onTap: () => _setTab(1))),
            Gap.m,
            Expanded(child: _StatTile(
              icon: Icons.account_balance_wallet_outlined,
              color: dueClear ? AppColors.income : AppColors.expense,
              valueColor: dueClear ? AppColors.income : AppColors.expense,
              value: taka(ps.remaining),
              label: 'Due now',
              sub: dueClear
                  ? 'All clear'
                  : ps.carry > 0.5 ? 'incl. ${taka(ps.carry)} carried' : 'of ${taka(ps.total)}',
              onTap: () => _setTab(2))),
          ]),
          Gap.m,
          Row(children: [
            Expanded(child: _StatTile(
              icon: Icons.price_check, color: paidClassColor,
              value: '$paidN/${monthLogs.length}',
              label: 'Paid classes',
              sub: unpaidAll.isEmpty ? 'All paid' : '${unpaidAll.length} unpaid in total',
              onTap: () => showMarkPaidSheet(context, repo, s))),
            Gap.m,
            Expanded(child: _StatTile(
              icon: Icons.schedule, color: AppColors.warning,
              value: nextAt == null ? 'Not set' : _whenLabel(nextAt),
              label: 'Next class',
              sub: nextExam == null
                  ? 'No upcoming exam'
                  : 'Exam ${shortDate(nextExam.date)} · ${nextExam.title}',
              onTap: nextAt == null
                  ? () => openScheduleSheet(context, ref, presetStudentId: id)
                  : () => _setTab(0))),
          ]),
        ]);

        final body = switch (_tab) { 1 => classes, 2 => payments, 3 => info, _ => overview };

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'logClass-$id',
            onPressed: () => context.push('/class-log', extra: id),
            icon: const Icon(Icons.edit_note),
            label: const Text('Log class'),
          ),
          body: SafeArea(
            child: CustomScrollView(controller: _scroll, slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                surfaceTintColor: Colors.transparent,
                title: AnimatedOpacity(
                  opacity: _showTitle ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Text(s.name)),
                actions: [
                  IconButton(icon: const Icon(Icons.add_alarm),
                      tooltip: 'Schedule class',
                      onPressed: () => openScheduleSheet(context, ref, presetStudentId: id)),
                  IconButton(
                      icon: Icon(s.isCurrent ? Icons.person_off_outlined : Icons.person_add_alt_1),
                      tooltip: s.isCurrent ? 'Mark as previous' : 'Mark as current',
                      onPressed: () => setStudentCurrent(context, ref, s, !s.isCurrent)),
                  IconButton(icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit student',
                      onPressed: () => context.push('/student-form', extra: id)),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                sliver: SliverToBoxAdapter(child: Column(key: _topKey, children: [
                  _header(s),
                  Gap.m,
                  _quickActions(repo, s, phones),
                  Gap.m,
                  tiles,
                  Gap.s,
                ])),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _DetailTabs(index: _tab, onChanged: _setTab),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                sliver: SliverList(delegate: SliverChildListDelegate(body)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Small at-a-glance tile on the student page.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.color, required this.value,
      required this.label, required this.sub, this.valueColor, this.onTap});
  final IconData icon;
  final Color color;
  final Color? valueColor;
  final String value, label, sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return PadCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon: icon, color: color, size: 34),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 28,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: valueColor)),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 1),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: hint, fontSize: 11.5)),
        ])),
      ]),
    );
  }
}

/// Sticky segmented control: Overview · Classes · Payments · Info.
class _DetailTabs extends SliverPersistentHeaderDelegate {
  const _DetailTabs({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;
  static const _labels = ['Overview', 'Classes', 'Payments', 'Info'];

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final stuck = shrinkOffset > 0 || overlapsContent;
    return Container(
      color: stuck ? cs.surface : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: dark ? AppColors.dSurfaceVariant : AppColors.lSurfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? AppColors.dOutline : AppColors.lOutline),
        ),
        child: Row(children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: i == index
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: Text(_labels[i], maxLines: 1, style: TextStyle(
                    fontSize: 13,
                    fontWeight: i == index ? FontWeight.w700 : FontWeight.w600,
                    color: i == index ? Colors.white : Theme.of(context).hintColor,
                  )),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DetailTabs old) => old.index != index || old.onChanged != onChanged;
}

/// Month calendar that highlights days a class was logged (green).
class _TaughtCalendar extends StatelessWidget {
  const _TaughtCalendar({
    required this.taughtKeys, required this.start, required this.end, this.paidKeys = const {},
    required this.label, this.onShift, this.onTapDay, this.absentKeys = const {}});
  final Set<String> taughtKeys;
  final Set<String> paidKeys; // classes whose payment is done
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
    Widget legend(Color c, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor)),
        ]);

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
            color: taught ? (paidKeys.contains(key) ? paidClassColor : AppColors.income) : (absent ? AppColors.expense : Colors.transparent),
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
        Text('Taught $count ${count == 1 ? 'day' : 'days'} · $label',
            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        Gap.s,
        Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 4, children: [
          legend(AppColors.income, 'Taught'),
          if (paidKeys.isNotEmpty) legend(paidClassColor, 'Paid'),
          if (days.any((d) => absentKeys.contains(dateKey(d)) && !taughtKeys.contains(dateKey(d))))
            legend(AppColors.expense, 'Absent'),
        ]),
      ]),
    );
  }
}

const _waGreen = Color(0xFF25D366);

/// Phone number in WhatsApp's wa.me form (Bangladeshi 01… numbers get 88).
String _waNumber(String phone) {
  var n = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (n.startsWith('+')) n = n.substring(1);
  if (n.startsWith('0')) n = '88$n';
  return n;
}

Future<void> _launchUri(BuildContext context, Uri uri) async {
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

// Phone row with call / SMS / WhatsApp actions.
class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.label, required this.phone});
  final String label, phone;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const IconBadge(icon: Icons.person_outline, color: AppColors.primary, size: 34),
      Gap.m,
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
        Text(phone, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
      ])),
      IconButton(visualDensity: VisualDensity.compact, tooltip: 'Call',
          icon: const Icon(Icons.call, color: AppColors.income, size: 20),
          onPressed: () => _launchUri(context, Uri(scheme: 'tel', path: phone))),
      IconButton(visualDensity: VisualDensity.compact, tooltip: 'SMS',
          icon: const Icon(Icons.sms, color: AppColors.savings, size: 20),
          onPressed: () => _launchUri(context, Uri(scheme: 'sms', path: phone))),
      IconButton(visualDensity: VisualDensity.compact, tooltip: 'WhatsApp',
          icon: const Icon(Icons.chat, color: _waGreen, size: 20),
          onPressed: () => _launchUri(context, Uri.parse('https://wa.me/${_waNumber(phone)}'))),
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
