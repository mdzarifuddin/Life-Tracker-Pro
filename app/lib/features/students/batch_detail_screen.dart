import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';
import '../payments/payments_screen.dart' show showFeeSheet, feeStatusColor, feeStatusLabel;
import 'students_screen.dart' show StudentAvatar, setStudentCurrent;

/// One batch: members (add / remove / move to previous), attendance (who missed
/// which day) and each student's own payment.
class BatchDetailScreen extends ConsumerStatefulWidget {
  const BatchDetailScreen({super.key, required this.batch});
  final String batch;
  @override
  ConsumerState<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends ConsumerState<BatchDetailScreen> {
  late String _batch = widget.batch;

  Future<void> _rename() async {
    final c = TextEditingController(text: _batch);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename batch'),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == _batch) return;
    final repo = ref.read(repoProvider);
    for (final s in repo.batchMembers(_batch)) {
      await repo.saveStudent(Student.fromMap({...s.toMap(), 'batch': name}));
    }
    if (mounted) setState(() => _batch = name);
  }

  Future<void> _showAbsences(Student s) {
    final repo = ref.read(repoProvider);
    final list = repo.absencesFor(s.id);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          Text('${s.name} · absent days (${list.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Never absent.')),
          for (final a in list)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy, color: AppColors.expense),
              title: Text(fullDate(DateTime.parse(a.date))),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () { repo.deleteAbsence(a.id); Navigator.pop(ctx); }),
            ),
        ]),
      )),
    );
  }

  /// Give one student a different fee: for all coming months, or just this month.
  Future<void> _editFee(Student s) async {
    final repo = ref.read(repoProvider);
    final month = repo.currentCycleMonth(s);
    final st = repo.payState(s, month);
    final c = TextEditingController(
        text: (s.monthlyFee == 0 ? '' : s.monthlyFee.toStringAsFixed(0)));
    final thisMonth = TextEditingController(text: st.due == 0 ? '' : st.due.toStringAsFixed(0));
    var onlyThisMonth = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text('Fee for ${s.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('From now on')),
              ButtonSegment(value: true, label: Text('This month only')),
            ],
            selected: {onlyThisMonth},
            onSelectionChanged: (v) => setS(() => onlyThisMonth = v.first),
          ),
          const SizedBox(height: 12),
          if (!onlyThisMonth)
            TextField(
              controller: c, autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  prefixText: '৳ ',
                  labelText: s.payPerClass ? 'Fee per class' : 'Monthly fee',
                  helperText: 'Every month, until you change it again'),
            )
          else
            TextField(
              controller: thisMonth, autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  prefixText: '৳ ',
                  labelText: 'Total for this month',
                  helperText: 'Other months keep the normal fee'),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      )),
    );
    if (ok != true) return;
    if (onlyThisMonth) {
      final v = double.tryParse(thisMonth.text.trim());
      if (v != null) await repo.setCustomDue(s, month, v);
    } else {
      final v = double.tryParse(c.text.trim());
      if (v != null) await repo.saveStudent(Student.fromMap({...s.toMap(), 'monthlyFee': v}));
    }
  }

  void _attendance(DateTime day) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _AttendanceSheet(batch: _batch, day: day),
      );

  void _addStudents() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _AddMembersSheet(batch: _batch),
      );

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_batch),
        actions: [IconButton(tooltip: 'Rename batch', icon: const Icon(Icons.edit), onPressed: _rename)],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.studentsL, repo.paymentsL, repo.absencesL, repo.logsL]),
          builder: (context, _) {
            final members = repo.batchMembers(_batch);
            final current = members.where((s) => s.isCurrent).toList();
            var collected = 0.0, pending = 0.0;
            for (final s in current) {
              final st = repo.payState(s, repo.currentCycleMonth(s));
              collected += st.paid;
              pending += st.remaining;
            }
            final ids = members.map((s) => s.id).toSet();
            final names = {for (final s in members) s.id: s.name};
            final byDate = <String, List<String>>{};
            for (final a in repo.absenceList.where((a) => ids.contains(a.studentId))) {
              byDate.putIfAbsent(a.date, () => []).add(names[a.studentId] ?? '?');
            }
            final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
              Row(children: [
                Expanded(child: GradientStatCard(label: 'Collected', value: taka(collected),
                    gradient: AppColors.incomeGrad, icon: Icons.check_circle)),
                Gap.m,
                Expanded(child: GradientStatCard(label: 'Pending', value: taka(pending),
                    gradient: AppColors.warningGrad, icon: Icons.schedule)),
              ]),
              Gap.m,
              Row(children: [
                Expanded(child: FilledButton.icon(
                  onPressed: current.isEmpty ? null : () => _attendance(DateTime.now()),
                  icon: const Icon(Icons.fact_check_outlined), label: const Text('Take attendance'))),
                Gap.m,
                Expanded(child: FilledButton.tonalIcon(
                  onPressed: _addStudents,
                  icon: const Icon(Icons.person_add_alt), label: const Text('Add students'))),
              ]),
              Gap.l,
              SectionTitle('Students (${current.length})', icon: Icons.groups_2_outlined, color: AppColors.primary),
              if (members.isEmpty) const PadCard(child: Text('No students in this batch yet.')),
              for (final s in members) _memberCard(context, repo, s),
              if (dates.isNotEmpty) ...[
                Gap.l,
                const SectionTitle('Who missed which day', icon: Icons.event_busy, color: AppColors.expense),
                for (final d in dates.take(20))
                  PadCard(
                    onTap: () => _attendance(DateTime.parse(d)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.event_busy, color: AppColors.expense, size: 20),
                      Gap.m,
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fullDate(DateTime.parse(d)), style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Absent: ${byDate[d]!.join(', ')}',
                            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
                      ])),
                    ]),
                  ),
              ],
            ]);
          },
        ),
      ),
    );
  }

  Widget _memberCard(BuildContext context, Repo repo, Student s) {
    final month = repo.currentCycleMonth(s);
    final st = repo.payState(s, month);
    final a = repo.cycleStart(s, month), b = repo.cycleEnd(s, month);
    final missed = repo.absencesFor(s.id).where((x) {
      final d = DateTime.tryParse(x.date);
      return d != null && !d.isBefore(a) && !d.isAfter(b);
    }).length;
    final color = feeStatusColor(st.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PadCard(
        onTap: () => context.push('/students/${s.id}'),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(children: [
          StudentAvatar(s),
          Gap.m,
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Wrap(spacing: 6, runSpacing: 2, children: [
              if (!s.isCurrent) const InfoChip(Icons.history, 'Previous', color: AppColors.expense),
              InfoChip(Icons.sell_outlined,
                  s.payPerClass ? '${taka(s.monthlyFee)}/class' : '${taka(s.monthlyFee)}/mo',
                  color: AppColors.savings),
              InfoChip(Icons.event_busy, 'Absent $missed', color: missed > 0 ? AppColors.expense : AppColors.savings),
              InfoChip(Icons.payments, '${feeStatusLabel(st.status)} · ${taka(st.paid)}/${taka(st.total)}', color: color),
            ]),
          ])),
          IconButton(
            tooltip: 'Payment',
            icon: const Icon(Icons.attach_money, color: AppColors.income),
            onPressed: () => showFeeSheet(context, ref, s, month)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'absent') _showAbsences(s);
              if (v == 'fee') _editFee(s);
              if (v == 'remove') {
                await repo.saveStudent(Student.fromMap({...s.toMap(), 'batch': ''}));
              }
              if (v == 'previous' && context.mounted) setStudentCurrent(context, ref, s, false);
              if (v == 'current' && context.mounted) setStudentCurrent(context, ref, s, true);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'fee', child: Text('Change fee')),
              const PopupMenuItem(value: 'absent', child: Text('Absent days')),
              if (s.isCurrent)
                const PopupMenuItem(value: 'previous', child: Text('Move to past students'))
              else
                const PopupMenuItem(value: 'current', child: Text('Make current again')),
              const PopupMenuItem(value: 'remove', child: Text('Remove from batch')),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Mark who was present / absent on a date. Everyone starts present.
class _AttendanceSheet extends ConsumerStatefulWidget {
  const _AttendanceSheet({required this.batch, required this.day});
  final String batch;
  final DateTime day;
  @override
  ConsumerState<_AttendanceSheet> createState() => _AttendanceSheetState();
}

class _AttendanceSheetState extends ConsumerState<_AttendanceSheet> {
  late DateTime _day = DateTime(widget.day.year, widget.day.month, widget.day.day);
  final _topics = TextEditingController();
  final _absent = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _topics.dispose();
    super.dispose();
  }

  void _load() {
    final repo = ref.read(repoProvider);
    final key = dateKey(_day);
    _absent
      ..clear()
      ..addAll(repo.absenceList.where((a) => a.date == key).map((a) => a.studentId));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final members = repo.batchMembers(widget.batch).where((s) => s.isCurrent).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(child: Text('Attendance · ${widget.batch}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 18),
                label: Text(fullDate(_day)),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _day,
                      firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) setState(() { _day = DateTime(d.year, d.month, d.day); _load(); });
                },
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _topics,
              decoration: const InputDecoration(labelText: 'Topics covered (optional)', isDense: true),
            ),
          ),
          Flexible(child: ListView(shrinkWrap: true, children: [
            for (final s in members)
              SwitchListTile(
                dense: true,
                activeThumbColor: AppColors.income,
                title: Text(s.name),
                subtitle: Text(_absent.contains(s.id) ? 'Absent' : 'Present',
                    style: TextStyle(
                        color: _absent.contains(s.id) ? AppColors.expense : AppColors.income,
                        fontWeight: FontWeight.w600)),
                value: !_absent.contains(s.id),
                onChanged: (present) => setState(() => present ? _absent.remove(s.id) : _absent.add(s.id)),
              ),
          ])),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () async {
                await repo.saveBatchAttendance(widget.batch, _day, _absent, members,
                    topics: _topics.text.trim());
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('Save · ${members.length - _absent.length} present, ${_absent.length} absent'),
            )),
          ),
        ]),
      )),
    );
  }
}

