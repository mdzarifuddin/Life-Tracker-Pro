import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';
import '../finance/finance_screen.dart' show orderedAccounts;

/// Details of a student's fee for one billing cycle: due, paid, every payment
/// with its date, and buttons to add a full / partial payment.
Future<void> showFeeSheet(BuildContext context, WidgetRef ref, Student s, DateTime month) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FeeSheet(student: s, month: month),
  );
}

Color feeStatusColor(String status) => status == 'paid'
    ? AppColors.income
    : status == 'partial' ? AppColors.warning : AppColors.expense;

String feeStatusLabel(String status) =>
    status == 'paid' ? 'Paid' : status == 'partial' ? 'Partial' : 'Pending';

String cycleLabel(Repo repo, Student s, DateTime month) =>
    '${fullDate(repo.cycleStart(s, month))} – ${fullDate(repo.cycleEnd(s, month))}';

class _FeeSheet extends ConsumerStatefulWidget {
  const _FeeSheet({required this.student, required this.month});
  final Student student;
  final DateTime month;
  @override
  ConsumerState<_FeeSheet> createState() => _FeeSheetState();
}

class _FeeSheetState extends ConsumerState<_FeeSheet> {
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  String _account = '';

  @override
  void dispose() {
    _amount.dispose();
    _classes.dispose();
    super.dispose();
  }

  final _classes = TextEditingController();
  int _classesPaid = 0;

  double get _perClass {
    return widget.student.perClassFee;
  }

  /// "Pay for N classes": fills the amount as N × per-class rate.
  void _onClasses(String v) {
    final n = int.tryParse(v.trim()) ?? 0;
    setState(() => _classesPaid = n);
    _amount.text = n > 0 ? (n * _perClass).toStringAsFixed(0) : '';
  }

