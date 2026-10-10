import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/tasks/tasks_screen.dart';
import 'theme.dart';

/// Quick-add bottom sheet (expense / income / student).
void showQuickAdd(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Quick Add', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          _QuickTile(Icons.south_west, 'Add Expense', AppColors.expense,
              () { ctx.pop(); ctx.push('/txn-form', extra: 'expense'); }),
          _QuickTile(Icons.north_east, 'Add Income', AppColors.income,
              () { ctx.pop(); ctx.push('/txn-form', extra: 'income'); }),
          _QuickTile(Icons.person_add_alt, 'Add Student', AppColors.primary,
              () { ctx.pop(); ctx.push('/student-form'); }),
          _QuickTile(Icons.add_task, 'Add Task', AppColors.warning,
              () { ctx.pop(); showTaskSheet(context); }),
          _QuickTile(Icons.add_alarm, 'Add Schedule', AppColors.savings,
              () { ctx.pop(); openScheduleSheet(context, ref); }),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _QuickTile extends StatelessWidget {
  const _QuickTile(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: onTap,
      );
}
