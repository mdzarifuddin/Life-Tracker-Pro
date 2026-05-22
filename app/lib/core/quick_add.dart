import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';

/// Quick-add bottom sheet (expense / income / student / class log).
void showQuickAdd(BuildContext context) {
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
          _QuickTile(Icons.edit_note, 'Log Class', AppColors.savings,
              () { ctx.pop(); ctx.push('/class-log'); }),
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
