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
import 'collect_sheet.dart';
import 'payments_screen.dart' show sendFeeReminder;
import 'plan_editor.dart';

/// One student's whole fee story: balance, plan, and every charge and payment.
class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([repo.studentsL, repo.paymentsL, repo.logsL]),
      builder: (context, _) {
        final s = repo.student(id);
        if (s == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Student not found')));
        final a = repo.feeAccount(s);
        final cfg = repo.feeSettings;
        final ledger = a.ledger().reversed.toList();
        final hint = Theme.of(context).hintColor;
        return Scaffold(
          appBar: AppBar(
            title: Text('${s.name} · Fees'),
            actions: [
              IconButton(
                tooltip: 'Share statement',
                icon: const Icon(Icons.ios_share),
                onPressed: () => SharePlus.instance.share(ShareParams(text: statementText(s, a, cfg))),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                PadCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.owed > 0.5 ? 'Owes' : a.credit > 0.5 ? 'Advance credit' : 'Balance',
                        style: TextStyle(color: hint, fontSize: 12)),
                    Text(
                      a.owed > 0.5 ? taka(a.owed) : a.credit > 0.5 ? taka(a.credit) : 'All clear',
                      style: TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800,
                        color: a.owed > 0.5 ? (a.isOverdue ? AppColors.expense : AppColors.warning) : AppColors.income,
                      ),
                    ),
                    if (a.isOverdue)
                      Text('${taka(a.overdueAmount)} overdue · oldest ${a.overdueDays} days',
                          style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600)),
                    Gap.m,
                    Row(children: [
                      Expanded(child: FilledButton.icon(
                        icon: const Icon(Icons.payments, size: 18),
                        label: const Text('Collect'),
                        onPressed: () => showCollectSheet(context, ref, s,
                            month: a.unpaid.isEmpty ? null : a.unpaid.first.month),
                      )),
                      Gap.s,
                      Expanded(child: OutlinedButton.icon(
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text('Remind'),
                        onPressed: a.owed > 0.5 ? () => sendFeeReminder(context, repo, s, a) : null,
                      )),
                      Gap.s,
                      IconButton.outlined(
                        tooltip: 'Adjust',
                        icon: const Icon(Icons.tune),
                        onPressed: () => _adjust(context, repo, s, a),
                      ),
                    ]),
                  ]),
                ),
                Gap.m,
                const SectionTitle('Fee plan'),
                for (final p in s.plans.reversed)
                  PadCard(
                    onTap: () async {
                      final np = await showPlanEditor(context,
                          initial: p, cfg: cfg, title: 'Edit plan', askFrom: s.plans.length > 1);
                      if (np != null) await repo.setPlan(s, np.copyWith(id: p.id));
                    },
                    child: Row(children: [
                      const Icon(Icons.sell_outlined, size: 20),
                      Gap.m,
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(planSummary(p), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(p.from.isEmpty ? 'From the beginning' : 'From ${monthLabel(DateTime.parse('${p.from}-01'))}',
                            style: TextStyle(color: hint, fontSize: 12)),
                      ])),
                      if (s.plans.length > 1)
                        IconButton(
                          tooltip: 'Remove this version',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => repo.saveStudent(s.withPlans(s.plans.where((x) => x.id != p.id).toList())),
                        ),
                    ]),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Change fee from a month…'),
                    onPressed: () => changeFeeFrom(context, repo, s),
                  ),
                ),
                Gap.s,
                const SectionTitle('History'),
                if (ledger.isEmpty)
                  const EmptyState(icon: Icons.receipt_long, message: 'Nothing charged yet.'),
                for (final e in ledger) _entry(context, repo, s, a, cfg, e),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _entry(BuildContext context, Repo repo, Student s, FeeAccount a, FeeSettings cfg, LedgerEntry e) {
    final isPay = e.kind == LedgerKind.payment;
    final pay = isPay ? repo.paymentFor(s.id, e.cycleKey) : null;
    final inst = pay?.installments.where((i) => i.id == e.refId).firstOrNull;
    final cycle = DateTime.parse('${e.cycleKey}-01');
    final color = e.amount < 0 ? AppColors.income : e.kind == LedgerKind.lateFee ? AppColors.expense : null;
    final detail = [
      fullDate(e.date),
      if (inst != null && cfg.methodById(inst.method) != null) cfg.methodById(inst.method)!.name,
      if (inst != null && inst.ref.isNotEmpty) inst.ref,
      if (inst != null && inst.receiptNo > 0) '#${inst.receiptNo.toString().padLeft(4, '0')}',
      if (inst != null && inst.note.isNotEmpty) inst.note,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        switch (e.kind) {
          LedgerKind.payment => Icons.check_circle,
          LedgerKind.discount => Icons.sell,
          LedgerKind.extra => Icons.add_circle_outline,
          LedgerKind.lateFee => Icons.alarm,
          _ => Icons.receipt_long,
        },
        color: color ?? Theme.of(context).hintColor,
      ),
      title: Text('${e.label} · ${monthLabel(cycle)}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(detail),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${e.amount < 0 ? '−' : '+'}${taka(e.amount.abs())}',
            style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        Text('bal ${taka(e.running)}', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
      ]),
      onTap: () async {
        if (isPay && pay != null && inst != null) {
          await _paymentActions(context, repo, s, a, cfg, pay, inst);
        } else if (e.refId.isNotEmpty) {
          final ok = await _confirm(context, 'Remove "${e.label}"?');
          if (ok) await repo.removeAdjustment(s, cycle, e.refId);
        }
      },
    );
  }

  Future<void> _paymentActions(BuildContext context, Repo repo, Student s, FeeAccount a,
      FeeSettings cfg, Payment pay, PayInstallment inst) async {
    final act = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('${taka(inst.amount)} · ${fullDate(inst.date)}',
              style: const TextStyle(fontWeight: FontWeight.w700))),
          ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Share receipt'),
              onTap: () => Navigator.pop(c, 'share')),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete payment'),
              onTap: () => Navigator.pop(c, 'delete')),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (act == 'share') {
      SharePlus.instance.share(ShareParams(text: receiptText(s, pay, inst, cfg, a.balance)));
    } else if (act == 'delete') {
      final messenger = ScaffoldMessenger.of(context);
      final month = DateTime.parse('${pay.month}-01');
      await repo.removeInstallment(pay, inst.id);
      messenger.showSnackBar(SnackBar(
        content: Text('${taka(inst.amount)} payment removed'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'UNDO', onPressed: () => repo.restoreInstallment(s, month, inst)),
      ));
    }
  }

  Future<bool> _confirm(BuildContext context, String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
          ],
        ),
      ) ??
      false;

  Future<void> _adjust(BuildContext context, Repo repo, Student s, FeeAccount a) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AdjustSheet(student: s, account: a),
    );
  }
}