  /// Set this month's fee by hand (or go back to the automatic amount).
  Future<void> _editDue(Repo repo, double? current, double shown) async {
    final c = TextEditingController(text: shown == 0 ? '' : shown.toStringAsFixed(0));
    final res = await showDialog<(bool, double?)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Fee for ${monthLabel(widget.month)}'),
        content: TextField(
          controller: c, autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(
              prefixText: '৳ ', labelText: 'Custom due for this month only'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (current != null)
            TextButton(onPressed: () => Navigator.pop(ctx, (true, null)), child: const Text('Use automatic')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(c.text.trim());
              if (v != null) Navigator.pop(ctx, (true, v));
            },
            child: const Text('Set')),
        ],
      ),
    );
    if (res == null) return;
    await repo.setCustomDue(widget.student, widget.month, res.$2);
  }

  Future<void> _pay(Repo repo, double amount, {int classes = 0}) async {
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    await repo.addPayment(widget.student, widget.month, amount, _date,
        account: _account, classes: classes);
    _amount.clear();
    _classes.clear();
    setState(() => _classesPaid = 0);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final s = widget.student;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: AnimatedBuilder(
        animation: Listenable.merge([repo.paymentsL, repo.logsL, repo.studentsL]),
        builder: (context, _) {
          final st = repo.payState(s, widget.month);
          final pay = repo.paymentFor(s.id, monthKey(widget.month));
          final installments = [...?pay?.installments]..sort((a, b) => a.date.compareTo(b.date));
          final color = feeStatusColor(st.status);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  Chip(
                    label: Text(feeStatusLabel(st.status), style: const TextStyle(color: Colors.white)),
                    backgroundColor: color, visualDensity: VisualDensity.compact),
                ]),
                Text(cycleLabel(repo, s, widget.month),
                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
                Gap.m,
                Row(children: [
                  Expanded(child: InkWell(
                  onTap: () => _editDue(repo, pay?.customDue, st.due),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(pay?.customDue != null ? 'Due (custom)' : 'Due',
                        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(taka(st.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 14, color: Theme.of(context).hintColor),
                    ]),
                  ]),
                )),
                  _stat('Paid', taka(st.paid), AppColors.income),
                  _stat('Remaining', taka(st.remaining), st.remaining > 0 ? AppColors.warning : null),
                ]),
                if (st.carry.abs() > 0.5) ...[
                  Gap.s,
                  Text(
                    st.carry > 0
                        ? 'Previous due ${taka(st.carry)} carried forward + this month ${taka(st.due)}'
                        : 'Advance ${taka(-st.carry)} from earlier months − adjusted against ${taka(st.due)}',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: st.carry > 0 ? AppColors.warning : AppColors.income,
                        fontWeight: FontWeight.w600)),
                ],
                Gap.m,
                const Text('Payments', style: TextStyle(fontWeight: FontWeight.w600)),
                if (installments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No payment yet.', style: TextStyle(color: Theme.of(context).hintColor)),
                  ),
                for (final i in installments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.check_circle, color: AppColors.income),
                    title: Text(taka(i.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${fullDate(i.date)} · ${repo.accountName(i.account)}'
                        '${i.classes > 0 ? ' · ${i.classes} ${i.classes == 1 ? 'class' : 'classes'}' : ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => repo.removeInstallment(pay!, i.id)),
                  ),
                const Divider(),
                if (s.payPerClass || s.classesPerMonth > 0) ...[
                  TextField(
                    controller: _classes,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onClasses,
                    decoration: InputDecoration(
                      labelText: 'Pay for some classes',
                      helperText: '${taka(_perClass)} per class · '
                          '${repo.classesInMonth(s, widget.month)} taught this month'),
                  ),
                  Gap.s,
                ],
                Row(children: [
                  Expanded(child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: InputDecoration(
                      labelText: 'Amount (৳)',
                      hintText: st.remaining > 0 ? st.remaining.toStringAsFixed(0) : null),
                  )),
                  Gap.m,
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(fullDate(_date)),
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: _date,
                          firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ]),
                Gap.s,
                DropdownButtonFormField<String>(
                  initialValue: repo.accountById(_account) == null ? '' : _account,
                  decoration: const InputDecoration(labelText: 'Received in'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('No account')),
                    ...orderedAccounts(repo).map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.isMain ? a.name : '   ${a.name}'))),
                  ],
                  onChanged: (v) => setState(() => _account = v ?? ''),
                ),
                Gap.m,
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => _pay(repo, double.tryParse(_amount.text.trim()) ?? 0,
                        classes: _classesPaid),
                    child: Text(_classesPaid > 0 ? 'Pay $_classesPaid classes' : 'Pay some'))),
                  Gap.m,
                  Expanded(child: FilledButton(
                    onPressed: st.remaining > 0
                        ? () => _pay(repo, st.remaining,
                            classes: (s.payPerClass || s.classesPerMonth > 0) ? repo.classesInMonth(s, widget.month) : 0)
                        : null,
                    child: Text(st.remaining > 0 ? 'Pay all (${taka(st.remaining)})' : 'Fully paid'))),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, Color? color) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
        ]),
      );
}

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  void _shift(int m) => setState(() => _month = DateTime(_month.year, _month.month + m));

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.studentsL, repo.paymentsL, repo.logsL]),
          builder: (context, _) {
            final students = repo.studentsForMonth(_month);
            var collected = 0.0, pending = 0.0;
            // Current students always; previous students only while they still owe.
            final visible = students
                .where((s) => s.isCurrent || repo.payState(s, _month).remaining > 0)
                .toList();
            for (final s in students) {
              final st = repo.payState(s, _month);
              collected += st.paid;
              pending += st.remaining;
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                  Text(monthLabel(_month), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
                ]),
                Gap.m,
                Row(children: [
                  Expanded(child: GradientStatCard(label: 'Collected', value: taka(collected), gradient: AppColors.incomeGrad, icon: Icons.check_circle)),
                  Gap.m,
                  Expanded(child: GradientStatCard(label: 'Pending', value: taka(pending), gradient: AppColors.warningGrad, icon: Icons.schedule)),
                ]),
                Gap.l,
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(icon: Icons.attach_money, message: 'No students for this month.'),
                  )
                else
                  ...visible.map((s) {
                    final st = repo.payState(s, _month);
                    final classes = repo.classesInMonth(s, _month);
                    final perClass = s.perClassFee;
                    final color = feeStatusColor(st.status);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PadCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        onTap: () => showFeeSheet(context, ref, s, _month),
                        child: Row(children: [
                          InitialAvatar(s.name),
                          Gap.m,
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(repo.paymentFor(s.id, monthKey(_month))?.customDue != null
                                ? '$classes ${classes == 1 ? 'class' : 'classes'} · custom fee ${taka(st.due)}'
                                : '$classes ${classes == 1 ? 'class' : 'classes'} × ${taka(perClass)} = ${taka(st.due)}',
                                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
                            if (s.billingDay != 1)
                              Text(cycleLabel(repo, s, _month),
                                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11.5)),
                            if (st.carry > 0.5)
                              Text('Includes previous due ${taka(st.carry)}',
                                  style: const TextStyle(color: AppColors.warning, fontSize: 12)),
                            if (st.status == 'partial')
                              Text('Paid ${taka(st.paid)} · Left ${taka(st.remaining)}',
                                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                          ])),
                          Chip(
                            label: Text(feeStatusLabel(st.status),
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: color, visualDensity: VisualDensity.compact),
                        ]),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
