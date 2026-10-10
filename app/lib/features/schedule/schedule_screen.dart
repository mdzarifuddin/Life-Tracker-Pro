import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';
import 'routines_screen.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule'), actions: [
        IconButton(
          tooltip: 'Routine pictures',
          icon: const Icon(Icons.photo_library_outlined),
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const RoutinesScreen())),
        ),
      ]),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([repo.schedulesL, repo.studentsL]),
          builder: (context, _) {
            final conflicts = repo.conflictIds;
            final all = repo.scheduleList;
            final dated = repo.datedUpcoming;
            if (all.isEmpty) {
              return EmptyState(
                icon: Icons.calendar_today_outlined,
                message: 'No classes scheduled.\nAdd your weekly timetable.',
                cta: 'Add Class',
                onCta: () => openScheduleSheet(context, ref),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (conflicts.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(children: [
                      Icon(Icons.warning_amber, color: AppColors.expense),
                      SizedBox(width: 8),
                      Expanded(child: Text('You have overlapping classes (in red).')),
                    ]),
                  ),
                if (dated.isNotEmpty) ...[
                  SectionTitle('Booked dates', icon: Icons.event_available, color: AppColors.savings),
                  for (final k in dated.map((e) => e.onDate).toSet()) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Text(
                          '${_dayName(DateTime.parse(k).weekday - 1)} · ${fullDate(DateTime.parse(k))}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).hintColor)),
                    ),
                    ...dated.where((e) => e.onDate == k).map((s) => _card(context, ref, repo, s, conflicts)),
                  ],
                  Gap.m,
                ],
                for (var d = 0; d < 7; d++)
                  if (repo.scheduleForDay(d).isNotEmpty) ...[
                    SectionTitle('${_dayName(d)} · ${shortDate(_nextDate(d))}'),
                    ...repo.scheduleForDay(d).map((s) => _card(context, ref, repo, s, conflicts)),
                  ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addSchedule',
        onPressed: () => openScheduleSheet(context, ref),
        icon: const Icon(Icons.add), label: const Text('Class'),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Repo repo, ScheduleItem s, Set<String> conflicts) {
    final st = repo.student(s.studentId);
    final conflict = conflicts.contains(s.id);
    return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: conflict ? AppColors.expense : Theme.of(context).dividerColor,
                                width: conflict ? 1.5 : 1),
                          ),
                          child: ListTile(
                            onTap: () => openScheduleSheet(context, ref, existing: s),
                            leading: s.isPersonal
                                ? CircleAvatar(
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                    foregroundColor: AppColors.primary,
                                    child: const Icon(Icons.event_note))
                                : InitialAvatar(st?.name ?? '?'),
                            title: Text(s.isPersonal ? s.title : (st?.name ?? 'Unknown'),
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${minutesToTime(s.startMinutes)} · ${s.durationMin} min'
                                '${s.isDated ? '' : ' · every week'}'
                                '${s.location.isNotEmpty ? ' · ${s.location}' : ''}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.edit, size: 16),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => repo.deleteSchedule(s.id),
                              ),
                            ]),
                          ),
                        ),
    );
  }

  String _dayName(int d) =>
      ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d];

  /// Next calendar date that falls on weekday [d] (0 = Monday).
  DateTime _nextDate(int d) {
    final now = DateTime.now();
    var delta = (d - (now.weekday - 1)) % 7;
    if (delta < 0) delta += 7;
    return DateTime(now.year, now.month, now.day).add(Duration(days: delta));
  }

}

void openScheduleSheet(BuildContext context, WidgetRef ref, {ScheduleItem? existing, String? presetStudentId}) {
  showModalBottomSheet(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ScheduleSheet(existing: existing, presetStudentId: presetStudentId),
    ),
  );
}

