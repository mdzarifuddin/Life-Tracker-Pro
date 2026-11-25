import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/appearance.dart';
import 'core/l10n.dart';
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
import 'features/history/history_screen.dart';

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
              GoRoute(path: 'history', builder: (c, s) => const HistoryScreen()),
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
        if (extra is Map) {
          return TransactionFormScreen(
              type: (extra['type'] as String?) ?? 'expense', category: extra['category'] as String?);
        }
        return TransactionFormScreen(type: (extra as String?) ?? 'expense');
      },
    ),
  ],
);

class LifeTrackerApp extends ConsumerWidget {
  const LifeTrackerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The chosen background fixes the theme (Pastel = light, Aurora / Midnight = dark).
    final look = ref.watch(appearanceProvider);
    ref.watch(langProvider); // rebuild the app when the language changes
    return MaterialApp.router(
      title: 'Life Tracker Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: look.themeMode,
      routerConfig: _router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: AppTextScaler(mq.textScaler, look.textScale)),
          // Status-bar icons follow the background (app bars set the same style).
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: BgInk.of(context).overlay,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: look.gradient),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
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
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: true),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: tr('Home')),
          NavigationDestination(icon: const Icon(Icons.school_outlined), selectedIcon: const Icon(Icons.school), label: tr('Tuition')),
          NavigationDestination(icon: const Icon(Icons.calendar_today_outlined), selectedIcon: const Icon(Icons.calendar_today), label: tr('Schedule')),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), selectedIcon: const Icon(Icons.account_balance_wallet), label: tr('Finance')),
          NavigationDestination(icon: const Icon(Icons.grid_view_outlined), selectedIcon: const Icon(Icons.grid_view), label: tr('More')),
        ],
      ),
    );
  }
}
