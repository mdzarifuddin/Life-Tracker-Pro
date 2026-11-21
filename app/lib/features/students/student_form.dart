part of 'students_screen.dart';

/// Editable controllers for one guardian row in the student form.
class _GuardianEntry {
  _GuardianEntry([Guardian? g])
      : name = TextEditingController(text: g?.name ?? ''),
        phone = TextEditingController(text: g?.phone ?? ''),
        relation = TextEditingController(text: g?.relation ?? '');
  final TextEditingController name, phone, relation;
  Guardian get value => Guardian(
      name: name.text.trim(), phone: phone.text.trim(), relation: relation.text.trim());
  void dispose() {
    name.dispose();
    phone.dispose();
    relation.dispose();
  }
}

class StudentFormScreen extends ConsumerStatefulWidget {
  const StudentFormScreen({super.key, this.id});
  final String? id;
  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends ConsumerState<StudentFormScreen> {
  static const _classOptions = [
    'Class 6', 'Class 7', 'Class 8', 'SSC (Class 9)', 'SSC (Class 10)',
    'HSC 1st Year', 'HSC 2nd Year', 'Admission', 'Honors', 'Other',
  ];
  static const _subjectPreset = [
    'Math', 'Higher Math', 'Physics', 'Chemistry', 'ICT',
  ];
  static const _perMonthOptions = [4, 8, 12, 16, 20, 24, 30];
  DateTime? _billingStart; // picked "month starts on" date
  bool _payPerClass = false;

  Future<void> _customPerMonth() async {
    final c = TextEditingController(text: '$_perMonth');
    final n = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Classes per month'),
      content: TextField(controller: c, autofocus: true, keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'e.g. 10')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(c.text.trim()) ?? 0;
            Navigator.pop(ctx, v > 0 && v <= 60 ? v : null);
          },
          child: const Text('Set')),
      ],
    ));
    if (n != null) setState(() => _perMonth = n);
  }

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _institution = TextEditingController();
  final _fee = TextEditingController();
  final _batch = TextEditingController();
  final List<_GuardianEntry> _guardians = [];
  final List<TextEditingController> _extraPhones = [];

  String? _grade;
  int _perMonth = 8;
  int _colorValue = 0;
  String _photo = '';
  TimeOfDay _defaultTime = const TimeOfDay(hour: 16, minute: 0);
  final _subjects = <String>{};
  final _days = <String>{};
  List<String> _classList = [];
  List<String> _subjectOptions = [];
  Student? _existing;
  bool _current = true;

  @override
  void initState() {
    super.initState();
    _classList = [..._classOptions];
    _subjectOptions = [..._subjectPreset];
    if (widget.id != null) {
      final s = ref.read(repoProvider).student(widget.id!);
      if (s != null) {
        _existing = s;
        _current = s.isCurrent;
        _name.text = s.name;
        _phone.text = s.phone;
        _batch.text = s.batch;
        _institution.text = s.institution;
        _fee.text = s.monthlyFee == 0 ? '' : s.monthlyFee.toStringAsFixed(0);
        for (final g in s.guardians) {
          _guardians.add(_GuardianEntry(g));
        }
        for (final p in s.extraPhones) {
          _extraPhones.add(TextEditingController(text: p));
        }
        _photo = s.photo;
        _perMonth = s.classesPerMonth == 0 ? 8 : s.classesPerMonth;
        _billingStart = s.billingStartDate;
        _payPerClass = s.payPerClass;
        _defaultTime = TimeOfDay(hour: s.defaultTimeMinutes ~/ 60, minute: s.defaultTimeMinutes % 60);
        _colorValue = s.colorValue;
        _days.addAll(s.days);
        if (s.grade.isNotEmpty) {
          if (!_classList.contains(s.grade)) _classList.insert(_classList.length - 1, s.grade);
          _grade = s.grade;
        }
        _subjects.addAll(s.subjects);
        for (final sub in s.subjects) {
          if (!_subjectOptions.contains(sub)) _subjectOptions.add(sub);
        }
      }
    }
    if (_guardians.isEmpty) _guardians.add(_GuardianEntry());
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name is required')));
      return;
    }
    final s = Student(
      id: widget.id ?? newId(),
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      grade: _grade ?? '',
      institution: _institution.text.trim(),
      monthlyFee: double.tryParse(_fee.text.trim()) ?? 0,
      classesPerMonth: _perMonth,
      billingDay: _billingStart?.day ?? 1,
      billingStart: _billingStart == null ? '' : dateKey(_billingStart!),
      payPerClass: _payPerClass,
      defaultTimeMinutes: _defaultTime.hour * 60 + _defaultTime.minute,
      colorValue: _colorValue,
      photo: _photo,
      subjects: _subjects.toList(),
      days: weekdayNames.where((d) => _days.contains(d)).toList(),
      weakSubjects: const [],
      extraPhones: _extraPhones.map((c) => c.text.trim()).where((x) => x.isNotEmpty).toList(),
      guardians: _guardians.map((g) => g.value).where((g) => !g.isEmpty).toList(),
      batch: _batch.text.trim(),
      status: _current ? 'active' : 'previous',
      leftOn: _current
          ? ''
          : (_existing?.leftOn.isNotEmpty ?? false)
              ? _existing!.leftOn
              : DateTime.now().toIso8601String().substring(0, 10),
    );
    await ref.read(repoProvider).saveStudent(s);
    if (mounted) context.pop();
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 70);
    if (x != null) {
      final bytes = await x.readAsBytes();
      setState(() => _photo = base64Encode(bytes));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? 'Add Student' : 'Edit Student')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(child: GestureDetector(
            onTap: _pickPhoto,
            child: CircleAvatar(
              radius: 46,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: _photo.isEmpty ? null : MemoryImage(base64Decode(_photo)),
              child: _photo.isEmpty
                  ? const Icon(Icons.add_a_photo, color: AppColors.primary, size: 28)
                  : null,
            ),
          )),
          if (_photo.isNotEmpty)
            Center(child: TextButton(
                onPressed: () => setState(() => _photo = ''), child: const Text('Remove photo'))),
          Gap.m,
          _text(_name, 'Name *'),
          if (_existing != null) ...[
            Gap.s,
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Currently studying'),
              subtitle: Text(_current
                  ? 'Shown in Tuition, schedule and fees'
                  : 'Previous student: hidden from Tuition list and schedule'),
              value: _current,
              onChanged: (v) => setState(() => _current = v),
            ),
          ],
          Gap.m,
          DropdownButtonFormField<String>(
            initialValue: _grade,
            decoration: const InputDecoration(labelText: 'Class'),
            items: _classList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _grade = v),
          ),
          Gap.m,
          _text(_institution, 'Institution'),
          Gap.m,
          _text(_batch, 'Batch (optional)'),
          if (ref.read(repoProvider).batchNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 0, children: [
                for (final b in ref.read(repoProvider).batchNames)
                  ActionChip(
                    label: Text(b),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: () => setState(() => _batch.text = b)),
              ]),
            ),
          Gap.l,
          _chips('Subjects', _subjects),
          Gap.l,
          DropdownButtonFormField<int>(
            key: ValueKey(_payPerClass),
            initialValue: _payPerClass ? -2 : _perMonth,
            decoration: const InputDecoration(labelText: 'Classes per month'),
            items: [
              ...({..._perMonthOptions, _perMonth}.toList()..sort()).map((n) =>
                  DropdownMenuItem(value: n, child: Text('$n classes / month'))),
              const DropdownMenuItem(value: -1, child: Text('Custom…')),
              const DropdownMenuItem(value: -2, child: Text('Per day (pay per class)')),
            ],
            onChanged: (v) {
              if (v == -1) {
                _customPerMonth();
              } else if (v == -2) {
                setState(() => _payPerClass = true);
              } else {
                setState(() { _payPerClass = false; _perMonth = v ?? 8; });
              }
            },
          ),
          Gap.m,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_repeat),
            title: const Text('Month starts on'),
            subtitle: Text(_billingStart == null
                ? '1st of every month (calendar month)'
                : '${fullDate(_billingStart!)} · every month from the ${_billingStart!.day}${_ord(_billingStart!.day)}'),
            trailing: _billingStart == null
                ? const Icon(Icons.calendar_today, size: 20)
                : IconButton(
                    tooltip: 'Use calendar month',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _billingStart = null)),
            onTap: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: _billingStart ?? DateTime.now(),
                  firstDate: DateTime(2020), lastDate: DateTime(2100),
                  helpText: 'Pick the day this student\'s month starts');
              if (d != null) setState(() => _billingStart = DateTime(d.year, d.month, d.day));
            },
          ),
          Gap.s,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: const Text('Default class time'),
            subtitle: Text(_defaultTime.format(context)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _defaultTime);
              if (t != null) setState(() => _defaultTime = t);
            },
          ),
          Gap.m,
          const Align(alignment: Alignment.centerLeft,
              child: Text('Class days', style: TextStyle(fontWeight: FontWeight.w600))),
          Gap.s,
          // all seven days in a single row
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
          Gap.m,
          const Text('Card colour', style: TextStyle(fontWeight: FontWeight.w600)),
          Gap.s,
          _colorGrid(),
          Gap.m,
          _text(_fee, _payPerClass ? 'Fee per class (৳)' : 'Monthly fee (৳)', number: true),
          Gap.m,
          _text(_phone, 'Student phone', number: true,
              onPickContact: () => _pickContact(_phone, nameTo: _name)),
          Gap.m,
          for (var i = 0; i < _guardians.length; i++) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
              decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Row(children: [
                  Text('Guardian ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Remove guardian',
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.expense),
                    onPressed: () => setState(() => _guardians.removeAt(i).dispose())),
                ]),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(children: [
                    _text(_guardians[i].name, 'Name'),
                    Gap.s,
                    _text(_guardians[i].relation, 'Relation (Father, Mother…)'),
                    Gap.s,
                    _text(_guardians[i].phone, 'Phone', number: true,
                        onPickContact: () => _pickContact(_guardians[i].phone, nameTo: _guardians[i].name)),
                  ]),
                ),
              ]),
            ),
          ],
          Align(alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _guardians.add(_GuardianEntry())),
              icon: const Icon(Icons.add), label: const Text('Add guardian'))),
          Gap.m,
          const Align(alignment: Alignment.centerLeft,
              child: Text('More student numbers', style: TextStyle(fontWeight: FontWeight.w600))),
          for (var i = 0; i < _extraPhones.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _extraPhones[i],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.+ ]'))],
                  decoration: InputDecoration(
                    labelText: 'Number',
                    suffixIcon: IconButton(
                      tooltip: 'Pick from contacts',
                      icon: const Icon(Icons.contacts_outlined),
                      onPressed: () => _pickContact(_extraPhones[i]))))),
                IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.expense),
                    onPressed: () => setState(() => _extraPhones.removeAt(i))),
              ]),
            ),
          Align(alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _extraPhones.add(TextEditingController())),
              icon: const Icon(Icons.add), label: const Text('Add student number'))),
          Gap.l,
          FilledButton(onPressed: _save, child: const Text('Save Student')),
        ]),
      ),
    );
  }

  Widget _chips(String label, Set<String> selected) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Gap.s,
        Wrap(spacing: 8, runSpacing: 8, children: [
          ..._subjectOptions.map((sub) => FilterChip(
                label: Text(sub),
                selected: selected.contains(sub),
                onSelected: (v) => setState(() => v ? selected.add(sub) : selected.remove(sub)),
              )),
          ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: const Text('Custom'),
            onPressed: () => _addCustom(selected),
          ),
        ]),
      ]);

  Future<void> _addCustom(Set<String> selected) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Add subject'),
      content: TextField(controller: controller, autofocus: true,
          decoration: const InputDecoration(hintText: 'Subject name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Add')),
      ],
    ));
    if (name != null && name.isNotEmpty) {
      setState(() {
        if (!_subjectOptions.contains(name)) _subjectOptions.add(name);
        selected.add(name);
      });
    }
  }

  /// Pick a phone number from the device contacts (no permission needed:
  /// the system picker returns only the chosen contact). Fills [nameTo] when empty.
  Future<void> _pickContact(TextEditingController phone, {TextEditingController? nameTo}) async {
    try {
      final c = await FlutterNativeContactPicker().selectPhoneNumber();
      final number = (c?.selectedPhoneNumber ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
      if (number.isEmpty) return;
      setState(() {
        phone.text = number;
        if (nameTo != null && nameTo.text.trim().isEmpty) nameTo.text = c?.fullName ?? '';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open contacts')));
      }
    }
  }

  Widget _text(TextEditingController c, String label,
          {bool number = false, VoidCallback? onPickContact}) =>
      TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.+ ]'))] : null,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onPickContact == null
              ? null
              : IconButton(
                  tooltip: 'Pick from contacts',
                  icon: const Icon(Icons.contacts_outlined),
                  onPressed: onPickContact),
        ),
      );

  /// Built-in card colours (13 + the custom picker = two full rows of 7).
  static const _cardColors = <Color>[
    Color(0xFF6366F1), Color(0xFF10B981), Color(0xFFF43F5E), Color(0xFFF59E0B),
    Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF14B8A6),
    Color(0xFFF97316), Color(0xFF06B6D4), Color(0xFF84CC16), Color(0xFF0EA5E9),
    Color(0xFFB45309),
  ];

  Widget _colorGrid() {
    final cells = <Widget>[
      _customSwatch(),
      for (final c in _cardColors) _swatch(c),
    ];
    return Column(children: [
      for (var r = 0; r < cells.length; r += 7)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            for (var k = r; k < r + 7; k++)
              Expanded(child: Center(child: k < cells.length ? cells[k] : const SizedBox())),
          ]),
        ),
    ]);
  }

  bool get _isCustomColor =>
      _colorValue != 0 && !_cardColors.any((c) => c.toARGB32() == _colorValue);

  /// First swatch: opens the colour picker. Shows the chosen custom colour once set.
  Widget _customSwatch() {
    final custom = _isCustomColor ? Color(_colorValue) : null;
    return GestureDetector(
      onTap: () async {
        final c = await showDialog<Color>(
            context: context,
            builder: (_) => _ColorPickerDialog(initial: custom ?? _cardColors.first));
        if (c != null) setState(() => _colorValue = c.toARGB32());
      },
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: custom == null
              ? const SweepGradient(colors: [
                  Colors.red, Colors.yellow, Colors.green, Colors.cyan,
                  Colors.blue, Colors.purple, Colors.red])
              : null,
          color: custom,
          border: Border.all(color: custom != null ? Colors.white : Colors.transparent, width: 3),
          boxShadow: custom != null ? [BoxShadow(color: custom, blurRadius: 0, spreadRadius: 1)] : null,
        ),
        alignment: Alignment.center,
        child: Icon(custom == null ? Icons.colorize : Icons.check, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _swatch(Color color) {
    final val = color.toARGB32();
    final sel = _colorValue == val;
    return GestureDetector(
      // tap the selected colour again to go back to automatic
      onTap: () => setState(() => _colorValue = sel ? 0 : val),
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 3),
          boxShadow: sel ? [BoxShadow(color: color, blurRadius: 0, spreadRadius: 1)] : null,
        ),
        alignment: Alignment.center,
        child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
      ),
    );
  }
}

