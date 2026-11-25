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

  // UI-only state (no effect on what gets saved)
  final _scroll = ScrollController();
  final _nameFocus = FocusNode();
  String? _nameError;
  String _initialSig = '';

  /// Snapshot of every editable value, used to detect unsaved changes.
  String _signature() => [
        _name.text.trim(), _phone.text.trim(), _institution.text.trim(), _fee.text.trim(),
        _batch.text.trim(), _grade ?? '', _perMonth, _colorValue, _photo.length, _photo.hashCode,
        _defaultTime.hour * 60 + _defaultTime.minute, (_subjects.toList()..sort()).join(','),
        weekdayNames.where(_days.contains).join(','), _billingStart?.toIso8601String() ?? '',
        _payPerClass, _current,
        _guardians.map((g) => '${g.name.text.trim()}|${g.relation.text.trim()}|${g.phone.text.trim()}').join(';'),
        _extraPhones.map((c) => c.text.trim()).where((x) => x.isNotEmpty).join(','),
      ].join('\u0001');

  bool get _dirty => _signature() != _initialSig;

  @override
  void dispose() {
    _scroll.dispose();
    _nameFocus.dispose();
    for (final c in [_name, _phone, _institution, _fee, _batch, ..._extraPhones]) {
      c.dispose();
    }
    for (final g in _guardians) {
      g.dispose();
    }
    super.dispose();
  }

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
    _initialSig = _signature();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Please enter the student\'s name');
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      _nameFocus.requestFocus();
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

  /// Colour the student card will use (custom if chosen, else derived from the name),
  /// mirroring [studentColor].
  Color get _previewColor {
    if (_colorValue != 0) return Color(_colorValue);
    final n = _name.text.trim();
    return AppColors.forIndex(n.isEmpty ? 0 : n.codeUnitAt(0) + n.length);
  }

  /// Back button / gesture: ask before throwing away edits.
  Future<void> _onBack() async {
    if (!_dirty) {
      if (mounted) context.pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.edit_note, color: AppColors.warning, size: 32),
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. If you go back now they will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep editing')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.id == null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(isNew ? 'Add Student' : 'Edit Student')),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _previewHeader(),
                  Gap.l,
                  _basicSection(),
                  Gap.l,
                  _subjectsSection(),
                  Gap.l,
                  _scheduleSection(),
                  Gap.l,
                  _feeSection(),
                  Gap.l,
                  _contactSection(),
                  Gap.l,
                  _appearanceSection(),
                ],
              ),
            ),
            _saveBar(isNew),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- header

  /// Live preview: avatar (tap to change photo) in the chosen colour + name.
  Widget _previewHeader() => ListenableBuilder(
        listenable: Listenable.merge([_name, _institution, _fee, _batch]),
        builder: (context, _) {
          final c = _previewColor;
          final name = _name.text.trim();
          final sub = [_grade ?? '', _institution.text.trim()].where((e) => e.isNotEmpty).join(' · ');
          final fee = double.tryParse(_fee.text.trim()) ?? 0;
          final dayCount = _days.length;
          Widget pill(IconData icon, String text) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                  Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                ]),
              );
          final avatar = CircleAvatar(
            radius: 36,
            backgroundColor: Color.alphaBlend(c.withValues(alpha: 0.18), Colors.white),
            foregroundColor: c,
            backgroundImage: _photo.isEmpty ? null : MemoryImage(base64Decode(_photo)),
            child: _photo.isNotEmpty
                ? null
                : name.isEmpty
                    ? Icon(Icons.person, size: 34, color: c)
                    : Text(name[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 30)),
          );
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                // deepened so the white name / pills stay readable on light colours
                colors: [deepenForWhite(c), deepenForWhite(Color.lerp(c, const Color(0xFF8B5CF6), 0.5)!)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: c.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(children: [
              Tooltip(
                message: _photo.isEmpty ? 'Add photo' : 'Change photo',
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: avatar,
                    ),
                    Positioned(
                      right: -2, bottom: -2,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: c, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                        child: Icon(_photo.isEmpty ? Icons.add_a_photo : Icons.edit,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ),
              Gap.l,
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'New student' : name,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: name.isEmpty ? 0.75 : 1),
                        fontSize: 22, fontWeight: FontWeight.w800, height: 1.15)),
                const SizedBox(height: 3),
                Text(sub.isEmpty ? 'Preview of the student card' : sub,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5)),
                Gap.s,
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (fee > 0) pill(Icons.payments_outlined, _payPerClass ? '${taka(fee)}/class' : '${taka(fee)}/mo'),
                  if (dayCount > 0) pill(Icons.event_available, '$dayCount day${dayCount == 1 ? '' : 's'}/wk'),
                  if (_batch.text.trim().isNotEmpty) pill(Icons.groups_2_outlined, _batch.text.trim()),
                  if (_photo.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _photo = ''),
                      child: pill(Icons.hide_image_outlined, 'Remove photo')),
                ]),
              ])),
            ]),
          );
        },
      );

  // ---------------------------------------------------------------- sections

  /// Card with an icon badge header, matching the detail screen's look.
  Widget _section({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) =>
      PadCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconBadge(icon: icon, color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle, style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor)),
            ])),
            ?trailing,
          ]),
          Gap.l,
          ...children,
        ]),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(text, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).hintColor)),
      );

  Widget _basicSection() {
    final batches = ref.read(repoProvider).batchNames;
    return _section(
      icon: Icons.badge_outlined,
      color: AppColors.primary,
      title: 'Basic info',
      subtitle: 'Name, class and where they study',
      children: [
        _text(_name, 'Full name *',
            icon: Icons.person_outline,
            hint: 'e.g. Labib Hasan',
            focusNode: _nameFocus,
            errorText: _nameError,
            capitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            }),
        if (_existing != null) ...[
          Gap.m,
          _statusTile(),
        ],
        Gap.m,
        DropdownButtonFormField<String>(
          initialValue: _grade,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Class', prefixIcon: Icon(Icons.school_outlined)),
          items: _classList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _grade = v),
        ),
        Gap.m,
        _text(_institution, 'Institution',
            icon: Icons.account_balance_outlined,
            hint: 'School / college name',
            capitalization: TextCapitalization.words),
        Gap.m,
        _text(_batch, 'Batch (optional)',
            icon: Icons.groups_2_outlined,
            hint: 'Leave empty for a single student',
            capitalization: TextCapitalization.words),
        if (batches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final b in batches)
                ActionChip(
                  avatar: const Icon(Icons.groups_2_outlined, size: 16),
                  label: Text(b),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () => setState(() => _batch.text = b)),
            ]),
          ),
      ],
    );
  }

  Widget _statusTile() {
    final c = _current ? AppColors.income : Theme.of(context).hintColor;
    return Container(
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.30)),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.only(left: 12, right: 8),
        secondary: Icon(_current ? Icons.check_circle : Icons.history, color: c),
        title: const Text('Currently studying', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(_current
            ? 'Shown in Tuition, schedule and fees'
            : 'Previous student: hidden from Tuition list and schedule',
            style: const TextStyle(fontSize: 12.5)),
        value: _current,
        onChanged: (v) => setState(() => _current = v),
      ),
    );
  }

  Widget _subjectsSection() => _section(
        icon: Icons.menu_book_outlined,
        color: AppColors.savings,
        title: 'Subjects',
        subtitle: 'Tap to select · add your own with Custom',
        trailing: _subjects.isEmpty ? null : InfoChip(Icons.check, '${_subjects.length}'),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            ..._subjectOptions.map((sub) => FilterChip(
                  label: Text(sub),
                  selected: _subjects.contains(sub),
                  onSelected: (v) => setState(() => v ? _subjects.add(sub) : _subjects.remove(sub)),
                )),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Custom'),
              onPressed: () => _addCustom(_subjects),
            ),
          ]),
        ],
      );

  Widget _scheduleSection() {
    final picked = weekdayNames.where(_days.contains).toList();
    final hint = Theme.of(context).hintColor;
    final perMonthChoices = ({..._perMonthOptions, _perMonth}.toList()..sort());
    return _section(
      icon: Icons.calendar_month_outlined,
      color: AppColors.warning,
      title: 'Schedule',
      subtitle: 'Class days, time and monthly cycle',
      children: [
        _label('Class days'),
        _weekdaySelector(),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 2),
          child: Text(
            picked.isEmpty
                ? 'Tap the days this student has class'
                : '${picked.join(', ')} · ${picked.length} day${picked.length == 1 ? '' : 's'} a week',
            style: TextStyle(fontSize: 12.5, color: hint)),
        ),
        Gap.l,
        _tile(
          icon: Icons.access_time,
          label: 'Default class time',
          value: _defaultTime.format(context),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _defaultTime);
            if (t != null) setState(() => _defaultTime = t);
          },
        ),
        Gap.m,
        _tile(
          icon: Icons.event_repeat,
          label: 'Month starts on',
          value: _billingStart == null
              ? '1st of every month (calendar month)'
              : '${_billingStart!.day}${_ord(_billingStart!.day)} of every month · from ${fullDate(_billingStart!)}',
          trailing: _billingStart == null
              ? null
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
        Gap.l,
        _label('Classes per month'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in perMonthChoices)
            ChoiceChip(
              label: Text('$n'),
              showCheckmark: false,
              selected: _perMonth == n,
              onSelected: (_) => setState(() => _perMonth = n),
            ),
          ActionChip(
            avatar: const Icon(Icons.tune, size: 16),
            label: const Text('Custom'),
            onPressed: _customPerMonth,
          ),
        ]),
      ],
    );
  }

  /// Seven tappable day pills in one row.
  Widget _weekdaySelector() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final idle = dark ? AppColors.dSurfaceVariant : AppColors.lSurfaceVariant;
    return Row(children: [
      for (final d in weekdayNames)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Semantics(
              button: true,
              selected: _days.contains(d),
              label: d,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: _days.contains(d) ? AppColors.primaryGrad : null,
                    color: _days.contains(d) ? null : idle,
                    borderRadius: BorderRadius.circular(14),
                    border: _days.contains(d)
                        ? null
                        : Border.all(color: Theme.of(context).colorScheme.outline),
                    boxShadow: _days.contains(d)
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30),
                            blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(d, style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _days.contains(d) ? Colors.white : Theme.of(context).hintColor)),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _feeSection() => _section(
        icon: Icons.payments_outlined,
        color: AppColors.income,
        title: 'Fee',
        subtitle: 'How this student pays',
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.calendar_month, size: 18), label: Text('Monthly')),
              ButtonSegment(value: true, icon: Icon(Icons.today, size: 18), label: Text('Per class')),
            ],
            selected: {_payPerClass},
            onSelectionChanged: (s) => setState(() => _payPerClass = s.first),
          ),
          Gap.m,
          _text(_fee, _payPerClass ? 'Fee per class (৳)' : 'Monthly fee (৳)',
              number: true, icon: Icons.account_balance_wallet_outlined,
              hint: _payPerClass ? 'Amount for each class' : 'Amount for the whole month'),
          Gap.s,
          ListenableBuilder(
            listenable: _fee,
            builder: (context, _) {
              final fee = double.tryParse(_fee.text.trim()) ?? 0;
              final String msg;
              if (fee <= 0) {
                msg = _payPerClass
                    ? 'Charged for every class taken'
                    : 'Per-class fee is worked out from the classes per month';
              } else if (_payPerClass) {
                msg = 'Charged for every class taken · about ${taka(fee * _perMonth)} for $_perMonth classes';
              } else {
                msg = '${taka(_perMonth > 0 ? fee / _perMonth : fee)} per class · $_perMonth classes a month';
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.calculate_outlined, size: 18, color: AppColors.income),
                  Gap.s,
                  Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                ]),
              );
            },
          ),
        ],
      );

  static const _relations = ['Father', 'Mother', 'Brother', 'Sister', 'Uncle'];

  Widget _contactSection() {
    final cs = Theme.of(context).colorScheme;
    return _section(
      icon: Icons.contact_phone_outlined,
      color: AppColors.info,
      title: 'Contact',
      subtitle: 'Student and guardian numbers',
      children: [
        _text(_phone, 'Student phone', number: true, icon: Icons.phone_outlined,
            hint: '01XXXXXXXXX',
            onPickContact: () => _pickContact(_phone, nameTo: _name)),
        for (var i = 0; i < _extraPhones.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              Expanded(child: _text(_extraPhones[i], 'Another student number', number: true,
                  icon: Icons.phone_android_outlined,
                  onPickContact: () => _pickContact(_extraPhones[i]))),
              IconButton(
                  tooltip: 'Remove number',
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.expense),
                  onPressed: () => setState(() => _extraPhones.removeAt(i))),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _extraPhones.add(TextEditingController())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add student number')),
        ),
        const Divider(height: 20),
        _label('Guardians'),
        if (_guardians.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text('No guardian added yet',
                style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
          ),
        for (var i = 0; i < _guardians.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.info.withValues(alpha: 0.16),
                  child: Text('${i + 1}', style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.info)),
                ),
                Gap.s,
                Expanded(child: Text('Guardian ${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                  tooltip: 'Remove guardian',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: AppColors.expense),
                  onPressed: () => setState(() => _guardians.removeAt(i).dispose())),
              ]),
              Gap.s,
              _text(_guardians[i].name, 'Name', icon: Icons.person_outline,
                  capitalization: TextCapitalization.words),
              Gap.m,
              _text(_guardians[i].relation, 'Relation', icon: Icons.family_restroom,
                  hint: 'Father, Mother…', capitalization: TextCapitalization.words),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ListenableBuilder(
                  listenable: _guardians[i].relation,
                  builder: (context, _) => Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final r in _relations)
                      ChoiceChip(
                        label: Text(r, style: const TextStyle(fontSize: 12)),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        selected: _guardians[i].relation.text.trim() == r,
                        onSelected: (_) => _guardians[i].relation.text = r,
                      ),
                  ]),
                ),
              ),
              Gap.m,
              _text(_guardians[i].phone, 'Phone', number: true, icon: Icons.phone_outlined,
                  onPickContact: () => _pickContact(_guardians[i].phone, nameTo: _guardians[i].name)),
            ]),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _guardians.add(_GuardianEntry())),
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
          label: const Text('Add guardian')),
      ],
    );
  }

  Widget _appearanceSection() => _section(
        icon: Icons.palette_outlined,
        color: const Color(0xFFEC4899),
        title: 'Card colour',
        subtitle: _colorValue == 0
            ? 'Automatic (from the name) · pick one to override'
            : 'Tap the selected colour again for automatic',
        children: [_colorGrid()],
      );

  Widget _saveBar(bool isNew) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: FilledButton.icon(
        onPressed: _save,
        icon: Icon(isNew ? Icons.person_add_alt_1 : Icons.check_rounded),
        label: Text(isNew ? 'Add student' : 'Save changes'),
      ),
    );
  }

  /// Read-only "field" that opens a picker (time / date).
  Widget _tile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hint = Theme.of(context).hintColor;
    return Material(
      color: dark ? AppColors.dSurfaceVariant : AppColors.lSurfaceVariant,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(children: [
            Icon(icon, color: hint),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12, color: hint)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ])),
            trailing ??
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.chevron_right, color: hint),
                ),
          ]),
        ),
      ),
    );
  }

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
          {bool number = false,
          VoidCallback? onPickContact,
          IconData? icon,
          String? hint,
          String? errorText,
          FocusNode? focusNode,
          TextCapitalization capitalization = TextCapitalization.none,
          ValueChanged<String>? onChanged}) =>
      TextField(
        controller: c,
        focusNode: focusNode,
        onChanged: onChanged,
        textCapitalization: capitalization,
        textInputAction: TextInputAction.next,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.+ ]'))] : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          prefixIcon: icon == null ? null : Icon(icon),
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
        child: Icon(custom == null ? Icons.colorize : Icons.check, size: 18,
            color: custom == null ? Colors.white : onColor(custom)),
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
        child: sel ? Icon(Icons.check, color: onColor(color), size: 18) : null,
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

