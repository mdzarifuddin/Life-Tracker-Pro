import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/quick_add.dart';
import '../../core/theme.dart';
import '../../core/updater.dart';
import '../../core/widgets.dart';
import '../../models.dart';
import '../schedule/schedule_screen.dart';
import '../tasks/tasks_screen.dart';

/// Friendly empty state: soft icon + one line (optionally tappable).
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text, this.color, this.onTap});
  final IconData icon;
  final String text;
  final Color? color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return PadCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [
        IconBadge(icon: icon, color: color ?? hint, size: 34),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: hint, fontSize: 13.5))),
        if (onTap != null) Icon(Icons.chevron_right, color: hint, size: 20),
      ]),
    );
  }
}

/// Compact section header used on Home: small badge, title, optional count, "See all".
class _Section extends StatelessWidget {
  const _Section(this.title, {required this.icon, required this.color, this.badge, this.onAll});
  final String title;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback? onAll;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 0, 8),
        child: Row(children: [
          IconBadge(icon: icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Row(children: [
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700))),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge!, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ])),
          const SizedBox(width: 4),
          if (onAll != null)
            TextButton(
              onPressed: onAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('See all', style: TextStyle(fontSize: 13)),
                Icon(Icons.chevron_right, size: 18),
              ]),
            ),
        ]),
      );
}

