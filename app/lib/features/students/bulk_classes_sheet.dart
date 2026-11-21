import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/bulk_classes.dart';
import '../../core/data.dart';
import '../../core/theme.dart';
import '../../models.dart';

/// Type classes as text ("Jan_26:" then "Labib - 3,5,8,16") and add them all at once.
Future<void> showBulkClassesSheet(BuildContext context, Repo repo) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BulkSheet(repo: repo),
  );
}

class _BulkSheet extends StatefulWidget {
  const _BulkSheet({required this.repo});
  final Repo repo;
  @override
  State<_BulkSheet> createState() => _BulkSheetState();
}

class _BulkSheetState extends State<_BulkSheet> {
  final _text = TextEditingController();
  bool _busy = false;
  bool _create = true;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<BulkEntry> get _entries => parseBulkClasses(
        _text.text,
        widget.repo.studentList,
        (id) => widget.repo.logsFor(id).map((l) => l.date).toList(),
      );

  Future<void> _add(List<BulkEntry> entries) async {
    if (_busy) return;
    setState(() => _busy = true);
    var n = 0;
    final created = <String, Student>{}; // new students made from this text, by lowercase name
    for (final e in entries) {
      var st = e.student;
      if (st == null && _create && e.days.isNotEmpty) {
        st = created[e.name.toLowerCase()];
        if (st == null) {
          st = Student(id: newId(), name: e.name);
          await widget.repo.saveStudent(st);
          created[e.name.toLowerCase()] = st;
        }
      }
      if (st == null) continue;
      final t = st.defaultTimeMinutes;
      for (final d in e.days) {
        await widget.repo.saveLog(ClassLog(
          id: newId(), studentId: st.id,
          date: DateTime(e.year, e.month, d, (t ~/ 60) % 24, t % 60),
        ));
        n++;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $n classes')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final entries = _entries;
    bool ok(BulkEntry e) => e.matched || _create;
    final total = entries.where(ok).fold(0, (s, e) => s + e.days.length);
    final newNames = {for (final e in entries) if (!e.matched && e.days.isNotEmpty) e.name.toLowerCase()};
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add many classes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Paste or type your notes: month, then each student and the days.\n'
                'Example:  Jan_26:  then  Labib - 3,5,8,16,17\n'
                'Money lines (Done / Amount) are ignored.',
                style: TextStyle(color: hint, fontSize: 12.5)),
            Gap.m,
            TextField(
              controller: _text,
              minLines: 4,
              maxLines: 8,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Jan_26:\nLabib - 3,5,8,16',
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste),
                  onPressed: () async {
                    final d = await Clipboard.getData(Clipboard.kTextPlain);
                    if (d?.text != null) setState(() => _text.text = d!.text!);
                  },
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Create students that are not in the app'),
              subtitle: Text(newNames.isEmpty ? 'All names matched' : '${newNames.length} new: ${newNames.take(6).join(', ')}'
                  '${newNames.length > 6 ? '…' : ''}'),
              value: _create,
              onChanged: (v) => setState(() => _create = v),
            ),
            if (entries.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(shrinkWrap: true, children: [
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(e.matched ? Icons.check_circle : (_create ? Icons.person_add_alt : Icons.error_outline),
                            size: 18,
                            color: ok(e) ? AppColors.income : AppColors.expense),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          '${e.name}${e.matched ? '' : (_create ? ' (new)' : ' — not found')}'
                          ' · ${monthLabel(DateTime(e.year, e.month))} · ${e.days.length} classes'
                          '${e.days.isEmpty ? '' : ' (${e.days.join(', ')})'}'
                          '${e.skipped.isEmpty ? '' : '\nAlready logged: ${e.skipped.join(', ')}'}'
                          '${e.invalid.isEmpty ? '' : '\nNot a day of this month: ${e.invalid.join(', ')}'}',
                          style: TextStyle(color: ok(e) ? null : AppColors.expense, fontSize: 13),
                        )),
                      ]),
                    ),
                ]),
              ),
            Gap.s,
            FilledButton(
              onPressed: total == 0 || _busy ? null : () => _add(entries),
              child: Text(total == 0 ? 'Add classes' : 'Add $total classes'),
            ),
          ]),
        ),
      ),
    );
  }
}
