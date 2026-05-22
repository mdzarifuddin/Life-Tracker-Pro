import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'models.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/students/students_screen.dart';
import 'features/schedule/schedule_screen.dart';
import 'features/finance/finance_screen.dart';
import 'features/more/more_screen.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/payments/payments_screen.dart';
import 'features/exams/exams_screen.dart';
import 'features/jobprep/jobprep_screen.dart';
import 'features/thesis/thesis_screen.dart';
import 'features/lists/lists_screen.dart';
import 'features/settings/settings_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/dashboard',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/students',
            builder: (c, s) => const StudentsScreen(),
            routes: [
              GoRoute(path: 'payments', builder: (c, s) => const PaymentsScreen()),
              GoRoute(path: 'exams', builder: (c, s) => const ExamsScreen()),
              GoRoute(
                path: ':id',
                builder: (c, s) => StudentDetailScreen(id: s.pathParameters['id']!),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/schedule', builder: (c, s) => const ScheduleScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/finance', builder: (c, s) => const FinanceScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/more',
            builder: (c, s) => const MoreScreen(),
            routes: [
              GoRoute(path: 'tasks', builder: (c, s) => const TasksScreen()),
              GoRoute(path: 'payments', builder: (c, s) => const PaymentsScreen()),
              GoRoute(path: 'exams', builder: (c, s) => const ExamsScreen()),
              GoRoute(path: 'jobprep', builder: (c, s) => const JobPrepScreen()),
              GoRoute(path: 'thesis', builder: (c, s) => const ThesisScreen()),
              GoRoute(path: 'lists', builder: (c, s) => const ListsScreen()),
              GoRoute(path: 'settings', builder: (c, s) => const SettingsScreen()),
            ],
          ),
        ]),
      ],
    ),
    GoRoute(
      path: '/student-form',
      parentNavigatorKey: _rootKey,
      builder: (c, s) => StudentFormScreen(id: s.extra as String?),
    ),
    GoRoute(
      path: '/class-log',
      parentNavigatorKey: _rootKey,
      builder: (c, s) {
        final e = s.extra;
        if (e is ClassLog) return ClassLogFormScreen(existing: e);
        if (e is Map) {
          return ClassLogFormScreen(
              studentId: e['studentId'] as String?, presetDate: e['date'] as DateTime?);
        }
        return ClassLogFormScreen(studentId: e as String?);
      },
    ),
    GoRoute(
      path: '/txn-form',
      parentNavigatorKey: _rootKey,
      builder: (c, s) {
        final extra = s.extra;
        if (extra is Txn) {
          return TransactionFormScreen(type: extra.type, existing: extra);
        }
        return TransactionFormScreen(type: (extra as String?) ?? 'expense');
      },
    ),
  ],
);

class MentoraApp extends ConsumerWidget {
  const MentoraApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Life Tracker Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: _router,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return DecoratedBox(
          decoration: BoxDecoration(gradient: dark ? AppColors.darkBg : AppColors.lightBg),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -250 && shell.currentIndex < 4) {
            shell.goBranch(shell.currentIndex + 1);
          } else if (v > 250 && shell.currentIndex > 0) {
            shell.goBranch(shell.currentIndex - 1);
          }
        },
        child: shell,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: true),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Tuition'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Schedule'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Finance'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'More'),
        ],
      ),
    );
  }
}
