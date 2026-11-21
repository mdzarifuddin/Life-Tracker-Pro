import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';

/// Weekly times a student can't take classes (school, private tutor, etc.).
class BusyTimesList extends StatelessWidget {
  const BusyTimesList({super.key, required this.repo, required this.studentId});
  final Repo repo;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final list = repo.busyFor(studentId);
    if (list.isEmpty) {
      return const PadCard(
        child: Text(
          'No busy time. Tap Add to note when this student cannot study (school, private, other).',
        ),
      );
    }
    return Column(
      children: [
        for (final b in list)
          PadCard(
            onTap: () => showBusySheet(context, repo, studentId, existing: b),
            child: Row(
              children: [
                const Icon(Icons.block, color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.label.isEmpty ? 'Busy' : b.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_daysText(b.days)} · ${minutesToTime(b.startMinutes)} – ${minutesToTime(b.endMinutes)}',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete busy time',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text(
                          'Delete "${b.label.isEmpty ? 'Busy time' : b.label}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await repo.deleteBusy(b.id);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _daysText(List<int> days) {
  final d = [...days]..sort();
  if (d.length == 7) return 'Every day';
  return d.where((i) => i >= 0 && i < 7).map((i) => weekdayNames[i]).join(', ');
}

Future<void> showBusySheet(
  BuildContext context,
  Repo repo,
  String studentId, {
  BusyTime? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _BusySheet(repo: repo, studentId: studentId, existing: existing),
  );
}

class _BusySheet extends StatefulWidget {
  const _BusySheet({
    required this.repo,
    required this.studentId,
    this.existing,
  });
  final Repo repo;
  final String studentId;
  final BusyTime? existing;
  @override
  State<_BusySheet> createState() => _BusySheetState();
}

const _reasons = [
  'School',
  'College',
  'University',
  'Coaching',
  'Private tutor',
  'Madrasa',
  'Sports / Hobby',
  'Family / Event',
  'Other',
];

class _BusySheetState extends State<_BusySheet> {
  String _reason = 'School';
  final _label = TextEditingController();
  final _days = <int>{};
  int _start = 9 * 60, _end = 14 * 60;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      if (_reasons.contains(e.label) && e.label != 'Other') {
        _reason = e.label;
      } else {
        _reason = 'Other';
        _label.text = e.label;
      }
      _days.addAll(e.days);
      _start = e.startMinutes;
      _end = e.endMinutes;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final m = start ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (t == null) return;
    setState(
      () => start
          ? _start = t.hour * 60 + t.minute
          : _end = t.hour * 60 + t.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Add busy time' : 'Edit busy time',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              borderRadius: BorderRadius.circular(16),
              menuMaxHeight: 360,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [
                for (final r in _reasons)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => setState(() => _reason = v ?? _reason),
            ),
            if (_reason == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Type the reason'),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(weekdayNames[i]),
                    selected: _days.contains(i),
                    onSelected: (v) =>
                        setState(() => v ? _days.add(i) : _days.remove(i)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text('From ${minutesToTime(_start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text('To ${minutesToTime(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (_saving) return;
                  String? err;
                  if (_days.isEmpty) {
                    err = 'Pick at least one day';
                  } else if (_end <= _start) {
                    err = 'End time must be after start time';
                  }
                  if (err != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err)));
                    return;
                  }
                  _saving = true;
                  await widget.repo.saveBusy(
                    BusyTime(
                      id: widget.existing?.id ?? newId(),
                      studentId: widget.studentId,
                      label: _reason == 'Other'
                          ? (_label.text.trim().isEmpty
                                ? 'Other'
                                : _label.text.trim())
                          : _reason,
                      days: _days.toList()..sort(),
                      startMinutes: _start,
                      endMinutes: _end,
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