/// Small at-a-glance chip under the greeting (value + label).
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.color, required this.value,
      required this.label, this.onTap});
  final IconData icon;
  final Color color;
  final String value, label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: cs.surface.withValues(alpha: dark ? 0.72 : 0.80),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: dark ? 0.30 : 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, maxLines: 1,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
              ),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            ])),
          ]),
        ),
      ),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    autoUpdateOnce(context);
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            repo.studentsL, repo.txnsL, repo.paymentsL, repo.schedulesL, repo.logsL,
            repo.thesisL, repo.examsL, repo.tasksL, repo.jobtasksL, repo.scheddoneL,
          ]),
          builder: (context, _) {
            final now = DateTime.now();
            final todays = repo.scheduleOnDate(now);
            final doneCount = todays.where((s) => repo.isSchedDone(s.id, now)).length;
            final tasks = repo.todayTasks;
            final pending = repo.pendingFees();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                _header(context, now),
                Gap.m,
                Row(children: [
                  Expanded(child: _StatChip(
                    icon: Icons.event_available, color: AppColors.savings,
                    value: todays.isEmpty ? '0' : '$doneCount/${todays.length}',
                    label: todays.length == 1 ? 'Class today' : 'Classes today',
                    onTap: () => context.go('/schedule'))),
                  const SizedBox(width: 8),
                  Expanded(child: _StatChip(
                    icon: Icons.checklist, color: AppColors.primary,
                    value: '${tasks.length}',
                    label: 'Tasks due',
                    onTap: () => context.go('/more/tasks'))),
                  const SizedBox(width: 8),
                  Expanded(child: _StatChip(
                    icon: Icons.account_balance_wallet_outlined,
                    color: pending > 0.5 ? AppColors.expense : AppColors.income,
                    value: pending > 0.5 ? taka(pending) : 'Clear',
                    label: 'Fees due',
                    onTap: () => context.go('/students/payments'))),
                ]),
                Gap.m,
                _quickActions(context, ref),
                _Section("Today's Schedule",
                    icon: Icons.calendar_today, color: AppColors.savings,
                    badge: todays.isEmpty ? null : '$doneCount/${todays.length} done',
                    onAll: () => context.go('/schedule')),
                if (todays.isEmpty)
                  const _EmptyHint(icon: Icons.celebration_outlined, color: AppColors.savings,
                      text: 'No classes today. Enjoy your day!')
                else
                  _todayAgenda(context, ref, repo, todays, now),
                ..._upcoming(context, ref, repo),
                _Section('My Tasks', icon: Icons.checklist, color: AppColors.primary,
                    badge: tasks.isEmpty ? null : '${tasks.length} due',
                    onAll: () => context.go('/more/tasks')),
                if (tasks.isEmpty)
                  _EmptyHint(icon: Icons.add_task, color: AppColors.primary,
                      text: 'No tasks due today. Tap to add one.',
                      onTap: () => showTaskSheet(context))
                else
                  _taskList(context, repo, tasks),
                _Section('Progress', icon: Icons.insights, color: AppColors.primary),
                Row(children: [
                  Expanded(child: _ProgressTile(
                    label: 'MSc Thesis', sub: 'Overall',
                    percent: repo.thesisProgress, color: AppColors.primary, icon: Icons.school,
                    onTap: () => context.go('/more/thesis'))),
                  Gap.m,
                  Expanded(child: _ProgressTile(
                    label: 'Govt Job', sub: 'Today',
                    percent: _jobPercent(repo), color: AppColors.savings, icon: Icons.account_balance,
                    onTap: () => context.go('/more/jobprep'))),
                ]),
                _Section('Upcoming Exams', icon: Icons.event, color: AppColors.warning,
                    onAll: () => context.go('/more/exams')),
                if (repo.upcomingExams.isEmpty)
                  const _EmptyHint(icon: Icons.event_available_outlined, color: AppColors.warning,
                      text: 'No upcoming exams.')
                else
                  _examList(context, repo),
              ],
            );
          },
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: () => showQuickAdd(context, ref),
        child: Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            gradient: AppColors.hero,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  /// Compact top: greeting, app name, date, update chip + menu. No hero card.
  Widget _header(BuildContext context, DateTime now) {
    final cs = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_greeting(now),
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant, letterSpacing: 0.2)),
        const SizedBox(height: 2),
        Text('Life Tracker Pro',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.15,
                color: cs.onSurface, letterSpacing: -0.3)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.today, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text('${DateFormat('EEEE').format(now)}, ${fullDate(now)}',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ]),
        ValueListenableBuilder<VersionStatus>(
          valueListenable: versionStatus,
          builder: (context, v, _) => !v.updateAvailable
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => installLatestVersion(context),
                    child: InfoChip(Icons.system_update,
                        'Update available: ${v.latest!.version} (you have v${v.installed})',
                        color: AppColors.income),
                  ),
                ),
        ),
      ])),
      Container(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
        ),
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Menu',
          onOpened: refreshVersionStatus,
          onSelected: (v) async {
            if (v == 'update') installLatestVersion(context);
            if (v == 'settings') context.go('/more/settings');
            if (v == 'about') {
              final pkg = await PackageInfo.fromPlatform();
              if (!context.mounted) return;
              showAboutDialog(
                context: context,
                applicationName: 'Life Tracker Pro',
                applicationVersion: 'Version ${pkg.version}',
                applicationIcon: const Icon(Icons.auto_awesome, color: AppColors.primary),
                children: const [Text('Manage tuition, finance, study & personal life — all in one place.')],
              );
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'update',
                child: ValueListenableBuilder<VersionStatus>(
                  valueListenable: versionStatus,
                  builder: (context, v, _) => ListTile(
                    leading: Icon(Icons.system_update,
                        color: v.updateAvailable ? AppColors.income : null),
                    title: Text(v.updateAvailable ? 'Install update' : 'Install latest version'),
                    subtitle: Text(v.label, style: TextStyle(
                        fontSize: 12,
                        color: v.updateAvailable ? AppColors.income : null)),
                    contentPadding: EdgeInsets.zero,
                  ),
                )),
            const PopupMenuItem(value: 'settings',
                child: ListTile(leading: Icon(Icons.settings), title: Text('Settings'), contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'about',
                child: ListTile(leading: Icon(Icons.info_outline), title: Text('App info'), contentPadding: EdgeInsets.zero)),
          ],
        ),
      ),
    ]);
  }

  /// Row of the most-used actions (same style as the student page).
  Widget _quickActions(BuildContext context, WidgetRef ref) {
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
        act(Icons.south_west, 'Expense', AppColors.expense,
            () => context.push('/txn-form', extra: 'expense')),
        act(Icons.north_east, 'Income', AppColors.income,
            () => context.push('/txn-form', extra: 'income')),
        act(Icons.add_task, 'Task', AppColors.primary, () => showTaskSheet(context)),
        act(Icons.add_alarm, 'Class', AppColors.savings, () => openScheduleSheet(context, ref)),
        act(Icons.payments_outlined, 'Fees', AppColors.warning,
            () => context.go('/students/payments')),
      ]),
    );
  }

  /// Today's classes as a timeline inside one card; highlights the current / next one.
  Widget _todayAgenda(BuildContext context, WidgetRef ref, Repo repo,
      List<ScheduleItem> todays, DateTime now) {
    final hint = Theme.of(context).hintColor;
    final nowMin = now.hour * 60 + now.minute;
    String? focusId;
    var focusIsNow = false;
    for (final s in todays) {
      if (repo.isSchedDone(s.id, now)) continue;
      if (s.startMinutes + s.durationMin <= nowMin) continue;
      focusId = s.id;
      focusIsNow = s.startMinutes <= nowMin;
      break;
    }
    final rows = <Widget>[];
    for (var i = 0; i < todays.length; i++) {
      final s = todays[i];
      final st = repo.student(s.studentId);
      final last = repo.lastLog(s.studentId);
      final name = s.isPersonal ? s.title : (st?.name ?? 'Unknown');
      final teach = s.isPersonal
          ? 'Personal'
          : ((last != null && last.nextPlan.isNotEmpty)
              ? last.nextPlan
              : (st != null && st.subjects.isNotEmpty ? st.subjects.join(', ') : ''));
      final done = repo.isSchedDone(s.id, now);
      final focus = s.id == focusId;
      final accent = done ? AppColors.income : AppColors.savings;
      if (i > 0) rows.add(Divider(height: 1, indent: 14, endIndent: 14, color: hint.withValues(alpha: 0.15)));
      rows.add(InkWell(
        onTap: () => openScheduleSheet(context, ref, existing: s),
        child: Container(
          color: focus ? AppColors.savings.withValues(alpha: 0.08) : null,
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(children: [
            SizedBox(
              width: 66,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(minutesToTime(s.startMinutes), maxLines: 1,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                          color: done ? hint : accent)),
                ),
                Text('${s.durationMin} min', maxLines: 1, style: TextStyle(fontSize: 11, color: hint)),
              ]),
            ),
            Container(
              width: 3, height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: done ? 0.5 : 0.9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(s.isPersonal ? Icons.event_note : Icons.person, size: 15, color: hint),
                const SizedBox(width: 5),
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                        color: done ? hint : null,
                        decoration: done ? TextDecoration.lineThrough : null))),
                if (focus) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: (focusIsNow ? AppColors.income : AppColors.savings).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(focusIsNow ? 'NOW' : 'NEXT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4,
                            color: focusIsNow ? AppColors.income : AppColors.savings)),
                  ),
                ],
              ]),
              if (teach.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(teach, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: hint, fontSize: 12)),
                ),
            ])),
            IconButton(
              tooltip: done ? 'Mark not done' : 'Mark done',
              onPressed: () => repo.toggleSchedDone(s.id, now),
              icon: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? AppColors.income : hint, size: 24),
            ),
          ]),
        ),
      ));
    }
    return _groupCard(context, rows);
  }

  /// A card that holds several tappable rows (rows provide their own ink).
  Widget _groupCard(BuildContext context, List<Widget> rows) => PadCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(children: rows),
        ),
      );

  Widget _taskList(BuildContext context, Repo repo, List<PersonalTask> tasks) {
    final hint = Theme.of(context).hintColor;
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final rows = <Widget>[];
    final shown = tasks.take(5).toList();
    for (var i = 0; i < shown.length; i++) {
      final t = shown[i];
      final overdue = t.due.isBefore(startToday);
      if (i > 0) rows.add(Divider(height: 1, indent: 52, endIndent: 14, color: hint.withValues(alpha: 0.15)));
      rows.add(InkWell(
        onTap: () => showTaskSheet(context, existing: t),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
          child: Row(children: [
            Checkbox(value: t.done, activeColor: AppColors.income,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                onChanged: (_) => repo.saveTask(t.copyWith(done: !t.done))),
            Expanded(child: Text(t.title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Text(overdue ? shortDate(t.due) : TimeOfDay.fromDateTime(t.due).format(context),
                style: TextStyle(
                    color: overdue ? AppColors.expense : hint,
                    fontWeight: overdue ? FontWeight.w600 : null,
                    fontSize: 12)),
            const SizedBox(width: 10),
            Container(width: 9, height: 9,
                decoration: BoxDecoration(color: priorityColor(t.priority), shape: BoxShape.circle)),
          ]),
        ),
      ));
    }
    if (tasks.length > shown.length) {
      rows.add(Divider(height: 1, color: hint.withValues(alpha: 0.15)));
      rows.add(InkWell(
        onTap: () => context.go('/more/tasks'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(child: Text('+${tasks.length - shown.length} more',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13))),
        ),
      ));
    }
    return _groupCard(context, rows);
  }

  Widget _examList(BuildContext context, Repo repo) {
    final hint = Theme.of(context).hintColor;
    final rows = <Widget>[];
    final exams = repo.upcomingExams.take(3).toList();
    for (var i = 0; i < exams.length; i++) {
      final e = exams[i];
      final days = e.date.difference(DateTime.now()).inDays;
      final soon = days <= 3;
      if (i > 0) rows.add(Divider(height: 1, indent: 70, endIndent: 14, color: hint.withValues(alpha: 0.15)));
      rows.add(InkWell(
        onTap: () => context.go('/more/exams'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(children: [
            Container(
              width: 44, height: 46,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${e.date.day}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    color: AppColors.warning, height: 1.1)),
                Text(DateFormat('MMM').format(e.date).toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warning)),
              ]),
            ),
            Gap.m,
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (e.subject.isNotEmpty)
                Text(e.subject, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: hint, fontSize: 12)),
            ])),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: (soon ? AppColors.expense : AppColors.warning).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(days <= 0 ? 'Today' : (days == 1 ? 'Tomorrow' : 'in $days d'),
                  style: TextStyle(color: soon ? AppColors.expense : AppColors.warning,
                      fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
        ),
      ));
    }
    return _groupCard(context, rows);
  }

  /// Classes on the next days (weekly schedule), shown only when there are any.
  List<Widget> _upcoming(BuildContext context, WidgetRef ref, Repo repo) {
    final today = DateTime.now();
    final rows = <(DateTime, ScheduleItem)>[];
    for (var i = 1; i <= 7 && rows.length < 8; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      for (final it in repo.scheduleOnDate(day)) {
        rows.add((day, it));
      }
    }
    if (rows.isEmpty) return const [];
    final shown = rows.take(8).toList();
    final hint = Theme.of(context).hintColor;
    String dayLabel(DateTime d) {
      final diff = DateTime(d.year, d.month, d.day)
          .difference(DateTime(today.year, today.month, today.day)).inDays;
      return diff == 1 ? 'Tomorrow' : '${weekdayNames[d.weekday - 1]}, ${shortDate(d)}';
    }

    final children = <Widget>[];
    DateTime? lastDay;
    for (final (day, it) in shown) {
      if (day != lastDay) {
        children.add(Padding(
          padding: EdgeInsets.fromLTRB(14, lastDay == null ? 12 : 10, 14, 4),
          child: Row(children: [
            Text(dayLabel(day).toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    letterSpacing: 0.6, color: hint)),
            const SizedBox(width: 8),
            Expanded(child: Divider(height: 1, color: hint.withValues(alpha: 0.15))),
          ]),
        ));
        lastDay = day;
      }
      children.add(InkWell(
        onTap: () => openScheduleSheet(context, ref, existing: it),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Icon(it.isPersonal ? Icons.event_note : Icons.person, size: 18, color: AppColors.savings),
            Gap.m,
            Expanded(child: Text(
                it.isPersonal ? it.title : (repo.student(it.studentId)?.name ?? 'Unknown'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('${minutesToTime(it.startMinutes)} · ${it.durationMin}m',
                style: const TextStyle(color: AppColors.savings, fontWeight: FontWeight.w600, fontSize: 12)),
          ]),
        ),
      ));
    }
    children.add(const SizedBox(height: 6));
    return [
      _Section('Upcoming Schedule',
          icon: Icons.upcoming, color: AppColors.savings,
          onAll: () => context.go('/schedule')),
      _groupCard(context, children),
    ];
  }

  int _jobPercent(Repo repo) {
    final tasks = repo.jobTaskList;
    if (tasks.isEmpty) return 0;
    var t = 0, c = 0;
    for (final j in tasks) {
      t += j.target;
      c += j.completed;
    }
    if (t == 0) return 0;
    return ((c / t) * 100).round().clamp(0, 100);
  }
}

/// Progress tile with a ring + label (thesis / job prep).
class _ProgressTile extends StatelessWidget {
  const _ProgressTile({required this.label, required this.sub, required this.percent,
      required this.color, required this.icon, required this.onTap});
  final String label, sub;
  final int percent;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PadCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(children: [
          SizedBox(
            width: 48, height: 48,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: (percent / 100).clamp(0, 1).toDouble(),
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: color.withValues(alpha: 0.16),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Icon(icon, size: 18, color: color),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$percent%', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(sub, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11)),
          ])),
        ]),
      );
}