/// Asks which month the new fee starts from, then edits a copy of the latest plan.
Future<void> changeFeeFrom(BuildContext context, Repo repo, Student s) async {
  final cfg = repo.feeSettings;
  final cur = monthKey(repo.currentCycleMonth(s));
  final base = s.plans.last;
  final np = await showPlanEditor(context,
      initial: base.copyWith(id: newId(), from: cur), cfg: cfg, title: 'New fee plan');
  if (np != null) await repo.setPlan(s, np);
}

class _AdjustSheet extends ConsumerStatefulWidget {
  const _AdjustSheet({required this.student, required this.account});
  final Student student;
  final FeeAccount account;
  @override
  ConsumerState<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends ConsumerState<_AdjustSheet> {
  String _kind = FeeAdjustment.discount;
  final _amount = TextEditingController();
  final _label = TextEditingController();
  final _note = TextEditingController();
  late String _cycle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _cycle = a.unpaid.isNotEmpty ? a.unpaid.first.key : a.todayKey;
  }

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(Repo repo) async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (_busy) return;
    final month = DateTime.parse('$_cycle-01');
    final s = widget.student;
    setState(() => _busy = true);
    if (_kind == 'custom') {
      await repo.setCustomDue(s, month, _amount.text.trim().isEmpty ? null : amt);
    } else if (_kind == 'lateWaive') {
      await repo.setLateFeeWaived(s, month, true);
    } else {
      if (amt <= 0) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount')));
        return;
      }
      await repo.addAdjustment(s, month, FeeAdjustment(
          id: newId(), kind: _kind, amount: amt, date: DateTime.now(),
          label: _label.text.trim(), note: _note.text.trim()));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final cfg = repo.feeSettings;
    final a = widget.account;
    final keys = [for (final c in a.cycles.reversed.take(18)) c.key];
    if (!keys.contains(_cycle)) keys.insert(0, _cycle);
    final needsAmount = _kind != 'lateWaive';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Adjust fee', style: Theme.of(context).textTheme.titleLarge),
            Gap.m,
            Wrap(spacing: 8, children: [
              for (final e in const [
                (FeeAdjustment.discount, 'Discount'),
                (FeeAdjustment.charge, 'Extra charge'),
                (FeeAdjustment.waiver, 'Waive amount'),
                ('lateWaive', 'Waive late fee'),
                ('custom', 'Set month fee'),
              ])
                ChoiceChip(label: Text(e.$2), selected: _kind == e.$1, onSelected: (_) => setState(() => _kind = e.$1)),
            ]),
            Gap.m,
            DropdownButtonFormField<String>(
              initialValue: _cycle,
              decoration: const InputDecoration(labelText: 'For month'),
              items: [for (final k in keys) DropdownMenuItem(value: k, child: Text(monthLabel(DateTime.parse('$k-01'))))],
              onChanged: (v) => setState(() => _cycle = v ?? _cycle),
            ),
            if (needsAmount) ...[
              Gap.s,
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(
                  labelText: _kind == 'custom' ? 'Fee for this month' : 'Amount',
                  prefixText: '৳ ',
                  helperText: _kind == 'custom' ? 'Leave empty to go back to the automatic fee' : null,
                ),
              ),
            ],
            if (_kind == FeeAdjustment.charge) ...[
              Gap.s,
              Wrap(spacing: 8, children: [
                for (final t in cfg.chargeTypes) ActionChip(label: Text(t), onPressed: () => setState(() => _label.text = t)),
              ]),
            ],
            if (_kind == FeeAdjustment.discount || _kind == FeeAdjustment.charge || _kind == FeeAdjustment.waiver) ...[
              Gap.s,
              TextField(controller: _label, decoration: const InputDecoration(labelText: 'Label (optional)')),
            ],
            Gap.m,
            FilledButton(onPressed: _busy ? null : () => _save(repo), child: const Text('Apply')),
          ]),
        ),
      ),
    );
  }
}
