import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data.dart';
import '../../core/history.dart';
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
      _msg('Could not read that file');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuition history'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'share') {
                await shareHistory(repo);
              } else if (v == 'save') {
                final p = await saveHistoryToDevice(repo);
                if (p != null) _msg('History saved');
              } else {
                await _import(repo);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.ios_share), title: Text('Share as JSON'))),
              PopupMenuItem(value: 'save', child: ListTile(leading: Icon(Icons.save_alt), title: Text('Save JSON to device'))),
              PopupMenuItem(value: 'import', child: ListTile(leading: Icon(Icons.file_open), title: Text('Import JSON'))),
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
                  Expanded(child: _stat('Students', '${students.length}', Icons.people, AppColors.primary)),
                  Gap.s,
                  Expanded(child: _stat('Classes', '$classes', Icons.menu_book, AppColors.income)),
                ]),
                Gap.s,
                Row(children: [
                  Expanded(child: _stat('Paid classes', '$paidClasses', Icons.check_circle, paidClassColor)),
                  Gap.s,
                  Expanded(child: _stat('Received', taka(received), Icons.payments, AppColors.warning)),
                ]),
                Gap.m,
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('By student'), icon: Icon(Icons.person)),
                    ButtonSegment(value: true, label: Text('Timeline'), icon: Icon(Icons.timeline)),
                  ],
                  selected: {_timeline},
                  onSelectionChanged: (v) => setState(() => _timeline = v.first),
                ),
                Gap.s,
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Search student', prefixIcon: Icon(Icons.search)),
                ),
                Gap.m,
                if (students.isEmpty)
                  const EmptyState(icon: Icons.history, message: 'No students yet.')
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
            subtitle: Text('${logs.length} classes · $paid paid · ${taka(received)} received',
                style: TextStyle(color: hint, fontSize: 12.5)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (logs.isEmpty) Text('No classes yet.', style: TextStyle(color: hint)),
              for (final e in months.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Text('${monthLabel(DateTime.parse('${e.key}-01'))} · ${e.value.length} classes',
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
                    _dot(AppColors.income), const SizedBox(width: 4), const Text('Taught', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 12),
                    _dot(paidClassColor), const SizedBox(width: 4), const Text('Paid', style: TextStyle(fontSize: 12)),
                  ]),
                ),
              if (lump.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Payments', style: TextStyle(fontWeight: FontWeight.w600)),
                for (final x in lump)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.payments_outlined, color: AppColors.warning, size: 20),
                    title: Text(taka(x.$2.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${fullDate(x.$2.date)} · for ${monthLabel(DateTime.parse('${x.$1.month}-01'))}'),
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
    if (rows.isEmpty) return [const EmptyState(icon: Icons.history, message: 'Nothing here yet.')];
    return [
      for (final r in rows.take(400))
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(
            r.isClass ? Icons.menu_book : Icons.payments,
            color: r.isClass ? (r.paid ? paidClassColor : AppColors.income) : AppColors.warning,
          ),
          title: Text(r.isClass ? '${r.s.name} · class' : '${r.s.name} · payment ${taka(r.amount)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(fullDate(r.date), style: TextStyle(color: hint)),
          trailing: r.isClass && r.paid ? const Icon(Icons.check_circle, size: 18, color: paidClassColor) : null,
        ),
      if (rows.length > 400)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Showing the latest 400 of ${rows.length}. Use "By student" or export the JSON for everything.',
              style: TextStyle(color: hint, fontSize: 12)),
        ),
    ];
  }
}
