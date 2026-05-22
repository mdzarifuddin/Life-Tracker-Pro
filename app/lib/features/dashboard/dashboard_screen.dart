import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/quick_add.dart';
import '../../core/theme.dart';
import '../../core/updater.dart';
import '../../core/widgets.dart';
import '../schedule/schedule_screen.dart';
import '../tasks/tasks_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    autoUpdateOnce(context);
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            repo.studentsL, repo.txnsL, repo.paymentsL, repo.schedulesL,
            repo.thesisL, repo.examsL, repo.tasksL, repo.jobtasksL, repo.scheddoneL,
          ]),
          builder: (context, _) {
            final todayIdx = DateTime.now().weekday - 1;
            final todays = repo.scheduleForDay(todayIdx);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Life Tracker Pro',
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface)),
                    Text(fullDate(DateTime.now()),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ])),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) {
                      if (v == 'settings') context.go('/more/settings');
                      if (v == 'about') {
                        showAboutDialog(
                          context: context,
                          applicationName: 'Life Tracker Pro',
                          applicationVersion: 'Version 1.0.0',
                          applicationIcon: const Icon(Icons.auto_awesome, color: AppColors.primary),
                          children: const [Text('Manage tuition, finance, study & personal life — all in one place.')],
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'settings',
                          child: ListTile(leading: Icon(Icons.settings), title: Text('Settings'), contentPadding: EdgeInsets.zero)),
                      PopupMenuItem(value: 'about',
                          child: ListTile(leading: Icon(Icons.info_outline), title: Text('App info'), contentPadding: EdgeInsets.zero)),
                    ],
                  ),
                ]),
                Gap.l,
                SectionTitle("Today's Schedule",
                    icon: Icons.calendar_today, color: AppColors.savings,
                    trailing: TextButton(onPressed: () => context.go('/schedule'), child: const Text('All'))),
                if (todays.isEmpty)
                  const PadCard(child: Text('No classes scheduled today. Enjoy! 🎉'))
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10, crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: todays.map((s) {
                      final st = repo.student(s.studentId);
                      final last = repo.lastLog(s.studentId);
                      final name = s.isPersonal ? s.title : (st?.name ?? 'Unknown');
                      final teach = s.isPersonal
                          ? 'Personal'
                          : ((last != null && last.nextPlan.isNotEmpty)
                              ? last.nextPlan
                              : (st != null && st.subjects.isNotEmpty ? st.subjects.join(', ') : ''));
                      final done = repo.isSchedDone(s.id, DateTime.now());
                      return PadCard(
                        tint: done ? AppColors.income : null,
                        onTap: () => openScheduleSheet(context, ref, existing: s),
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(s.isPersonal ? Icons.event_note : Icons.person, size: 18, color: AppColors.savings),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => repo.toggleSchedDone(s.id, DateTime.now()),
                              child: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: done ? AppColors.income : Theme.of(context).hintColor, size: 22)),
                          ]),
                          const Spacer(),
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                                  decoration: done ? TextDecoration.lineThrough : null)),
                          Text('${minutesToTime(s.startMinutes)} · ${s.durationMin}m',
                              style: const TextStyle(color: AppColors.savings, fontWeight: FontWeight.w600, fontSize: 12)),
                          if (teach.isNotEmpty)
                            Text(teach, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11)),
                        ]),
                      );
                    }).toList(),
                  ),
                Gap.l,
                SectionTitle('My Tasks', icon: Icons.checklist, color: AppColors.primary,
                    trailing: TextButton(onPressed: () => context.go('/more/tasks'), child: const Text('All'))),
                if (repo.todayTasks.isEmpty)
                  PadCard(
                    onTap: () => showTaskSheet(context),
                    child: Row(children: const [
                      Icon(Icons.add_task, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('No tasks due today. Tap to add one.'),
                    ]),
                  )
                else
                  ...repo.todayTasks.take(5).map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PadCard(
                          onTap: () => showTaskSheet(context, existing: t),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(children: [
                            Checkbox(value: t.done, activeColor: AppColors.income,
                                onChanged: (_) => repo.saveTask(t.copyWith(done: !t.done))),
                            Expanded(child: Text(t.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600))),
                            Text(TimeOfDay.fromDateTime(t.due).format(context),
                                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                            const SizedBox(width: 8),
                            Container(width: 9, height: 9,
                                decoration: BoxDecoration(color: priorityColor(t.priority), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                          ]),
                        ),
                      )),
                Gap.l,
                SectionTitle('Progress', icon: Icons.insights, color: AppColors.primary),
                PadCard(
                  onTap: () => context.go('/more/thesis'),
                  child: ProgressRow(label: 'MSc Thesis', percent: repo.thesisProgress, color: AppColors.primary),
                ),
                Gap.s,
                PadCard(
                  onTap: () => context.go('/more/jobprep'),
                  child: ProgressRow(label: 'Govt Job (today)', percent: _jobPercent(repo), color: AppColors.savings),
                ),
                Gap.l,
                SectionTitle('Upcoming Exams',
                    icon: Icons.event, color: AppColors.warning,
                    trailing: TextButton(onPressed: () => context.go('/more/exams'), child: const Text('All'))),
                if (repo.upcomingExams.isEmpty)
                  const PadCard(child: Text('No upcoming exams.'))
                else
                  ...repo.upcomingExams.take(3).map((e) {
                    final days = e.date.difference(DateTime.now()).inDays;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PadCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          const Icon(Icons.event, color: AppColors.warning),
                          Gap.m,
                          Expanded(child: Text('${e.title} · ${e.subject}',
                              style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text(days <= 0 ? 'Today' : 'in $days d',
                              style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: () => showQuickAdd(context),
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