/// Add more students to a batch: move existing ones in and/or create new ones that
/// copy the batch's fee, days, time and subjects.
class _AddMembersSheet extends ConsumerStatefulWidget {
  const _AddMembersSheet({required this.batch});
  final String batch;
  @override
  ConsumerState<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends ConsumerState<_AddMembersSheet> {
  final _picked = <String>{};
  final _newNames = <String>[];
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _addName() {
    final n = _input.text.trim();
    if (n.isEmpty) return;
    setState(() { _newNames.add(n); _input.clear(); });
  }

  Future<void> _save() async {
    _addName();
    final repo = ref.read(repoProvider);
    final current = repo.batchMembers(widget.batch).where((s) => s.isCurrent).toList();
    final tpl = current.isEmpty ? null : current.first;
    for (final n in _newNames) {
      final base = tpl == null ? <String, dynamic>{} : tpl.toMap();
      await repo.saveStudent(Student.fromMap({
        ...base,
        'id': newId(), 'name': n, 'phone': '', 'photo': '', 'extraPhones': <String>[],
        'guardians': <Map<String, dynamic>>[], 'guardianName': '', 'guardianPhone': '',
        'status': 'active', 'leftOn': '', 'batch': widget.batch,
      }));
    }
    for (final id in _picked) {
      final s = repo.student(id);
      if (s != null) await repo.saveStudent(Student.fromMap({...s.toMap(), 'batch': widget.batch}));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final others = repo.currentStudents.where((s) => s.batch != widget.batch).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(alignment: Alignment.centerLeft,
                child: Text('Add to ${widget.batch}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _input,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'New student name', isDense: true,
                helperText: 'Gets this batch\'s fee, days, time and subjects',
                suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _addName)),
              onSubmitted: (_) => _addName(),
            ),
          ),
          if (_newNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 6, children: [
                for (final n in _newNames)
                  InputChip(label: Text(n), onDeleted: () => setState(() => _newNames.remove(n))),
              ])),
            ),
          if (others.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(alignment: Alignment.centerLeft,
                  child: Text('Or pick existing students', style: TextStyle(fontWeight: FontWeight.w700))),
            ),
            Flexible(child: ListView(shrinkWrap: true, children: [
              for (final s in others)
                CheckboxListTile(
                  dense: true,
                  value: _picked.contains(s.id),
                  title: Text(s.name),
                  subtitle: s.batch.isEmpty ? null : Text('now in ${s.batch}'),
                  onChanged: (v) => setState(() => v == true ? _picked.add(s.id) : _picked.remove(s.id)),
                ),
            ])),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity, child: FilledButton(
              onPressed: _save, child: const Text('Add'))),
          ),
        ]),
      )),
    );
  }
}
