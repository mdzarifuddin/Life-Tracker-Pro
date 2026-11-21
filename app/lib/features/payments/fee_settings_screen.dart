import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';
import 'fee_widgets.dart';
import 'plan_editor.dart';

/// Everything about fees you can customise.
class FeeSettingsScreen extends ConsumerStatefulWidget {
  const FeeSettingsScreen({super.key});
  @override
  ConsumerState<FeeSettingsScreen> createState() => _FeeSettingsScreenState();
}

class _FeeSettingsScreenState extends ConsumerState<FeeSettingsScreen> {
  late FeeSettings _c;
  late final Repo _repo;
  final _due = TextEditingController();
  final _grace = TextEditingController();
  final _soon = TextEditingController();
  final _late = TextEditingController();
  final _tutor = TextEditingController();
  final _header = TextEditingController();
  final _footer = TextEditingController();
  final _remind = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = ref.read(repoProvider);
    _c = _repo.feeSettings;
    _due.text = '${_c.defaultDueDay}';
    _grace.text = '${_c.defaultGraceDays}';
    _soon.text = '${_c.dueSoonDays}';
    _late.text = _c.lateFeeAmount.toStringAsFixed(0);
    _tutor.text = _c.tutorName;
    _header.text = _c.receiptHeader;
    _footer.text = _c.receiptFooter;
    _remind.text = _c.reminderTemplate;
  }

  @override
  void dispose() {
    for (final c in [_due, _grace, _soon, _late, _tutor, _header, _footer, _remind]) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(FeeSettings v) {
    setState(() => _c = v);
    _repo.feeSettings = v;
  }

  Widget _int(TextEditingController c, String label, void Function(int) on, {String? helper}) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) => on(int.tryParse(v) ?? 0),
        decoration: InputDecoration(labelText: label, helperText: helper),
      );

  Future<String?> _ask(String title, {String initial = '', String label = 'Name'}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _editMethod(PayMethod? m) async {
    var name = m?.name ?? '';
    var icon = m?.icon ?? 'cash';
    var needsRef = m?.needsRef ?? false;
    final c = TextEditingController(text: name);
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(m == null ? 'New payment method' : 'Edit method'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Name')),
            Gap.s,
            Wrap(spacing: 6, children: [
              for (final k in methodIconKeys)
                ChoiceChip(
                  label: Icon(methodIcon(k), size: 18),
                  selected: icon == k,
                  onSelected: (_) => setD(() => icon = k),
                ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ask for reference / TrxID'),
              value: needsRef,
              onChanged: (v) => setD(() => needsRef = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    name = c.text.trim();
    c.dispose();
    if (res != true || name.isEmpty) return;
    if (m == null) {
      _set(_c.copyWith(methods: [..._c.methods, PayMethod(id: newId(), name: name, icon: icon, needsRef: needsRef)]));
    } else {
      _set(_c.copyWith(methods: [
        for (final x in _c.methods) x.id == m.id ? x.copyWith(name: name, icon: icon, needsRef: needsRef) : x
      ]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Scaffold(
      appBar: AppBar(title: const Text('Fee settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const SectionTitle('Due dates'),
            PadCard(child: Column(children: [
              _int(_due, 'Default due day', (v) => _set(_c.copyWith(defaultDueDay: v.clamp(0, 31))),
                  helper: '0 = last day of the billing cycle'),
              Gap.s,
              _int(_grace, 'Grace days after due date', (v) => _set(_c.copyWith(defaultGraceDays: v.clamp(0, 90))),
                  helper: 'A bill is "overdue" only after this'),
              Gap.s,
              _int(_soon, 'Show "Due soon" this many days before', (v) => _set(_c.copyWith(dueSoonDays: v.clamp(0, 60)))),
            ])),
            const SectionTitle('Late fee'),
            PadCard(child: Column(children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Charge a late fee'),
                subtitle: const Text('Once per overdue month. You can waive it any time.'),
                value: _c.lateFeeOn,
                onChanged: (v) => _set(_c.copyWith(lateFeeOn: v)),
              ),
              if (_c.lateFeeOn)
                _int(_late, 'Late fee amount (৳)', (v) => _set(_c.copyWith(lateFeeAmount: v.toDouble()))),
            ])),
            const SectionTitle('Payment methods'),
            for (final m in _c.methods)
              PadCard(
                padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                onTap: () => _editMethod(m),
                child: Row(children: [
                  Icon(methodIcon(m.icon), size: 20),
                  Gap.m,
                  Expanded(child: Text(m.name + (m.id == _c.defaultMethod ? '  · default' : ''),
                      style: TextStyle(fontWeight: FontWeight.w600, color: m.enabled ? null : hint))),
                  if (m.id != _c.defaultMethod && m.enabled)
                    TextButton(onPressed: () => _set(_c.copyWith(defaultMethod: m.id)), child: const Text('Make default')),
                  Switch(
                    value: m.enabled,
                    onChanged: m.id == _c.defaultMethod
                        ? null
                        : (v) => _set(_c.copyWith(methods: [for (final x in _c.methods) x.id == m.id ? x.copyWith(enabled: v) : x])),
                  ),
                  if (m.id != _c.defaultMethod && _c.methods.length > 1)
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _set(_c.copyWith(methods: _c.methods.where((x) => x.id != m.id).toList())),
                    ),
                ]),
              ),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                icon: const Icon(Icons.add), label: const Text('Add method'), onPressed: () => _editMethod(null))),
            const SectionTitle('Extra charge types'),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final t in _c.chargeTypes)
                InputChip(
                  label: Text(t),
                  onDeleted: () => _set(_c.copyWith(chargeTypes: _c.chargeTypes.where((x) => x != t).toList())),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                onPressed: () async {
                  final v = await _ask('New charge type');
                  if (v != null && v.isNotEmpty) _set(_c.copyWith(chargeTypes: [..._c.chargeTypes, v]));
                },
              ),
            ]),
            const SectionTitle('Fee plan templates'),
            for (final t in _c.templates)
              PadCard(
                onTap: () async {
                  final np = await showPlanEditor(context, initial: t, cfg: _c, askFrom: false, title: 'Edit template');
                  if (np != null) {
                    _set(_c.copyWith(templates: [for (final x in _c.templates) x.id == t.id ? np.copyWith(id: t.id, label: t.label) : x]));
                  }
                },
                child: Row(children: [
                  const Icon(Icons.bookmark_outline, size: 20),
                  Gap.m,
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.label.isEmpty ? 'Template' : t.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(planSummary(t), style: TextStyle(color: hint, fontSize: 12)),
                  ])),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _set(_c.copyWith(templates: _c.templates.where((x) => x.id != t.id).toList())),
                  ),
                ]),
              ),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add template'),
              onPressed: () async {
                final name = await _ask('Template name', label: 'e.g. Class 9–10 · ৳3000');
                if (name == null || name.isEmpty || !context.mounted) return;
                final np = await showPlanEditor(context,
                    initial: FeePlan(id: newId(), label: name), cfg: _c, askFrom: false, title: name);
                if (np != null) _set(_c.copyWith(templates: [..._c.templates, np.copyWith(label: name)]));
              },
            )),
            const SectionTitle('Receipts & reminders'),
            PadCard(child: Column(children: [
              TextField(controller: _tutor, onChanged: (v) => _set(_c.copyWith(tutorName: v.trim())),
                  decoration: const InputDecoration(labelText: 'Your name (shown on receipts)')),
              Gap.s,
              TextField(controller: _header, onChanged: (v) => _set(_c.copyWith(receiptHeader: v)),
                  decoration: const InputDecoration(labelText: 'Receipt header (optional)')),
              Gap.s,
              TextField(controller: _footer, onChanged: (v) => _set(_c.copyWith(receiptFooter: v)),
                  decoration: const InputDecoration(labelText: 'Receipt footer')),
              Gap.s,
              TextField(
                controller: _remind,
                minLines: 3,
                maxLines: 6,
                onChanged: (v) => _set(_c.copyWith(reminderTemplate: v.trim().isEmpty ? FeeSettings.defaultReminder : v)),
                decoration: const InputDecoration(
                  labelText: 'Reminder message',
                  helperMaxLines: 3,
                  helperText: 'Use {guardian} {student} {amount} {month} {due_date} {overdue} {tutor}',
                ),
              ),
              Align(alignment: Alignment.centerRight, child: TextButton(
                onPressed: () {
                  _remind.text = FeeSettings.defaultReminder;
                  _set(_c.copyWith(reminderTemplate: FeeSettings.defaultReminder));
                },
                child: const Text('Reset message'),
              )),
            ])),
          ],
        ),
      ),
    );
  }
}
