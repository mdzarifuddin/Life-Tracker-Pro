import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';

String hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

/// Stable color for a category (shared by donut + bubbles).
Color catColor(String name) =>
    AppColors.forIndex(name.isEmpty ? 0 : name.codeUnitAt(0) + name.length);

enum FinPeriod { day, week, month, year, all }

class _Range {
  final DateTime start, end;
  const _Range(this.start, this.end);
  bool has(DateTime d) => !d.isBefore(start) && !d.isAfter(end);
}

_Range _rangeFor(FinPeriod p, DateTime a) {
  switch (p) {
    case FinPeriod.day:
      return _Range(DateTime(a.year, a.month, a.day), DateTime(a.year, a.month, a.day, 23, 59, 59));
    case FinPeriod.week:
      final mon = a.subtract(Duration(days: a.weekday - 1));
      final s = DateTime(mon.year, mon.month, mon.day);
      return _Range(s, s.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59)));
    case FinPeriod.month:
      return _Range(DateTime(a.year, a.month, 1), DateTime(a.year, a.month + 1, 0, 23, 59, 59));
    case FinPeriod.year:
      return _Range(DateTime(a.year, 1, 1), DateTime(a.year, 12, 31, 23, 59, 59));
    case FinPeriod.all:
      return _Range(DateTime(2000), DateTime(2200));
  }
}

String _periodLabel(FinPeriod p, DateTime a) {
  switch (p) {
    case FinPeriod.day: return fullDate(a);
    case FinPeriod.week:
      final r = _rangeFor(p, a);
      return '${shortDate(r.start)} – ${shortDate(r.end)}';
    case FinPeriod.month: return monthLabel(a);
    case FinPeriod.year: return '${a.year}';
    case FinPeriod.all: return 'All time';
  }
}

DateTime _shift(FinPeriod p, DateTime a, int dir) {
  switch (p) {
    case FinPeriod.day: return a.add(Duration(days: dir));
    case FinPeriod.week: return a.add(Duration(days: 7 * dir));
    case FinPeriod.month: return DateTime(a.year, a.month + dir, 1);
    case FinPeriod.year: return DateTime(a.year + dir, 1, 1);
    case FinPeriod.all: return a;
  }
}

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final unlocked = ref.watch(vaultProvider);
    if (repo.pinHash != null && !unlocked) return const _VaultGate();
    return const _FinanceHome();
  }
}

class _VaultGate extends ConsumerStatefulWidget {
  const _VaultGate();
  @override
  ConsumerState<_VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends ConsumerState<_VaultGate> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  void _try() {
    if (hashPin(_pin.text) == ref.read(repoProvider).pinHash) {
      ref.read(vaultProvider.notifier).unlock();
    } else {
      setState(() => _error = 'Wrong PIN');
    }
  }

  Future<void> _bio() async {
    final auth = LocalAuthentication();
    try {
      final supported = await auth.isDeviceSupported();
      if (!supported) return;
      final ok = await auth.authenticate(localizedReason: 'Unlock Finance Vault');
      if (ok && mounted) ref.read(vaultProvider.notifier).unlock();
    } catch (_) {/* fall back to PIN */}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock, size: 64, color: AppColors.primary),
                Gap.l,
                const Text('Finance Vault', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Text('Enter your PIN to continue'),
                Gap.xl,
                TextField(
                  controller: _pin, obscureText: true, obscuringCharacter: '*',
                  keyboardType: TextInputType.number, autocorrect: false, enableSuggestions: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, letterSpacing: 10),
                  decoration: InputDecoration(errorText: _error, hintText: '* * * *'),
                  onSubmitted: (_) => _try(),
                ),
                Gap.l,
                FilledButton(onPressed: _try, child: const Text('Unlock')),
                Gap.m,
                TextButton.icon(
                  onPressed: _bio,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Use fingerprint'),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _FinanceHome extends ConsumerStatefulWidget {
  const _FinanceHome();
  @override
  ConsumerState<_FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends ConsumerState<_FinanceHome> {
  FinPeriod _period = FinPeriod.month;
  DateTime _anchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          if (repo.pinHash != null)
            IconButton(
              tooltip: 'Lock',
              icon: const Icon(Icons.lock_outline),
              onPressed: () => ref.read(vaultProvider.notifier).lock()),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.txnsL, repo.categoriesL]),
          builder: (context, _) {
            final range = _rangeFor(_period, _anchor);
            final txns = repo.txnList.where((t) => range.has(t.date)).toList();
            final income = txns.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
            final expense = txns.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);
            final balance = income - expense;

