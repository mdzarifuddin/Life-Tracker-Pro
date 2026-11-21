import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models.dart';

String planSummary(FeePlan p) {
  String n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final String base;
  switch (p.kind) {
    case FeePlan.perClass:
      base = '৳${n(p.amount)} per class';
      break;
    case FeePlan.package:
      base = '৳${n(p.amount)} per ${p.packageSize}-class package';
      break;
    case FeePlan.fixed:
      base = '৳${n(p.amount)} one-time';
      break;
    default:
      base = p.classesPerCycle > 0
          ? '৳${n(p.amount)}/month for ${p.classesPerCycle} classes'
          : '৳${n(p.amount)}/month';
  }
  final extras = [
    if (p.discountPct > 0) '${n(p.discountPct)}% off',
    if (p.discountFlat > 0) '৳${n(p.discountFlat)} off',
  ];
  return extras.isEmpty ? base : '$base · ${extras.join(' · ')}';
}

/// Edit one fee plan. Returns the new plan, or null if cancelled.
/// [askFrom]: let the user choose the month it starts from.
Future<FeePlan?> showPlanEditor(
  BuildContext context, {
  required FeePlan initial,
  required FeeSettings cfg,
  bool askFrom = true,
  String title = 'Fee plan',
}) {
  return showModalBottomSheet<FeePlan>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlanEditor(initial: initial, cfg: cfg, askFrom: askFrom, title: title),
  );
}

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({required this.initial, required this.cfg, required this.askFrom, required this.title});
  final FeePlan initial;
  final FeeSettings cfg;
  final bool askFrom;
  final String title;
  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  late String _kind;
  late String _from;
  late bool _prorate;
  late final TextEditingController _amount, _classes, _pkg, _pct, _flat, _due, _grace, _late;

  static String _t(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _kind = p.kind;
    _from = p.from;
    _prorate = p.classesPerCycle > 0;
    _amount = TextEditingController(text: _t(p.amount));
    _classes = TextEditingController(text: p.classesPerCycle > 0 ? '${p.classesPerCycle}' : '');
    _pkg = TextEditingController(text: p.packageSize > 0 ? '${p.packageSize}' : '');
    _pct = TextEditingController(text: _t(p.discountPct));
    _flat = TextEditingController(text: _t(p.discountFlat));
    _due = TextEditingController(text: p.dueDay == null ? '' : '${p.dueDay}');
    _grace = TextEditingController(text: p.graceDays == null ? '' : '${p.graceDays}');
    _late = TextEditingController(text: p.lateFee == null ? '' : _t(p.lateFee!));
  }

  @override
  void dispose() {
    for (final c in [_amount, _classes, _pkg, _pct, _flat, _due, _grace, _late]) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
  int? _optInt(TextEditingController c) => c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());

  FeePlan _build() => FeePlan(
        id: widget.initial.id,
        from: _from,
        kind: _kind,
        label: widget.initial.label,
        amount: _d(_amount),
        classesPerCycle: _kind == FeePlan.monthly && _prorate ? (int.tryParse(_classes.text.trim()) ?? 0) : 0,
        packageSize: _kind == FeePlan.package ? (int.tryParse(_pkg.text.trim()) ?? 0) : 0,
        discountPct: _d(_pct).clamp(0, 100).toDouble(),
        discountFlat: _d(_flat),
        dueDay: _optInt(_due)?.clamp(0, 31),
        graceDays: _optInt(_grace)?.clamp(0, 90),
        lateFee: _late.text.trim().isEmpty ? null : _d(_late),
      );

  Widget _num(TextEditingController c, String label, {String? prefix, String? helper, bool decimal = true}) => TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]'))],
        decoration: InputDecoration(labelText: label, prefixText: prefix, helperText: helper),
      );

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final init = _from.isEmpty ? DateTime(now.year, now.month) : DateTime.parse('$_from-01');
    final d = await showDatePicker(
        context: context, initialDate: init, firstDate: DateTime(2020), lastDate: DateTime(2100),
        helpText: 'Starts from the month of…');
    if (d != null) setState(() => _from = monthKey(d));
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final plan = _build();
    final valid = plan.amount > 0 && (_kind != FeePlan.package || plan.packageSize > 0) &&
        !(_kind == FeePlan.monthly && _prorate && plan.classesPerCycle <= 0);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            Gap.m,
            if (widget.cfg.templates.isNotEmpty) ...[
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                for (final t in widget.cfg.templates)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.bookmark_outline, size: 16),
                      label: Text(t.label.isEmpty ? planSummary(t) : t.label),
                      onPressed: () => setState(() {
                        _kind = t.kind;
                        _prorate = t.classesPerCycle > 0;
                        _amount.text = _t(t.amount);
                        _classes.text = t.classesPerCycle > 0 ? '${t.classesPerCycle}' : '';
                        _pkg.text = t.packageSize > 0 ? '${t.packageSize}' : '';
                        _pct.text = _t(t.discountPct);
                        _flat.text = _t(t.discountFlat);
                      }),
                    ),
                  ),
              ])),
              Gap.m,
            ],
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: FeePlan.monthly, label: Text('Monthly')),
                ButtonSegment(value: FeePlan.perClass, label: Text('Per class')),
                ButtonSegment(value: FeePlan.package, label: Text('Package')),
                ButtonSegment(value: FeePlan.fixed, label: Text('One-time')),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            Gap.m,
            _num(
              _amount,
              switch (_kind) {
                FeePlan.perClass => 'Fee per class',
                FeePlan.package => 'Price of one package',
                FeePlan.fixed => 'One-time amount',
                _ => 'Monthly fee',
              },
              prefix: '৳ ',
            ),
            if (_kind == FeePlan.monthly) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pro-rate by classes taught'),
                subtitle: const Text('Fee ÷ classes per month × classes actually taken'),
                value: _prorate,
                onChanged: (v) => setState(() => _prorate = v),
              ),
              if (_prorate) _num(_classes, 'Classes per month', decimal: false),
            ],
            if (_kind == FeePlan.package) ...[
              Gap.s,
              _num(_pkg, 'Classes in one package', decimal: false,
                  helper: 'A new package is charged each time this many classes are taken'),
            ],
            Gap.m,
            Text('Discount / scholarship (every cycle)', style: TextStyle(color: hint, fontSize: 12)),
            Gap.s,
            Row(children: [
              Expanded(child: _num(_pct, 'Percent', prefix: '% ')),
              Gap.m,
              Expanded(child: _num(_flat, 'Flat amount', prefix: '৳ ')),
            ]),
            Gap.m,
            Text('Due date (leave empty to use your settings)', style: TextStyle(color: hint, fontSize: 12)),
            Gap.s,
            Row(children: [
              Expanded(child: _num(_due, 'Due day', decimal: false, helper: '0 = last day of cycle')),
              Gap.m,
              Expanded(child: _num(_grace, 'Grace days', decimal: false)),
            ]),
            Gap.s,
            _num(_late, 'Late fee if unpaid after grace', prefix: '৳ ',
                helper: 'Empty = use settings, 0 = never'),
            if (widget.askFrom) ...[
              Gap.m,
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(_from.isEmpty ? 'Applies from the beginning' : 'Applies from ${monthLabel(DateTime.parse('$_from-01'))}'),
                subtitle: const Text('Earlier months keep their old fee'),
                trailing: const Icon(Icons.edit_calendar),
                onTap: _pickFrom,
              ),
            ],
            Gap.s,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(valid ? planSummary(plan) : 'Fill in the amount to see a summary',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Gap.m,
            FilledButton(
              onPressed: valid ? () => Navigator.pop(context, plan) : null,
              child: const Text('Save plan'),
            ),
          ]),
        ),
      ),
    );
  }
}