class _ScheduleSheet extends ConsumerStatefulWidget {
  const _ScheduleSheet({this.existing, this.presetStudentId});
  final ScheduleItem? existing;
  final String? presetStudentId;
  @override
  ConsumerState<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends ConsumerState<_ScheduleSheet> {
  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  String? _studentId;
  int _day = DateTime.now().weekday - 1;
  DateTime _dayDate = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 16, minute: 0);
  int _duration = 60;
  bool _isPersonal = false;
  bool _weekly = true; // false = book specific date(s) in advance
  final _dates = <DateTime>[];
  final _title = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _isPersonal = e.isPersonal;
      _studentId = e.isPersonal ? null : e.studentId;
      _title.text = e.title;
      _day = e.dayOfWeek;
      if (e.isDated && e.dateOn != null) {
        _weekly = false;
        _dates.add(e.dateOn!);
      }
      _time = TimeOfDay(hour: e.startMinutes ~/ 60, minute: e.startMinutes % 60);
      _duration = e.durationMin == 0 ? 60 : e.durationMin;
      final today = DateTime.now();
      var delta = (_day - (today.weekday - 1)) % 7;
      if (delta < 0) delta += 7;
      _dayDate = DateTime(today.year, today.month, today.day).add(Duration(days: delta));
    } else {
      _studentId = widget.presetStudentId;
      _applyDefaultTime();
    }
  }

  void _applyDefaultTime() {
    if (_studentId == null) return;
    final s = ref.read(repoProvider).student(_studentId!);
    if (s != null) {
      _time = TimeOfDay(hour: s.defaultTimeMinutes ~/ 60, minute: s.defaultTimeMinutes % 60);
    }
  }

  String _fmtDur(int m) {
    final h = m ~/ 60, mm = m % 60;
    return '${h > 0 ? '${h}h ' : ''}${mm > 0 ? '${mm}m' : (h > 0 ? '' : '0m')}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.read(repoProvider).pickableStudents(_studentId);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.existing == null ? 'Add Class' : 'Edit Class',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Gap.m,
        if (widget.presetStudentId == null) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Tuition'), icon: Icon(Icons.school)),
              ButtonSegment(value: true, label: Text('Personal'), icon: Icon(Icons.event_note)),
            ],
            selected: {_isPersonal},
            onSelectionChanged: (s) => setState(() => _isPersonal = s.first),
          ),
          Gap.s,
        ],
        if (_isPersonal)
          TextField(controller: _title,
              decoration: const InputDecoration(labelText: 'Event (Doctor, Meeting, Visit…)'))
        else
          DropdownButtonFormField<String>(
            initialValue: _studentId,
            decoration: const InputDecoration(labelText: 'Student'),
            items: students.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
            onChanged: (v) => setState(() { _studentId = v; _applyDefaultTime(); }),
          ),
        if (widget.existing == null) ...[
          Gap.s,
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Every week'), icon: Icon(Icons.repeat)),
              ButtonSegment(value: false, label: Text('Specific dates'), icon: Icon(Icons.event)),
            ],
            selected: {_weekly},
            onSelectionChanged: (s) => setState(() => _weekly = s.first),
          ),
        ],
        if (_weekly)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('Day'),
            subtitle: Text('${_dayNames[_day]} · from ${shortDate(_dayDate)}'),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _dayDate,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() { _dayDate = d; _day = d.weekday - 1; });
            },
          )
        else ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available),
            title: Text(widget.existing == null ? 'Dates' : 'Date'),
            subtitle: _dates.isEmpty ? const Text('Tap to pick a date') : null,
            trailing: (widget.existing != null && _dates.isNotEmpty)
                ? null
                : const Icon(Icons.add),
            onTap: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: _dates.isEmpty ? DateTime.now() : _dates.last,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d == null) return;
              final day = DateTime(d.year, d.month, d.day);
              setState(() {
                if (widget.existing != null) _dates.clear();
                if (!_dates.contains(day)) _dates.add(day);
                _dates.sort();
              });
            },
          ),
          if (_dates.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 6, runSpacing: 4, children: _dates.map((d) => InputChip(
                    label: Text('${_dayNames[d.weekday - 1].substring(0, 3)}, ${shortDate(d)}'),
                    onDeleted: () => setState(() => _dates.remove(d)),
                  )).toList()),
            ),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.access_time),
          title: const Text('Time'),
          subtitle: Text(_time.format(context)),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _time);
            if (t != null) setState(() => _time = t);
          },
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Duration', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: _duration > 15 ? () => setState(() => _duration -= 15) : null,
            icon: const Icon(Icons.remove)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(_fmtDur(_duration), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          IconButton.filledTonal(
            onPressed: _duration < 360 ? () => setState(() => _duration += 15) : null,
            icon: const Icon(Icons.add)),
        ]),
        Gap.l,
        FilledButton(
          onPressed: () async {
            if (_isPersonal ? _title.text.trim().isEmpty : _studentId == null) return;
            if (!_weekly && _dates.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pick at least one date')));
              return;
            }
            final repo = ref.read(repoProvider);
            ScheduleItem build(String id, int day, String onDate) => ScheduleItem(
                  id: id,
                  studentId: _isPersonal ? '' : _studentId!,
                  title: _isPersonal ? _title.text.trim() : '',
                  dayOfWeek: day,
                  startMinutes: _time.hour * 60 + _time.minute, durationMin: _duration,
                  location: widget.existing?.location ?? '',
                  reminderMin: widget.existing?.reminderMin ?? 30,
                  onDate: onDate,
                );
            if (_weekly) {
              await repo.saveSchedule(build(widget.existing?.id ?? newId(), _day, ''));
            } else {
              // one class per picked date (editing keeps the original item)
              for (var i = 0; i < _dates.length; i++) {
                final d = _dates[i];
                await repo.saveSchedule(build(
                    i == 0 && widget.existing != null ? widget.existing!.id : newId(),
                    d.weekday - 1, dateKey(d)));
              }
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
        Gap.s,
      ]),
    );
  }
}