            // expense by category for the donut
            final byCat = <String, double>{};
            for (final t in txns.where((t) => t.type == 'expense')) {
              byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
            }
            final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                // period selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: FinPeriod.values.map((p) {
                    final sel = p == _period;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.name[0].toUpperCase() + p.name.substring(1)),
                        selected: sel,
                        onSelected: (_) => setState(() => _period = p),
                      ),
                    );
                  }).toList()),
                ),
                Gap.s,
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (_period != FinPeriod.all)
                    IconButton(onPressed: () => setState(() => _anchor = _shift(_period, _anchor, -1)),
                        icon: const Icon(Icons.chevron_left)),
                  Text(_periodLabel(_period, _anchor),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  if (_period != FinPeriod.all)
                    IconButton(onPressed: () => setState(() => _anchor = _shift(_period, _anchor, 1)),
                        icon: const Icon(Icons.chevron_right)),
                ]),
                Gap.s,
                // donut with balance in the middle (white card)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: SizedBox(
                    height: 210,
                    child: Stack(alignment: Alignment.center, children: [
                      PieChart(PieChartData(
                        sectionsSpace: cats.length > 1 ? 2 : 0,
                        centerSpaceRadius: 74,
                        sections: cats.isEmpty
                            ? [PieChartSectionData(value: 1, color: Colors.black12, radius: 24, showTitle: false)]
                            : cats.map((e) => PieChartSectionData(
                                  value: e.value, color: catColor(e.key), radius: 24, showTitle: false)).toList(),
                      )),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Balance', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        Text(taka(balance),
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                                color: balance >= 0 ? AppColors.income : AppColors.expense)),
                        const SizedBox(height: 2),
                        Text('Spent ${taka(expense)}',
                            style: const TextStyle(color: Colors.black54, fontSize: 11)),
                      ]),
                    ]),
                  ),
                ),
                Gap.m,
                Row(children: [
                  Expanded(child: _MoneyPill(label: 'Income', amount: income, color: AppColors.income, icon: Icons.south_west,
                      onTap: () => _showTxnBreakdown(context, ref, range, 'income'))),
                  Gap.m,
                  Expanded(child: _MoneyPill(label: 'Expense', amount: expense, color: AppColors.expense, icon: Icons.north_east,
                      onTap: () => _showTxnBreakdown(context, ref, range, 'expense'))),
                ]),
                Gap.l,
                SectionTitle('Records', icon: Icons.receipt_long, color: AppColors.primary),
                if (txns.isEmpty)
                  const PadCard(child: Text('No records in this period. Tap + or − below.'))
                else
                  ...txns.map((t) => Dismissible(
                        key: ValueKey(t.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: AppColors.expense, borderRadius: BorderRadius.circular(20)),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => repo.deleteTxn(t.id),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PadCard(
                            onTap: () => context.push('/txn-form', extra: t),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(children: [
                              CircleAvatar(
                                backgroundColor: (t.type == 'income' ? AppColors.income : catColor(t.category)).withValues(alpha: 0.15),
                                foregroundColor: t.type == 'income' ? AppColors.income : catColor(t.category),
                                child: Icon(iconForCategory(t.category)),
                              ),
                              Gap.m,
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(t.category, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(['${shortDate(t.date)} · ${TimeOfDay.fromDateTime(t.date).format(context)}',
                                      if (t.note.isNotEmpty) t.note].join(' · '),
                                    style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                              ])),
                              Text('${t.type == 'income' ? '+' : '-'}${taka(t.amount)}',
                                  style: TextStyle(fontWeight: FontWeight.bold,
                                      color: t.type == 'income' ? AppColors.income : AppColors.expense)),
                            ]),
                          ),
                        ),
                      )),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(child: _BigButton(
              label: 'Income', icon: Icons.add, gradient: AppColors.incomeGrad,
              onTap: () => context.push('/txn-form', extra: 'income'))),
            const SizedBox(width: 12),
            Expanded(child: _BigButton(
              label: 'Expense', icon: Icons.remove, gradient: AppColors.expenseGrad,
              onTap: () => context.push('/txn-form', extra: 'expense'))),
          ]),
        ),
      ),
    );
  }
}

class _MoneyPill extends StatelessWidget {
  const _MoneyPill({required this.label, required this.amount, required this.color, required this.icon, this.onTap});
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11.5)),
                Text(taka(amount), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
              ])),
            ]),
          ),
        ),
      );
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.icon, required this.gradient, required this.onTap});
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),
      );
}

