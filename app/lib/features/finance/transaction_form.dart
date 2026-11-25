part of 'finance_screen.dart';

/// Monefy-style entry: amount display + calculator keypad + category grid.
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, required this.type, this.existing, this.category});
  final String type;
  final Txn? existing;
  final String? category;
  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  static const _ops = '+-×÷';
  late String _type = widget.type;
  String? _category;
  String _expr = '';
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  String _account = ''; // '' = no account
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  /// Earlier notes (from saved records) that match what is being typed. With nothing
  /// typed it offers recent notes of the chosen category.
  List<String> _noteHints(String typed) {
    final q = typed.trim().toLowerCase();
    if (q.isEmpty && _category == null) return const [];
    final seen = <String>{};
    final starts = <String>[], contains = <String>[];
    for (final t in ref.read(repoProvider).txnList) { // newest first
      final n = t.note.trim();
      if (n.isEmpty || t.type != _type || t.sourceRef.isNotEmpty) continue;
      if (q.isEmpty && t.category != _category) continue;
      final l = n.toLowerCase();
      if (l == q || !seen.add(l)) continue;
      if (q.isEmpty || l.startsWith(q)) {
        starts.add(n);
      } else if (l.contains(q)) {
        contains.add(n);
      }
    }
    return [...starts, ...contains].take(5).toList();
  }

  bool get _editing => widget.existing != null;
  bool get _isIncome => _type == 'income';
  Color get _color => _isIncome ? _Mf.greenFill : _Mf.redFill;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    final e = widget.existing;
    if (e != null) {
      _category = e.category;
      _expr = e.amount == 0 ? '' : _fmt(e.amount);
      _account = e.account;
      _note.text = e.note;
      _date = e.date;
    } else {
      // start with the account used for the previous record (if it still exists)
      final repo = ref.read(repoProvider);
      final last = repo.txnList.isEmpty ? '' : repo.txnList.first.account;
      if (repo.accountById(last) != null) _account = last;
    }
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  /// Evaluates "12+3×4" with × ÷ before + −.
  static double? _eval(String e) {
    while (e.isNotEmpty && _ops.contains(e[e.length - 1])) {
      e = e.substring(0, e.length - 1);
    }
    if (e.isEmpty) return null;
    final nums = <double>[];
    final ops = <String>[];
    var buf = '';
    for (final ch in e.split('')) {
      if (_ops.contains(ch)) {
        nums.add(double.tryParse(buf) ?? 0);
        ops.add(ch);
        buf = '';
      } else {
        buf += ch;
      }
    }
    nums.add(double.tryParse(buf) ?? 0);
    final n2 = [nums.first];
    final o2 = <String>[];
    for (var i = 0; i < ops.length; i++) {
      final b = nums[i + 1];
      if (ops[i] == '×') {
        n2.last = n2.last * b;
      } else if (ops[i] == '÷') {
        n2.last = b == 0 ? n2.last : n2.last / b;
      } else {
        o2.add(ops[i]);
        n2.add(b);
      }
    }
    var r = n2.first;
    for (var i = 0; i < o2.length; i++) {
      r = o2[i] == '+' ? r + n2[i + 1] : r - n2[i + 1];
    }
    return r;
  }

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (k == '=') {
        final v = _eval(_expr);
        _expr = v == null ? '' : _fmt(v);
        return;
      }
      final last = _expr.isEmpty ? '' : _expr[_expr.length - 1];
      final cur = _expr.split(RegExp(r'[+\-×÷]')).last;
      if (_ops.contains(k)) {
        if (_expr.isEmpty) return;
        if (_ops.contains(last)) _expr = _expr.substring(0, _expr.length - 1);
        _expr += k;
        return;
      }
      if (_expr.length >= 18) return;
      if (k == '.') {
        if (cur.contains('.')) return;
        _expr += cur.isEmpty ? '0.' : '.';
        return;
      }
      if (cur.contains('.') && cur.split('.').last.length >= 2) return;
      if (cur == '0') _expr = _expr.substring(0, _expr.length - 1);
      _expr += k;
    });
  }

  void _backspace() {
    if (_expr.isEmpty) return;
    setState(() => _expr = _expr.substring(0, _expr.length - 1));
  }

  Future<String?> _addCategory() async {
    final repo = ref.read(repoProvider);
    final taken = repo.categoriesOf(_type).map((c) => c.name.toLowerCase()).toSet();
    final res = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _NewCategoryDialog(taken: taken),
    );
    if (res == null) return null;
    final (name, icon) = res;
    await repo.saveCategory(Category(id: newId(), name: name, type: _type, icon: icon));
    _syncCategoryIcons(repo);
    return name;
  }

  Future<String?> _pickCategory() {
    final mf = _Mf(context);
    final cats = ref.read(repoProvider).categoriesOf(_type);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: mf.bg,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
                children: cats.map((c) {
                  final col = catColor(c.name);
                  return Material(
                    color: _category == c.name ? mf.selFill : mf.keyFill,
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6), side: BorderSide(color: mf.line)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => Navigator.pop(ctx, c.name),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(catIcon(c.name), color: col, size: 36),
                        const SizedBox(height: 6),
                        Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: mf.ink(col), fontSize: 12.5)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _wideKey(mf, 'Add category', color: _Mf.green, onTap: () async {
                final n = await _addCategory();
                if (n != null && ctx.mounted) Navigator.pop(ctx, n);
              }),
            ),
          ]),
        ),
      ),
    );
  }

  /// Earlier records that look like this one: same amount, or matching what is typed
  /// in the note. Tapping one fills the type (category) + note and saves.
  List<Txn> _suggestions(Repo repo) {
    final amt = _eval(_expr) ?? 0;
    final q = _note.text.trim().toLowerCase();
    if (amt <= 0 && q.isEmpty) return const [];
    final cats = repo.categoriesOf(_type).map((c) => c.name).toSet();
    final seen = <String>{};
    final hits = <(int, Txn)>[];
    for (final t in repo.txnList) { // newest first
      if (t.type != _type || t.sourceRef.isNotEmpty || t.id == widget.existing?.id) continue;
      if (!cats.contains(t.category)) continue;
      final sameAmt = amt > 0 && (t.amount - amt).abs() < 0.01;
      final noteHit = q.isNotEmpty &&
          (t.note.toLowerCase().contains(q) || t.category.toLowerCase().contains(q));
      if (q.isNotEmpty ? !noteHit : !sameAmt) continue;
      if (!seen.add('${t.category}|${t.note.toLowerCase()}|${t.amount}')) continue;
      hits.add(((sameAmt ? 2 : 0) + (noteHit ? 1 : 0), t));
    }
    hits.sort((a, b) => b.$1.compareTo(a.$1)); // stable: newest first within a score
    return hits.take(6).map((h) => h.$2).toList();
  }

  Future<void> _useSuggestion(Txn t) async {
    setState(() {
      _category = t.category;
      _note.text = t.note;
      if ((_eval(_expr) ?? 0) <= 0) _expr = _fmt(t.amount);
    });
    await _save();
  }

  Future<void> _chooseAndSave() async {
    final c = await _pickCategory();
    if (c == null) return;
    setState(() => _category = c);
    await _save();
  }

  Future<void> _save() async {
    final amt = _eval(_expr) ?? 0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    if (_category == null) return _chooseAndSave();
    final txn = Txn(
      id: widget.existing?.id ?? newId(), type: _type, category: _category!,
      amount: amt, date: _date, account: _account, note: _note.text.trim(),
      sourceRef: widget.existing?.sourceRef ?? '',
    );
    await ref.read(repoProvider).saveTxn(txn);
    if (mounted) context.pop(_editing ? null : txn);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _Mf.redFill),
              onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(repoProvider).deleteTxn(widget.existing!.id);
    if (mounted) context.pop();
  }

  void _switchType() {
    setState(() {
      _type = _isIncome ? 'expense' : 'income';
      final names = ref.read(repoProvider).categoriesOf(_type).map((c) => c.name);
      if (!names.contains(_category)) _category = null;
    });
  }

  Future<void> _pickAccount() async {
    final mf = _Mf(context);
    final repo = ref.read(repoProvider);
    final a = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: mf.bg,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            ListTile(
              leading: const Icon(Icons.block, color: _Mf.green),
              title: Text('No account', style: TextStyle(color: mf.text)),
              trailing: _account.isEmpty ? const Icon(Icons.check, color: _Mf.green) : null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            ...orderedAccounts(repo).map((e) => ListTile(
              contentPadding: EdgeInsets.only(left: e.isMain ? 16 : 40, right: 16),
              leading: Icon(accountIcon(repo, e.id), color: _Mf.green),
              title: Text(e.name, style: TextStyle(color: mf.text)),
              subtitle: e.isMain
                  ? (e.inTotal ? null : Text('separate · not in the total',
                      style: TextStyle(color: mf.muted, fontSize: 12)))
                  : Text('in ${repo.accountName(e.parentId)}',
                      style: TextStyle(color: mf.muted, fontSize: 12)),
              trailing: e.id == _account ? const Icon(Icons.check, color: _Mf.green) : null,
              onTap: () => Navigator.pop(ctx, e.id),
            )),
          ]),
        ),
      ),
    );
    if (a != null) setState(() => _account = a);
  }

  Widget _wideKey(_Mf mf, String label, {required VoidCallback onTap, Color? color}) => Material(
        color: mf.keyFill,
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: mf.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: SizedBox(
            height: 58, width: double.infinity,
            child: Center(child: Text(label, style: TextStyle(
                color: color ?? mf.text, fontSize: 17, letterSpacing: 0.6))),
          ),
        ),
      );

  Widget _keypad(_Mf mf) {
    final keyH = MediaQuery.of(context).size.height < 720 ? 50.0 : 62.0;
    const rows = [
      ['1', '2', '3', '+'],
      ['4', '5', '6', '-'],
      ['7', '8', '9', '×'],
      ['.', '0', '=', '÷'],
    ];
    return Column(children: rows.map((r) => Row(children: r.map((k) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: mf.keyFill,
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: mf.line)),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => _key(k),
            child: SizedBox(height: keyH, child: Center(child: Text(k,
                style: TextStyle(color: mf.text, fontSize: 30, fontWeight: FontWeight.w300)))),
          ),
        ),
      ),
    )).toList())).toList());
  }

  @override
  Widget build(BuildContext context) {
    final mf = _Mf(context);
    _syncCategoryIcons(ref.read(repoProvider));
    final title = _editing
        ? (_isIncome ? 'Edit income' : 'Edit expense')
        : (_isIncome ? 'New income' : 'New expense');
    return Scaffold(
      backgroundColor: mf.bg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: mf.bar,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        actions: [
          if (_editing)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          IconButton(
            tooltip: _isIncome ? 'Switch to expense' : 'Switch to income',
            icon: const Icon(Icons.repeat),
            onPressed: _switchType),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 12),
          // date · time
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date,
                    firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  Icon(Icons.calendar_today, size: 18, color: mf.text),
                  const SizedBox(width: 4),
                  Text(DateFormat('EEEE, d MMMM').format(_date), style: TextStyle(color: mf.text, fontSize: 17)),
                ]),
              ),
            ),
            InkWell(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
                if (t != null) setState(() => _date = DateTime(_date.year, _date.month, _date.day, t.hour, t.minute));
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text('· ${TimeOfDay.fromDateTime(_date).format(context)}',
                    style: TextStyle(color: mf.muted, fontSize: 15)),
              ),
            ),
          ]),
          const Spacer(),
          // amount display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: _color,
              elevation: 2,
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 84,
                child: Row(children: [
                  InkWell(
                    onTap: _pickAccount,
                    child: SizedBox(
                      width: 68,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(accountIcon(ref.read(repoProvider), _account), color: Colors.white, size: 30),
                        Text(ref.read(repoProvider).accountById(_account)?.name ?? 'Account',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ]),
                    ),
                  ),
                  Container(width: 1.5, height: 64, color: Colors.white70),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_expr.isEmpty ? '0' : _expr,
                          style: const TextStyle(color: Colors.white, fontSize: 46)),
                    ),
                  )),
                  GestureDetector(
                    onLongPress: () => setState(() => _expr = ''),
                    child: IconButton(
                      onPressed: _backspace,
                      icon: const Icon(Icons.backspace, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(width: 6),
                ]),
              ),
            ),
          ),
          // note
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: RawAutocomplete<String>(
              textEditingController: _note,
              focusNode: _noteFocus,
              optionsViewOpenDirection: OptionsViewOpenDirection.up,
              optionsBuilder: (v) => _noteHints(v.text),
              onSelected: (n) {
                // also fills the type when it is still empty
                if (_category == null) {
                  for (final t in ref.read(repoProvider).txnList) {
                    if (t.note.trim() == n && t.type == _type && t.sourceRef.isEmpty) {
                      setState(() => _category = t.category);
                      break;
                    }
                  }
                }
                setState(() {});
              },
              fieldViewBuilder: (context, c, f, onSubmit) => TextField(
                controller: c,
                focusNode: f,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: mf.text),
                decoration: InputDecoration(
                  filled: false,
                  hintText: 'Add note',
                  hintStyle: TextStyle(color: mf.muted.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.edit_outlined, color: mf.muted),
                  border: UnderlineInputBorder(borderSide: BorderSide(color: mf.line)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: mf.line)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: mf.muted)),
                ),
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.bottomLeft,
                child: Material(
                  color: mf.keyFill,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 40, maxHeight: 220),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final o in options)
                          ListTile(
                            dense: true,
                            leading: Icon(Icons.history, size: 18, color: mf.muted),
                            title: Text(o, style: TextStyle(color: mf.text)),
                            onTap: () => onSelected(o),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Builder(builder: (context) {
            final sug = _suggestions(ref.read(repoProvider));
            if (sug.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Earlier similar costs — tap to use',
                    style: TextStyle(color: mf.muted, fontSize: 11.5)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final t in sug)
                    ActionChip(
                      avatar: Icon(catIcon(t.category), size: 16, color: catColor(t.category)),
                      label: Text(
                          '${t.note.isEmpty ? t.category : '${t.note} · ${t.category}'} ৳${_fmt(t.amount)}',
                          style: TextStyle(color: mf.text, fontSize: 12)),
                      backgroundColor: mf.keyFill,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () => _useSuggestion(t),
                    ),
                ]),
              ]),
            );
          }),
          const Spacer(flex: 2),
          if (_category != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ActionChip(
                backgroundColor: mf.keyFill,
                side: BorderSide(color: mf.line),
                avatar: Icon(catIcon(_category!), color: catColor(_category!), size: 20),
                label: Text(_category!, style: TextStyle(color: mf.ink(catColor(_category!)))),
                onPressed: () async {
                  final c = await _pickCategory();
                  if (c != null) setState(() => _category = c);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(children: [
              _keypad(mf),
              Padding(
                padding: const EdgeInsets.all(2),
                child: _wideKey(mf,
                    _category == null ? 'CHOOSE CATEGORY' : (_editing ? 'UPDATE' : 'ADD'),
                    onTap: _save),
              ),
            ]),
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }
}

/// "New category" dialog: name + icon from the built-in set.
/// Pops with (name, iconKey).
class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog({required this.taken});
  final Set<String> taken; // existing names (lower-case)
  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _name = TextEditingController();
  String _icon = 'other';
  String? _error;

  void _submit() {
    final n = _name.text.trim();
    if (n.isEmpty) return setState(() => _error = 'Enter a name');
    if (widget.taken.contains(n.toLowerCase())) {
      return setState(() => _error = 'This category already exists');
    }
    Navigator.pop(context, (n, _icon));
  }

  @override
  Widget build(BuildContext context) {
    final mf = _Mf(context);
    final color = catColor(_name.text.trim());
    return AlertDialog(
      backgroundColor: mf.bg,
      title: Text('New category', style: TextStyle(color: mf.text)),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(kCategoryIcons[_icon], color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: 'Category name', errorText: _error),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            )),
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Choose icon', style: TextStyle(color: mf.muted, fontSize: 13)),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: kCategoryIcons.entries.map((e) {
                final sel = e.key == _icon;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _icon = e.key),
                  child: Container(
                    decoration: BoxDecoration(
                      color: sel ? mf.selFill : null,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? _Mf.green : Colors.transparent, width: 1.5),
                    ),
                    child: Icon(e.value, color: sel ? color : mf.text, size: 24),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _Mf.greenFill, minimumSize: const Size(88, 44)),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

