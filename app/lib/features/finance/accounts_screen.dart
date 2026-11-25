part of 'finance_screen.dart';

/// Manage main accounts and their sub-accounts.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, {FinAccount? existing, String? parentId}) async {
    final repo = ref.read(repoProvider);
    // an account can be moved under another one unless it has sub-accounts itself
    final canMove = existing != null && (!existing.isMain || repo.subsOf(existing.id).isEmpty);
    final res = await showDialog<_AccountResult>(
      context: context,
      builder: (_) => _AccountDialog(
        initialName: existing?.name ?? '',
        initialIcon: existing?.icon ?? (parentId == null ? 'wallet' : repo.accountById(parentId)?.icon ?? 'wallet'),
        title: existing != null
            ? 'Edit account'
            : parentId == null ? 'New account (person or group)' : 'New sub-account of ${repo.accountName(parentId)}',
        parents: canMove ? repo.mainAccounts.where((m) => m.id != existing.id).toList() : const [],
        initialParent: existing?.parentId ?? '',
        offerSubs: existing == null && parentId == null,
        showTotalSwitch: existing == null ? parentId == null : existing.isMain,
        initialInTotal: existing?.inTotal ?? true,
      ),
    );
    if (res == null) return;
    final id = existing?.id ?? newId();
    await repo.saveAccount(FinAccount(
      id: id, name: res.name, icon: res.icon, inTotal: res.inTotal,
      parentId: existing == null ? (parentId ?? '') : (canMove ? res.parent : existing.parentId)));
    for (final w in res.subs) {
      await repo.saveAccount(FinAccount(id: newId(), name: w.$1, icon: w.$2, parentId: id));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, FinAccount a) async {
    final repo = ref.read(repoProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${a.name}?'),
        content: Text(a.isMain
            ? 'Only accounts with no records and no sub-accounts can be deleted.'
            : 'Its records move to ${repo.accountName(a.parentId)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _Mf.redFill),
              onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await repo.deleteAccount(a.id);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final mf = _Mf(context);
    return Scaffold(
      backgroundColor: mf.bg,
      appBar: AppBar(
        backgroundColor: mf.bar,
        foregroundColor: Colors.white,
        title: const Text('Accounts'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(22),
          child: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Tap an account to open its expense tracker',
                style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 12)),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _Mf.greenFill,
        foregroundColor: Colors.white,
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Account'),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([repo.accountsL, repo.txnsL]),
        builder: (context, _) {
          return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
            for (final m in repo.mainAccounts)
              Card(
                color: mf.keyFill,
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(children: [
                  ListTile(
                    onTap: () => Navigator.pop(context, m.id),
                    leading: Icon(accountIcon(repo, m.id), color: _Mf.green, size: 30),
                    title: Text(m.name, style: TextStyle(color: mf.text, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        m.inTotal ? 'Total incl. sub-accounts' : 'Separate · not in the All total',
                        style: TextStyle(color: m.inTotal ? mf.muted : Colors.orange, fontSize: 11)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      moneyText(repo.accountBalance(m.id),
                          color: repo.accountBalance(m.id) < 0 ? _Mf.red : _Mf.green, size: 16),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'sub') _edit(context, ref, parentId: m.id);
                          if (v == 'edit') _edit(context, ref, existing: m);
                          if (v == 'del') _delete(context, ref, m);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'sub', child: Text('Add sub-account')),
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'del', child: Text('Delete')),
                        ],
                      ),
                    ]),
                  ),
                  for (final s in repo.subsOf(m.id))
                    ListTile(
                      dense: true,
                      onTap: () => Navigator.pop(context, s.id),
                      contentPadding: const EdgeInsets.only(left: 40, right: 4),
                      leading: Icon(accountIcon(repo, s.id), color: mf.muted, size: 22),
                      title: Text(s.name, style: TextStyle(color: mf.text)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        moneyText(repo.accountBalance(s.id),
                            color: repo.accountBalance(s.id) < 0 ? _Mf.red : mf.text, size: 14),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 18, color: mf.muted),
                          onPressed: () => _edit(context, ref, existing: s)),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: mf.muted),
                          onPressed: () => _delete(context, ref, s)),
                      ]),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _edit(context, ref, parentId: m.id),
                      style: TextButton.styleFrom(foregroundColor: _Mf.green),
                      icon: const Icon(Icons.subdirectory_arrow_right, size: 18),
                      label: const Text('Add sub-account'),
                    ),
                  ),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}

class _AccountResult {
  _AccountResult(this.name, this.icon, this.parent, this.subs, this.inTotal);
  final String name, icon, parent; // parent '' = top-level account
  final bool inTotal;
  final List<(String, String)> subs; // wallets to create inside (name, icon)
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({
    required this.initialName, required this.initialIcon, required this.title,
    this.parents = const [], this.initialParent = '', this.offerSubs = false,
    this.showTotalSwitch = false, this.initialInTotal = true});
  final bool showTotalSwitch, initialInTotal;
  final String initialName, initialIcon, title, initialParent;
  final List<FinAccount> parents;
  final bool offerSubs;
  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  static const _wallets = <(String, String)>[
    ('Cash', 'cash'), ('bKash', 'phone'), ('Nagad', 'phone'), ('Bank', 'bank'), ('Card', 'card'),
  ];
  late final _name = TextEditingController(text: widget.initialName);
  late String _icon = widget.initialIcon;
  late String _parent = widget.parents.any((p) => p.id == widget.initialParent) ? widget.initialParent : '';
  final _subs = <String>{'Cash', 'bKash', 'Bank'};
  late bool _inTotal = widget.initialInTotal;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                labelText: 'Name',
                helperText: widget.offerSubs ? 'e.g. Husband, Wife, Business' : null)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: kAccountIcons.entries.map((e) => ChoiceChip(
              label: Icon(e.value, size: 22),
              selected: _icon == e.key,
              onSelected: (_) => setState(() => _icon = e.key),
            )).toList()),
        if (widget.showTotalSwitch) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _Mf.green,
            title: const Text('Add to the total'),
            subtitle: Text(_inTotal
                ? 'Counted in "All accounts"'
                : 'Separate account: kept out of the All total'),
            value: _inTotal,
            onChanged: (v) => setState(() => _inTotal = v),
          ),
        ],
        if (widget.parents.isNotEmpty) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _parent,
            decoration: const InputDecoration(labelText: 'Belongs to'),
            items: [
              const DropdownMenuItem(value: '', child: Text('— none (top-level) —')),
              for (final p in widget.parents) DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _parent = v ?? ''),
          ),
        ],
        if (widget.offerSubs) ...[
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft,
              child: Text('Create inside it', style: TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 6, runSpacing: 4, children: [
            for (final w in _wallets)
              FilterChip(
                label: Text(w.$1),
                selected: _subs.contains(w.$1),
                onSelected: (v) => setState(() => v ? _subs.add(w.$1) : _subs.remove(w.$1)),
              ),
          ])),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _Mf.greenFill),
          onPressed: () {
            final n = _name.text.trim();
            if (n.isEmpty) return;
            Navigator.pop(context, _AccountResult(n, _icon, _parent,
                widget.offerSubs ? _wallets.where((w) => _subs.contains(w.$1)).toList() : const [], _inTotal));
          },
          child: const Text('Save')),
      ],
    );
  }
}
