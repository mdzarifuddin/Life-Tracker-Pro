import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/fees.dart';
import '../../core/theme.dart';

Color feeStateColor(String status) {
  switch (status) {
    case 'paid':
      return AppColors.income;
    case 'overdue':
      return AppColors.expense;
    case 'due':
      return AppColors.warning;
    default:
      return AppColors.savings;
  }
}

String feeStateLabel(CycleStatement c) {
  switch (c.status) {
    case 'paid':
      return 'Paid';
    case 'overdue':
      return 'Overdue ${c.overdueDays}d';
    case 'due':
      return 'Due';
    case 'upcoming':
      return 'Upcoming';
    default:
      return 'No fee';
  }
}

IconData methodIcon(String key) {
  switch (key) {
    case 'phone':
      return Icons.smartphone;
    case 'bank':
      return Icons.account_balance;
    case 'card':
      return Icons.credit_card;
    case 'other':
      return Icons.more_horiz;
    default:
      return Icons.payments_outlined;
  }
}

const methodIconKeys = ['cash', 'phone', 'bank', 'card', 'other'];

/// Small coloured pill, e.g. "Overdue 12d".
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, this.color, {super.key});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

/// Opens [uri] in another app, telling the user if nothing can handle it.
Future<bool> openExternal(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
  } catch (_) {}
  messenger.showSnackBar(SnackBar(content: Text('Cannot open ${uri.scheme}')));
  return false;
}
