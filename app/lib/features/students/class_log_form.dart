part of 'students_screen.dart';

class ClassLogFormScreen extends ConsumerStatefulWidget {
  const ClassLogFormScreen({super.key, this.studentId, this.existing, this.presetDate});
  final String? studentId;
  final ClassLog? existing;
  final DateTime? presetDate;
  @override
  ConsumerState<ClassLogFormScreen> createState() => _ClassLogFormScreenState();
}

class _ClassLogFormScreenState extends ConsumerState<ClassLogFormScreen> {
  String? _studentId;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  final _logSubjects = <String>{};
  final _hwTypes = <String>{};
  final _topics = TextEditingController();
  final _homework = TextEditingController();
  final _nextPlan = TextEditingController();
  final _learned = TextEditingController();
  final _notDone = TextEditingController();
  final _remarks = TextEditingController();
  double _perf = 7;
  bool _paid = false; // payment received for this class

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _studentId = e.studentId;
      _date = e.date;
      _time = TimeOfDay(hour: e.date.hour, minute: e.date.minute);
      _logSubjects.addAll(e.subject.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty));
      _topics.text = e.topics;
      _homework.text = e.homework;
      _nextPlan.text = e.nextPlan;
      _learned.text = e.learned;
      _notDone.text = e.notDone;
      _remarks.text = e.remarks;
      _perf = e.performance.toDouble();
      _paid = e.isPaid;
    } else {
      _studentId = widget.studentId;
      if (widget.presetDate != null) _date = widget.presetDate!;
    }
  }

  Future<void> _save() async {
    final repo = ref.read(repoProvider);
    if (_studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a student')));
      return;
    }
    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final saved = ClassLog(
      id: widget.existing?.id ?? newId(),
      studentId: _studentId!, date: dt,
      subject: _logSubjects.join(', '),
      topics: _topics.text.trim(),
      homework: [..._hwTypes, if (_homework.text.trim().isNotEmpty) _homework.text.trim()].join(', '),
      nextPlan: _nextPlan.text.trim(), learned: _learned.text.trim(),
      notDone: _notDone.text.trim(), remarks: _remarks.text.trim(),
      performance: _perf.round(),
      payId: widget.existing?.payId ?? '', payMonth: widget.existing?.payMonth ?? '',
    );
    await repo.saveLog(saved);
    final st = repo.student(_studentId!);
    if (st != null && _paid != saved.isPaid) await repo.setLogPaid(st, saved, _paid);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final students = repo.pickableStudents(_studentId);
    final subjOpts = (_studentId == null ? null : repo.student(_studentId!))?.subjects ?? const <String>[];
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Class Log' : 'Log Class'), toolbarHeight: 48, actions: [
        if (!editing)
          OnBackground(
            child: TextButton.icon(
              onPressed: () => showBulkClassesSheet(context, repo),
              icon: const Icon(Icons.playlist_add, size: 20),
              label: const Text('Add many'),
            ),
          ),
      ]),
      // this form sits straight on the app background (no cards)
      body: OnBackground(child: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), children: [
          DropdownButtonFormField<String>(
            initialValue: _studentId,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Student', isDense: true),
            items: students.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
            onChanged: (v) => setState(() => _studentId = v),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(fullDate(_date)),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _date,
                    firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setState(() => _date = d);
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.access_time, size: 16),
              label: Text(_time.format(context)),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
            )),
          ]),
          const SizedBox(height: 6),
          if (subjOpts.isNotEmpty) ...[
            Wrap(spacing: 6, runSpacing: 0, children: subjOpts.map((s) => FilterChip(
                  label: Text(s), selected: _logSubjects.contains(s),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (v) => setState(() => v ? _logSubjects.add(s) : _logSubjects.remove(s)),
                )).toList()),
            const SizedBox(height: 8),
          ],
          _field(_topics, 'Today covered (topics)'),
          Wrap(spacing: 6, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Homework:', style: TextStyle(fontWeight: FontWeight.w600)),
            for (final h in const ['MCQ', 'CQ', 'Exercise', 'Page', 'Practice', 'Memorize', 'Worksheet'])
              FilterChip(
                label: Text(h),
                selected: _hwTypes.contains(h),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (v) => setState(() => v ? _hwTypes.add(h) : _hwTypes.remove(h))),
          ]),
          const SizedBox(height: 8),
          _field(_homework, 'Homework details (e.g. page 29-48)'),
          _field(_learned, 'What student learned / could do'),
          _field(_notDone, 'Not done / weak points'),
          _field(_nextPlan, 'Next class plan'),
          Row(children: [
            Text('Performance ${_perf.round()}/10', style: const TextStyle(fontWeight: FontWeight.w600)),
            Expanded(child: Slider(value: _perf, min: 0, max: 10, divisions: 10,
                label: '${_perf.round()}', onChanged: (v) => setState(() => _perf = v))),
          ]),
          _field(_remarks, "Today's comment"),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Payment received for this class'),
            subtitle: Text(_studentId == null
                ? 'Select a student first'
                : 'Records ${taka(repo.student(_studentId!)?.perClassFee ?? 0)} on this date (student records only)'),
            value: _paid,
            onChanged: _studentId == null ? null : (v) => setState(() => _paid = v),
          ),
        ]),
      )),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: FilledButton(onPressed: _save, child: Text(editing ? 'Update Log' : 'Save Log')),
        ),
      ),
    );
  }

  /// Compact field: one line that grows up to 3 as you type.
  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(controller: c, minLines: 1, maxLines: 3,
            decoration: InputDecoration(labelText: label, isDense: true)),
      );
}

