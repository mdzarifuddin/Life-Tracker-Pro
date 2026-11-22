import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data.dart';
import '../../core/history.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';
import '../students/mark_paid_sheet.dart' show paidClassColor;

/// All students, all classes and all payments in one place, plus JSON export / import.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _timeline = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _import(Repo repo) async {
    try {
      final r = await importHistoryFile(repo);
      if (r != null) _msg(r.summary);
    } on FormatException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg(tr('Could not read that file'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Tuition history')),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'share') {
                await shareHistory(repo);
              } else if (v == 'save') {
                final p = await saveHistoryToDevice(repo);
                if (p != null) _msg(tr('History saved'));
              } else {
                await _import(repo);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'share', child: ListTile(leading: const Icon(Icons.ios_share), title: Text(tr('Share as JSON')))),
              PopupMenuItem(value: 'save', child: ListTile(leading: const Icon(Icons.save_alt), title: Text(tr('Save JSON to device')))),
              PopupMenuItem(value: 'import', child: ListTile(leading: const Icon(Icons.file_open), title: Text(tr('Import JSON')))),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.studentsL, repo.logsL, repo.paymentsL]),
          builder: (context, _) {
            final students = repo.studentList
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            final logs = {for (final s in students) s.id: (repo.logsFor(s.id)..sort((a, b) => b.date.compareTo(a.date)))};
            var classes = 0, paidClasses = 0;
            var received = 0.0;
            for (final s in students) {
              classes += logs[s.id]!.length;
              paidClasses += logs[s.id]!.where((l) => l.isPaid).length;
              received += repo.paymentsOf(s.id).fold(0.0, (t, p) => t + p.paid);
            }
            final q = _search.text.trim().toLowerCase();
            final shown = students.where((s) => q.isEmpty || s.name.toLowerCase().contains(q)).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(children: [
                  Expanded(child: _stat(tr('Students'), '${students.length}', Icons.people, AppColors.primary)),
                  Gap.s,
                  Expanded(child: _stat(tr('Classes'), '$classes', Icons.menu_book, AppColors.income)),
                ]),
                Gap.s,
                Row(children: [
                  Expanded(child: _stat(tr('Paid classes'), '$paidClasses', Icons.check_circle, paidClassColor)),
                  Gap.s,
                  Expanded(child: _stat(tr('Received'), taka(received), Icons.payments, AppColors.warning)),
                ]),
                Gap.m,
                Row(children: [
                  Expanded(child: FilledButton.icon(
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(tr('Export')),
                    onPressed: () => shareHistory(repo),
                  )),
                  Gap.s,
                  Expanded(child: OutlinedButton.icon(
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: Text(tr('Save')),
                    onPressed: () async {
                      final p = await saveHistoryToDevice(repo);
                      if (p != null) _msg(tr('History saved'));
                    },
                  )),
                  Gap.s,
                  Expanded(child: OutlinedButton.icon(
                    icon: const Icon(Icons.file_open, size: 18),
                    label: Text(tr('Import')),
                    onPressed: () => _import(repo),
                  )),
                ]),
                Gap.m,
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, label: Text(tr('By student')), icon: const Icon(Icons.person)),
                    ButtonSegment(value: true, label: Text(tr('Timeline')), icon: const Icon(Icons.timeline)),
                  ],
                  selected: {_timeline},
                  onSelectionChanged: (v) => setState(() => _timeline = v.first),
                ),
                Gap.s,
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: tr('Search student'), prefixIcon: const Icon(Icons.search)),
                ),
                Gap.m,
                if (students.isEmpty)
                  EmptyState(icon: Icons.history, message: tr('No students yet.'))
                else if (_timeline)
                  ..._timelineRows(context, repo, shown, logs)
                else
                  for (final s in shown) _studentTile(context, repo, s, logs[s.id]!),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) => PadCard(
        child: Row(children: [
          Icon(icon, color: color),
          Gap.m,
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
          ])),
        ]),
      );

  /// Payments that are not tied to a single class (lump sums).
  List<(Payment, PayInstallment)> _lump(Repo repo, Student s, List<ClassLog> logs) {
    final linked = {for (final l in logs) if (l.isPaid) l.payId};
    return [
      for (final p in repo.paymentsOf(s.id))
        for (final i in p.installments)
          if (!linked.contains(i.id)) (p, i),
    ]..sort((a, b) => b.$2.date.compareTo(a.$2.date));
  }

  Widget _studentTile(BuildContext context, Repo repo, Student s, List<ClassLog> logs) {
    final hint = Theme.of(context).hintColor;
    final paid = logs.where((l) => l.isPaid).length;
    final received = repo.paymentsOf(s.id).fold(0.0, (t, p) => t + p.paid);
    final lump = _lump(repo, s, logs);
    // newest month first
    final months = <String, List<ClassLog>>{};
    for (final l in logs) {
      (months[monthKey(l.date)] ??= []).add(l);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PadCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: InitialAvatar(s.name),
            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(tr('{n} classes · {p} paid · {a} received', {'n': logs.length, 'p': paid, 'a': taka(received)}),
                style: TextStyle(color: hint, fontSize: 12.5)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (logs.isEmpty) Text(tr('No classes yet.'), style: TextStyle(color: hint)),
              for (final e in months.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Text(tr('{m} · {n} classes', {'m': monthLabel(DateTime.parse('${e.key}-01')), 'n': e.value.length}),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final l in e.value.reversed)
                    Container(
                      width: 38,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: (l.isPaid ? paidClassColor : AppColors.income).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: l.isPaid ? paidClassColor : AppColors.income),
                      ),
                      alignment: Alignment.center,
                      child: Text('${l.date.day}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                ]),
              ],
              if (logs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    _dot(AppColors.income), const SizedBox(width: 4), Text(tr('Taught'), style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 12),
                    _dot(paidClassColor), const SizedBox(width: 4), Text(tr('Paid'), style: const TextStyle(fontSize: 12)),
                  ]),
                ),
              if (lump.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(tr('Payments'), style: const TextStyle(fontWeight: FontWeight.w600)),
                for (final x in lump)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.payments_outlined, color: AppColors.warning, size: 20),
                    title: Text(taka(x.$2.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(tr('{d} · for {m}', {'d': fullDate(x.$2.date), 'm': monthLabel(DateTime.parse('${x.$1.month}-01'))})),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(width: 11, height: 11, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  List<Widget> _timelineRows(BuildContext context, Repo repo, List<Student> students, Map<String, List<ClassLog>> logs) {
    final hint = Theme.of(context).hintColor;
    final rows = <({DateTime date, Student s, bool isClass, bool paid, double amount})>[];
    for (final s in students) {
      for (final l in logs[s.id]!) {
        rows.add((date: l.date, s: s, isClass: true, paid: l.isPaid, amount: 0));
      }
      for (final x in _lump(repo, s, logs[s.id]!)) {
        rows.add((date: x.$2.date, s: s, isClass: false, paid: true, amount: x.$2.amount));
      }
    }
    rows.sort((a, b) => b.date.compareTo(a.date));
    if (rows.isEmpty) return [EmptyState(icon: Icons.history, message: tr('Nothing here yet.'))];
    return [
      for (final r in rows.take(400))
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(
            r.isClass ? Icons.menu_book : Icons.payments,
            color: r.isClass ? (r.paid ? paidClassColor : AppColors.income) : AppColors.warning,
          ),
          title: Text(r.isClass ? tr('{s} · class', {'s': r.s.name}) : tr('{s} · payment {a}', {'s': r.s.name, 'a': taka(r.amount)}),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(fullDate(r.date), style: TextStyle(color: hint)),
          trailing: r.isClass && r.paid ? const Icon(Icons.check_circle, size: 18, color: paidClassColor) : null,
        ),
      if (rows.length > 400)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(tr('Showing the latest 400 of {n}. Use "By student" or export the JSON for everything.', {'n': rows.length}),
              style: TextStyle(color: hint, fontSize: 12)),
        ),
    ];
  }
}
