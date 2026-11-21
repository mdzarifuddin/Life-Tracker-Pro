import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data.dart';
import '../../core/fee_text.dart';
import '../../core/fees.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';
import 'fee_widgets.dart';

/// Collect a payment from a student. [month] is the cycle the payment is filed under
/// (default: the current cycle); money always clears the oldest bills first.
Future<void> showCollectSheet(BuildContext context, WidgetRef ref, Student s, {DateTime? month}) {
  final repo = ref.read(repoProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CollectSheet(student: s, month: month ?? repo.currentCycleMonth(s)),
  );
}

/// Kept so older screens (batch detail) keep working: opens the collect sheet.
Future<void> showFeeSheet(BuildContext context, WidgetRef ref, Student s, DateTime month) =>
    showCollectSheet(context, ref, s, month: month);

class _CollectSheet extends ConsumerStatefulWidget {
  const _CollectSheet({required this.student, required this.month});
  final Student student;
  final DateTime month;
  @override
  ConsumerState<_CollectSheet> createState() => _CollectSheetState();
}

class _CollectSheetState extends ConsumerState<_CollectSheet> {
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _note = TextEditingController();
  final _classes = TextEditingController();
  DateTime _date = DateTime.now();
  String? _method;
  int _classesPaid = 0;
  bool _busy = false;
  // Set after a payment is saved: shows the receipt actions.
  PayInstallment? _done;
  String _doneMonthKey = '';

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    _note.dispose();
    _classes.dispose();
    super.dispose();
  }

  void _setAmount(double v) {
    _amount.text = v > 0 ? (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)) : '';
    setState(() {});
  }

  Future<void> _pay(Repo repo, FeeSettings cfg) async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    final m = cfg.methodById(_method ?? cfg.defaultMethod);
    if (m != null && m.needsRef && _ref.text.trim().isEmpty) {
      // A reference is helpful but never blocks collecting money.
    }
    if (_busy) return;
    setState(() => _busy = true);
    final id = await repo.addPayment(widget.student, widget.month, amount, _date,
        classes: _classesPaid, method: m?.id ?? '', ref: _ref.text.trim(), note: _note.text.trim());
    final rec = repo.paymentFor(widget.student.id, monthKey(widget.month));
    final inst = rec?.installments.where((i) => i.id == id).firstOrNull;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = inst;
      _doneMonthKey = monthKey(widget.month);
    });
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
          final cfg = repo.feeSettings;
          final acct = repo.feeAccount(s, through: widget.month);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _done != null ? _success(context, repo, cfg, acct) : _form(context, repo, cfg, acct),
            ),
          );
        },
      ),
    );
  }

  Widget _success(BuildContext context, Repo repo, FeeSettings cfg, FeeAccount acct) {
    final i = _done!;
    final s = widget.student;
    final rec = repo.paymentFor(s.id, _doneMonthKey);
    final stillThere = rec?.installments.any((x) => x.id == i.id) ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      const Icon(Icons.check_circle, color: AppColors.income, size: 56),
      Gap.s,
      Text(stillThere ? '${taka(i.amount)} received' : 'Payment removed',
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      Text(
        acct.owed > 0.5
            ? 'Still due: ${taka(acct.owed)}'
            : acct.credit > 0.5 ? 'Advance credit: ${taka(acct.credit)}' : 'Fully paid — all clear',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).hintColor),
      ),
      Gap.l,
      if (stillThere) ...[
        FilledButton.icon(
          icon: const Icon(Icons.receipt_long),
          label: const Text('Share receipt'),
          onPressed: () {
            if (rec == null) return;
            SharePlus.instance.share(ShareParams(text: receiptText(s, rec, i, cfg, acct.balance)));
          },
        ),
        Gap.s,
        OutlinedButton.icon(
          icon: const Icon(Icons.undo),
          label: const Text('Undo this payment'),
          onPressed: () async {
            if (rec == null) return;
            await repo.removeInstallment(rec, i.id);
            if (mounted) setState(() {});
          },
        ),
        Gap.s,
      ],
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
    ]);
  }

  Widget _form(BuildContext context, Repo repo, FeeSettings cfg, FeeAccount acct) {
    final s = widget.student;
    final hint = Theme.of(context).hintColor;
    final cur = acct.statementFor(monthKey(widget.month));
    final methods = cfg.activeMethods;
    final method = cfg.methodById(_method ?? cfg.defaultMethod) ?? (methods.isEmpty ? null : methods.first);
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final after = acct.balance - amount;
    final overdueOnly = acct.overdueAmount;
    final thisCycle = cur?.outstanding ?? 0;
    final perClass = s.plans.last.perClassRate;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        InitialAvatar(s.name),
        Gap.m,
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(acct.owed > 0.5
              ? 'Owes ${taka(acct.owed)}'
              : acct.credit > 0.5 ? 'Advance ${taka(acct.credit)}' : 'All clear',
              style: TextStyle(color: acct.owed > 0.5 ? AppColors.warning : AppColors.income,
                  fontWeight: FontWeight.w600)),
        ])),
        if (cur != null) StatusPill(feeStateLabel(cur), feeStateColor(cur.status)),
      ]),
      Gap.m,
      TextField(
        controller: _amount,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        decoration: const InputDecoration(labelText: 'Amount received', prefixText: '৳ '),
      ),
      Gap.s,
      Wrap(spacing: 8, runSpacing: 4, children: [
        if (acct.owed > 0.5)
          ActionChip(label: Text('All owed ${taka(acct.owed)}'), onPressed: () => _setAmount(acct.owed)),
        if (overdueOnly > 0.5 && (overdueOnly - acct.owed).abs() > 0.5)
          ActionChip(label: Text('Overdue ${taka(overdueOnly)}'), onPressed: () => _setAmount(overdueOnly)),
        if (thisCycle > 0.5 && (thisCycle - acct.owed).abs() > 0.5)
          ActionChip(label: Text('This month ${taka(thisCycle)}'), onPressed: () => _setAmount(thisCycle)),
      ]),
      if (amount > 0) ...[
        Gap.s,
        Text(
          after > 0.5
              ? 'After this: ${taka(after)} still due'
              : after < -0.5 ? 'After this: ${taka(-after)} advance credit' : 'After this: fully paid',
          style: TextStyle(fontWeight: FontWeight.w600,
              color: after > 0.5 ? AppColors.warning : AppColors.income),
        ),
      ],
      Gap.m,
      Text('Paid by', style: TextStyle(color: hint, fontSize: 12)),
      Gap.s,
      Wrap(spacing: 8, children: [
        for (final m in methods)
          ChoiceChip(
            avatar: Icon(methodIcon(m.icon), size: 16),
            label: Text(m.name),
            selected: method?.id == m.id,
            onSelected: (_) => setState(() => _method = m.id),
          ),
      ]),
      if (method != null && method.needsRef) ...[
        Gap.s,
        TextField(controller: _ref, decoration: InputDecoration(labelText: '${method.name} reference / TrxID (optional)')),
      ],
      Gap.s,
      Row(children: [
        Expanded(child: TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)'))),
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
      if (perClass > 0 && s.plans.last.kind != FeePlan.fixed) ...[
        Gap.s,
        TextField(
          controller: _classes,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            final n = int.tryParse(v.trim()) ?? 0;
            _classesPaid = n;
            if (n > 0) _setAmount(n * perClass);
          },
          decoration: InputDecoration(
              labelText: 'Pay for some classes (optional)', helperText: '${taka(perClass)} per class'),
        ),
      ],
      Gap.l,
      FilledButton.icon(
        icon: const Icon(Icons.check),
        label: Text(amount > 0 ? 'Collect ${taka(amount)}' : 'Collect'),
        onPressed: _busy ? null : () => _pay(repo, cfg),
      ),
    ]);
  }
}
