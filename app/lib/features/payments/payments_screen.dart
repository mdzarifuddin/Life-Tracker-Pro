import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data.dart';
import '../../core/fee_text.dart';
import '../../core/fees.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';
import 'collect_sheet.dart';
import 'fee_widgets.dart';

export 'collect_sheet.dart' show showFeeSheet, showCollectSheet;

Color feeStatusColor(String status) => status == 'paid'
    ? AppColors.income
    : status == 'partial' ? AppColors.warning : AppColors.expense;

String feeStatusLabel(String status) =>
    status == 'paid' ? 'Paid' : status == 'partial' ? 'Partial' : 'Due';

String cycleLabel(Repo repo, Student s, DateTime month) =>
    '${fullDate(repo.cycleStart(s, month))} – ${fullDate(repo.cycleEnd(s, month))}';

/// Sends a fee reminder by WhatsApp (or SMS) and notes it on the cycle.
Future<void> sendFeeReminder(BuildContext context, Repo repo, Student s, FeeAccount a,
    {bool sms = false}) async {
  final phone = feeContactPhone(s);
  if (phone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number — add a guardian phone first')));
    return;
  }
  final text = reminderText(s, a, repo.feeSettings);
  final uri = sms
      ? Uri.parse('sms:$phone?body=${Uri.encodeComponent(text)}')
      : Uri.parse('https://wa.me/${waNumber(phone)}?text=${Uri.encodeComponent(text)}');
  final ok = await openExternal(context, uri);
  final c = a.unpaid.isEmpty ? a.current : a.unpaid.first;
  if (ok && c != null) await repo.markReminded(s, c.month);
}

enum _Filter { overdue, soon, paid, all }

/// The fee inbox: who owes what, overdue first.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  _Filter? _filter;
  late DateTime _month;
  final _search = TextEditingController();
  bool _byName = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isSoon(FeeAccount a) => a.dueSoonAmount > 0.5 && !a.isOverdue;
  bool _isPaid(FeeAccount a) => a.owed <= 0.5;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fees'),
        actions: [
          IconButton(
            tooltip: 'Fee settings',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/fee-settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.studentsL, repo.paymentsL, repo.logsL]),
          builder: (context, _) {
            final rows = repo.feeInbox();
            var overdue = 0.0, soon = 0.0;
            for (final r in rows) {
              overdue += r.$2.overdueAmount;
              soon += r.$2.dueSoonAmount;
            }
            // Money received (by payment date) in the chosen month.
            var collected = 0.0;
            for (final p in repo.paymentList) {
              for (final i in p.installments) {
                if (i.date.year == _month.year && i.date.month == _month.month) collected += i.amount;
              }
            }
            final anyOverdue = rows.any((r) => r.$2.isOverdue);
            final filter = _filter ?? (anyOverdue ? _Filter.overdue : _Filter.all);
            final q = _search.text.trim().toLowerCase();
            var list = rows.where((r) {
              if (q.isNotEmpty && !r.$1.name.toLowerCase().contains(q)) return false;
              switch (filter) {
                case _Filter.overdue:
                  return r.$2.isOverdue;
                case _Filter.soon:
                  return _isSoon(r.$2);
                case _Filter.paid:
                  return _isPaid(r.$2);
                case _Filter.all:
                  return true;
              }
            }).toList();
            list.sort((a, b) => _byName
                ? a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase())
                : b.$2.owed.compareTo(a.$2.owed));

            int count(bool Function(FeeAccount) f) => rows.where((r) => f(r.$2)).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(children: [
                  Expanded(child: GradientStatCard(label: 'Overdue', value: taka(overdue),
                      gradient: AppColors.expenseGrad, icon: Icons.error_outline)),
                  Gap.s,
                  Expanded(child: GradientStatCard(label: 'Due soon', value: taka(soon),
                      gradient: AppColors.warningGrad, icon: Icons.schedule)),
                ]),
                Gap.s,
                Row(children: [
                  IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      icon: const Icon(Icons.chevron_left)),
                  Expanded(child: Column(children: [
                    Text('Collected in ${monthLabel(_month)}',
                        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                    Text(taka(collected),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.income)),
                  ])),
                  IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                      icon: const Icon(Icons.chevron_right)),
                ]),
                Gap.s,
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search student',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: _byName ? 'Sorted by name' : 'Sorted by amount owed',
                      icon: Icon(_byName ? Icons.sort_by_alpha : Icons.sort),
                      onPressed: () => setState(() => _byName = !_byName),
                    ),
                  ),
                ),
                Gap.s,
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final e in [
                      (_Filter.overdue, 'Overdue', count((a) => a.isOverdue)),
                      (_Filter.soon, 'Due soon', count(_isSoon)),
                      (_Filter.paid, 'Paid', count(_isPaid)),
                      (_Filter.all, 'All', rows.length),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${e.$2} · ${e.$3}'),
                          selected: filter == e.$1,
                          onSelected: (_) => setState(() => _filter = e.$1),
                        ),
                      ),
                  ]),
                ),
                Gap.m,
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: filter == _Filter.overdue ? Icons.celebration : Icons.attach_money,
                      message: filter == _Filter.overdue
                          ? 'Nothing overdue. Nice!'
                          : rows.isEmpty ? 'Add students to track their fees.' : 'No students here.',
                    ),
                  )
                else
                  for (final r in list) _tile(context, repo, r.$1, r.$2),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Repo repo, Student s, FeeAccount a) {
    final hint = Theme.of(context).hintColor;
    final worst = a.unpaid.isEmpty ? null : a.unpaid.first;
    final String pillText;
    final Color pillColor;
    if (a.isOverdue) {
      pillText = 'Overdue ${a.overdueDays}d';
      pillColor = AppColors.expense;
    } else if (_isSoon(a)) {
      pillText = 'Due soon';
      pillColor = AppColors.warning;
    } else if (a.owed > 0.5) {
      pillText = 'Upcoming';
      pillColor = AppColors.savings;
    } else {
      pillText = a.credit > 0.5 ? 'Advance' : 'Paid';
      pillColor = AppColors.income;
    }
    final sub = a.owed > 0.5
        ? [
            if (a.unpaid.length > 1) '${a.unpaid.length} months' else if (worst != null) monthLabel(worst.month),
            if (worst != null) 'due ${fullDate(worst.dueDate)}',
          ].join(' · ')
        : a.credit > 0.5 ? 'Credit ${taka(a.credit)}' : 'All clear';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PadCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        onTap: () => showCollectSheet(context, ref, s, month: worst?.month),
        child: Column(children: [
          Row(children: [
            InitialAvatar(s.name),
            Gap.m,
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub, style: TextStyle(color: hint, fontSize: 12.5)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (a.owed > 0.5)
                Text(taka(a.owed), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              StatusPill(pillText, pillColor),
            ]),
          ]),
        ]),
      ),
    );
  }
}