/// Bottom sheet listing income/expense entries for a range; each row is editable.
void _showTxnBreakdown(BuildContext context, WidgetRef ref, _Range range, String type) {
  final repo = ref.read(repoProvider);
  final color = type == 'income' ? AppColors.income : AppColors.expense;
  showModalBottomSheet(
    context: context, showDragHandle: true, isScrollControlled: true,
    builder: (ctx) => AnimatedBuilder(
      animation: repo.txnsL,
      builder: (ctx, _) {
        final txns = repo.txnList.where((t) => t.type == type && range.has(t.date)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        final total = txns.fold(0.0, (s, t) => s + t.amount);
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Text(type == 'income' ? 'Income' : 'Expense',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(taka(total), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ),
            if (txns.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Text('No entries.'))
            else
              Flexible(child: ListView(shrinkWrap: true, children: txns.map((t) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15), foregroundColor: color,
                  child: Icon(iconForCategory(t.category))),
                title: Text(t.category, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([fullDate(t.date), if (t.note.isNotEmpty) t.note].join(' · ')),
                trailing: Text(taka(t.amount), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(ctx); context.push('/txn-form', extra: t); },
              )).toList())),
            Gap.s,
          ]),
        );
      },
    ),
  );
}

/// Monefy-style entry: category bubbles + calculator number pad.
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, required this.type, this.existing});
  final String type;
  final Txn? existing;
  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  String? _category;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _account = 'cash';
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _category = e.category;
      _amount.text = e.amount == 0 ? '' : (e.amount == e.amount.roundToDouble() ? e.amount.toStringAsFixed(0) : e.amount.toString());
      _account = e.account;
      _note.text = e.note;
      _date = e.date;
    }
  }

  bool get _isIncome => widget.type == 'income';
  Color get _color => _isIncome ? AppColors.income : AppColors.expense;

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New category'),
        content: TextField(controller: controller, autofocus: true,
            decoration: const InputDecoration(hintText: 'Category name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(repoProvider).saveCategory(Category(id: newId(), name: name, type: widget.type));
      setState(() => _category = name);
    }
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (_category == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a category and enter an amount')));
      return;
    }
    await ref.read(repoProvider).saveTxn(Txn(
      id: widget.existing?.id ?? newId(), type: widget.type, category: _category!,
      amount: amt, date: _date, account: _account, note: _note.text.trim(),
      sourceRef: widget.existing?.sourceRef ?? '',
    ));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final cats = repo.categoriesOf(widget.type);
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? (_isIncome ? 'Edit Income' : 'Edit Expense') : (_isIncome ? 'Add Income' : 'Add Expense')),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
            },
            icon: const Icon(Icons.calendar_today, size: 15),
            label: Text(shortDate(_date)),
          ),
          TextButton.icon(
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
              if (t != null) setState(() => _date = DateTime(_date.year, _date.month, _date.day, t.hour, t.minute));
            },
            icon: const Icon(Icons.access_time, size: 15),
            label: Text(TimeOfDay.fromDateTime(_date).format(context)),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
        // amount (modern tinted field)
        Container(
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _color.withValues(alpha: 0.30)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(children: [
            Text('৳', style: TextStyle(fontSize: 26, color: _color, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _amount,
              autofocus: !editing,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _color),
              decoration: const InputDecoration(border: InputBorder.none, hintText: '0', isDense: true),
            )),
          ]),
        ),
        Gap.l,
        const SectionTitle('Category'),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.86,
          children: [
            ...cats.map((c) => _CatBubble(
                  name: c.name, selected: _category == c.name,
                  onTap: () => setState(() => _category = c.name))),
            _CatBubble(name: 'New', icon: Icons.add, onTap: _addCategory),
          ],
        ),
        Gap.m,
        DropdownButtonFormField<String>(
          initialValue: _account,
          decoration: const InputDecoration(labelText: 'Account'),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash')),
            DropdownMenuItem(value: 'bkash', child: Text('bKash')),
            DropdownMenuItem(value: 'nagad', child: Text('Nagad')),
            DropdownMenuItem(value: 'bank', child: Text('Bank')),
          ],
          onChanged: (v) => setState(() => _account = v ?? 'cash'),
        ),
        Gap.m,
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
        Gap.l,
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _color),
          onPressed: _save,
          child: Text(editing ? 'Update' : (_isIncome ? 'Save Income' : 'Save Expense')),
        ),
      ]),
    );
  }
}

class _CatBubble extends StatelessWidget {
  const _CatBubble({required this.name, this.icon, this.selected = false, this.onTap});
  final String name;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = catColor(name);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: selected ? c : c.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: selected ? Border.all(color: c, width: 2) : null,
          ),
          child: Icon(icon ?? iconForCategory(name), color: selected ? Colors.white : c, size: 20),
        ),
        const SizedBox(height: 3),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5)),
      ]),
    );
  }
}
