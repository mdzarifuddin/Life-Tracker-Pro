import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';

Color priorityColor(String p) =>
    p == 'high' ? AppColors.expense : p == 'low' ? AppColors.savings : AppColors.warning;

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: repo.tasksL,
          builder: (context, _) {
            final list = repo.taskList;
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.checklist,
                message: 'No tasks yet.\nSchedule what you need to do.',
                cta: 'Add Task',
                onCta: () => showTaskSheet(context),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: list.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PadCard(
                      onTap: () => showTaskSheet(context, existing: t),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(children: [
                        Checkbox(
                          value: t.done,
                          activeColor: AppColors.income,
                          onChanged: (_) => repo.saveTask(t.copyWith(done: !t.done)),
                        ),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.title, style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: t.done ? TextDecoration.lineThrough : null,
                              color: t.done ? Theme.of(context).hintColor : null)),
                          Text('${fullDate(t.due)} · ${TimeOfDay.fromDateTime(t.due).format(context)}'
                              '${t.note.isNotEmpty ? ' · ${t.note}' : ''}',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: priorityColor(t.priority).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999)),
                          child: Text(t.priority, style: TextStyle(
                              color: priorityColor(t.priority), fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => repo.deleteTask(t.id)),
                      ]),
                    ),
                  )).toList(),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addTask',
        onPressed: () => showTaskSheet(context),
        icon: const Icon(Icons.add), label: const Text('Task'),
      ),
    );
  }
}

void showTaskSheet(BuildContext context, {PersonalTask? existing}) {
  showModalBottomSheet(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _TaskSheet(existing: existing),
    ),
  );
}

class _TaskSheet extends ConsumerStatefulWidget {
  const _TaskSheet({this.existing});
  final PersonalTask? existing;
  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  String _priority = 'med';
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _note.text = e.note;
      _priority = e.priority;
      _date = e.due;
      _time = TimeOfDay(hour: e.due.hour, minute: e.due.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(editing ? 'Edit Task' : 'New Task',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Gap.m,
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Task')),
        Row(children: [
          Expanded(child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, size: 20),
            title: Text(shortDate(_date)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _date = d);
            },
          )),
          Expanded(child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time, size: 20),
            title: Text(_time.format(context)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          )),
        ]),
        DropdownButtonFormField<String>(
          initialValue: _priority,
          decoration: const InputDecoration(labelText: 'Priority'),
          items: const [
            DropdownMenuItem(value: 'high', child: Text('High')),
            DropdownMenuItem(value: 'med', child: Text('Medium')),
            DropdownMenuItem(value: 'low', child: Text('Low')),
          ],
          onChanged: (v) => setState(() => _priority = v ?? 'med'),
        ),
        Gap.s,
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)')),
        Gap.l,
        FilledButton(
          onPressed: () async {
            if (_title.text.trim().isEmpty) return;
            final due = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
            await ref.read(repoProvider).saveTask(PersonalTask(
              id: widget.existing?.id ?? newId(),
              title: _title.text.trim(), note: _note.text.trim(),
              priority: _priority, due: due, done: widget.existing?.done ?? false,
            ));
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(editing ? 'Update' : 'Save'),
        ),
        Gap.s,
      ]),
    );
  }
}