/// Simple colour picker: hue / saturation / brightness sliders + hex code.
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});
  final Color initial;
  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final _hex = TextEditingController(text: _hexOf(widget.initial));

  static String _hexOf(Color c) =>
      (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  void _set(HSVColor h) {
    setState(() => _hsv = h);
    _hex.text = _hexOf(h.toColor());
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return AlertDialog(
      title: const Text('Custom colour'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 56, decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12))),
        const SizedBox(height: 8),
        Slider(
          value: _hsv.hue, min: 0, max: 360,
          activeColor: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
          onChanged: (v) => _set(_hsv.withHue(v))),
        Slider(
          value: _hsv.saturation, min: 0, max: 1,
          onChanged: (v) => _set(_hsv.withSaturation(v))),
        Slider(
          value: _hsv.value, min: 0, max: 1,
          onChanged: (v) => _set(_hsv.withValue(v))),
        TextField(
          controller: _hex,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]'))],
          decoration: const InputDecoration(prefixText: '# ', labelText: 'Hex code', counterText: ''),
          onChanged: (v) {
            if (v.length == 6) {
              setState(() => _hsv = HSVColor.fromColor(Color(0xFF000000 | int.parse(v, radix: 16))));
            }
          },
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, color), child: const Text('Use')),
      ],
    );
  }
}

