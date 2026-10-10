import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models.dart';

/// Create a batch: shared fee / days / time / subjects, then add several new
/// students at once and/or move existing students into it.
class BatchFormScreen extends ConsumerStatefulWidget {
  const BatchFormScreen({super.key});
  @override
  ConsumerState<BatchFormScreen> createState() => _BatchFormScreenState();
}

class _NewMember {
  final name = TextEditingController();
  final phone = TextEditingController();
  final fee = TextEditingController(); // empty = the batch fee
  void dispose() {
    name.dispose();
    phone.dispose();
    fee.dispose();
  }
}

class _BatchFormScreenState extends ConsumerState<BatchFormScreen> {
  static const _subjectPreset = [
    'Math', 'Higher Math', 'Physics', 'Chemistry', 'ICT',
  ];
  static const _perMonthOptions = [4, 8, 12, 16, 20, 24, 30];

  final _name = TextEditingController();
  final _fee = TextEditingController();
  final _subjects = <String>{};
  final _days = <String>{};
  final _existing = <String>{}; // ids of current students moved into this batch
  final _members = <_NewMember>[_NewMember()];
  int _perMonth = 8;
  TimeOfDay _time = const TimeOfDay(hour: 16, minute: 0);
  DateTime? _start;

  @override
  void dispose() {
    _name.dispose();
    _fee.dispose();
    for (final m in _members) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _pickContact(_NewMember m) async {
    try {
      final c = await FlutterNativeContactPicker().selectPhoneNumber();
      final number = (c?.selectedPhoneNumber ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
      if (number.isEmpty) return;
      setState(() {
        m.phone.text = number;
        if (m.name.text.trim().isEmpty) m.name.text = c?.fullName ?? '';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open contacts')));
      }
    }
  }

  Future<void> _save() async {
    final batch = _name.text.trim();
    final fresh = _members.where((m) => m.name.text.trim().isNotEmpty).toList();
    if (batch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch name is required')));
      return;
    }
    if (fresh.isEmpty && _existing.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one student')));
      return;
    }
    final repo = ref.read(repoProvider);
    final fee = double.tryParse(_fee.text.trim()) ?? 0;
    for (final m in fresh) {
      await repo.saveStudent(Student(
        id: newId(),
        name: m.name.text.trim(),
        phone: m.phone.text.trim(),
        batch: batch,
        monthlyFee: double.tryParse(m.fee.text.trim()) ?? fee, // own fee if given
        classesPerMonth: _perMonth,
        defaultTimeMinutes: _time.hour * 60 + _time.minute,
        subjects: _subjects.toList(),
        days: weekdayNames.where(_days.contains).toList(),
        billingDay: _start?.day ?? 1,
        billingStart: _start == null ? '' : dateKey(_start!),
      ));
    }
    for (final id in _existing) {
      final s = repo.student(id);
      if (s == null) continue;
      await repo.saveStudent(Student.fromMap({...s.toMap(), 'batch': batch}));
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Batch "$batch" · ${fresh.length + _existing.length} student(s)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final others = repo.currentStudents;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Batch')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Batch name * (e.g. HSC Physics)'),
          ),
          Gap.m,
          const Text('Subjects', style: TextStyle(fontWeight: FontWeight.w600)),
          Gap.s,
          Wrap(spacing: 8, runSpacing: 6, children: _subjectPreset.map((s) => FilterChip(
                label: Text(s),
                selected: _subjects.contains(s),
                onSelected: (v) => setState(() => v ? _subjects.add(s) : _subjects.remove(s)),
              )).toList()),
          Gap.m,
          const Text('Class days', style: TextStyle(fontWeight: FontWeight.w600)),
          Gap.s,
          Row(children: weekdayNames.map((d) => Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FilterChip(
                  label: SizedBox(width: double.infinity,
                      child: Text(d, textAlign: TextAlign.center, maxLines: 1,
                          style: const TextStyle(fontSize: 12))),
                  labelPadding: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  selected: _days.contains(d),
                  onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
                ),
              ))).toList()),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: const Text('Class time'),
            subtitle: Text(_time.format(context)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          ),
          DropdownButtonFormField<int>(
            initialValue: _perMonth,
            decoration: const InputDecoration(labelText: 'Classes per month'),
            items: _perMonthOptions.map((n) =>
                DropdownMenuItem(value: n, child: Text('$n classes / month'))).toList(),
            onChanged: (v) => setState(() => _perMonth = v ?? 8),
          ),
          Gap.m,
          TextField(
            controller: _fee,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(labelText: 'Monthly fee per student (৳)'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_repeat),
            title: const Text('Month starts on'),
            subtitle: Text(_start == null
                ? '1st of every month (calendar month)'
                : '${fullDate(_start!)} · every month from the ${_start!.day}'),
            trailing: _start == null
                ? const Icon(Icons.calendar_today, size: 20)
                : IconButton(icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _start = null)),
            onTap: () async {
              final d = await showDatePicker(
                  context: context, initialDate: _start ?? DateTime.now(),
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _start = DateTime(d.year, d.month, d.day));
            },
          ),
          Gap.m,
          Row(children: [
            const Expanded(child: Text('New students', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            TextButton.icon(
              onPressed: () => setState(() => _members.add(_NewMember())),
              icon: const Icon(Icons.add), label: const Text('Another')),
          ]),
          for (var i = 0; i < _members.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(children: [
                Row(children: [
                  Expanded(child: TextField(
                    controller: _members[i].name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: 'Student ${i + 1} name', isDense: true))),
                  if (_members.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.expense),
                      onPressed: () => setState(() => _members.removeAt(i).dispose())),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(flex: 5, child: TextField(
                    controller: _members[i].phone,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.+ ]'))],
                    decoration: InputDecoration(
                      labelText: 'Phone', isDense: true,
                      suffixIcon: IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Pick from contacts',
                        icon: const Icon(Icons.contacts_outlined, size: 20),
                        onPressed: () => _pickContact(_members[i]))))),
                  const SizedBox(width: 8),
                  Expanded(flex: 4, child: TextField(
                    controller: _members[i].fee,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: InputDecoration(
                      labelText: 'Own fee (৳)', isDense: true,
                      hintText: _fee.text.trim().isEmpty ? 'batch fee' : _fee.text.trim()))),
                ]),
              ]),
            ),
          if (others.isNotEmpty) ...[
            Gap.m,
            const Text('Or add existing students', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const Text('Their batch is set to this one; other details stay as they are.',
                style: TextStyle(fontSize: 12)),
            for (final s in others)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _existing.contains(s.id),
                title: Text(s.name),
                subtitle: s.batch.isEmpty ? null : Text('now in ${s.batch}'),
                onChanged: (v) => setState(() => v == true ? _existing.add(s.id) : _existing.remove(s.id)),
              ),
          ],
          Gap.l,
          FilledButton(onPressed: _save, child: const Text('Create Batch')),
        ]),
      ),
    );
  }
}
