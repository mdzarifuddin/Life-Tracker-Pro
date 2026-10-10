import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';

const _bazarQuickItems = [
  'Rice', 'Oil', 'Onion', 'Potato', 'Egg', 'Dal', 'Garlic', 'Salt',
  'Sugar', 'Flour', 'Fish', 'Chicken', 'Milk', 'Tea', 'Vegetables',
];

class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});
  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Lists'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Bazar'), Tab(text: 'Future Needs')]),
      ),
      body: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            color: AppColors.accent.withValues(alpha: 0.10),
            padding: const EdgeInsets.all(10),
            child: const Text('🔗 Real-time family sharing (Google) arrives in v1.1.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: repo.listitemsL,
              builder: (context, _) => TabBarView(controller: _tabs, children: [
                _BazarTab(repo: repo),
                _FutureTab(repo: repo),
              ]),
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addItem',
        onPressed: () => showItemSheet(context, _tabs.index == 0 ? 'bazar' : 'future'),
        icon: const Icon(Icons.add), label: const Text('Item'),
      ),
    );
  }
}

class _BazarTab extends StatelessWidget {
  const _BazarTab({required this.repo});
  final Repo repo;

  Future<void> _markBought(ListItem it) async {
    if (it.estPrice > 0) {
      await repo.saveTxn(Txn(
        id: newId(), type: 'expense', category: 'Bazar', amount: it.estPrice,
        date: DateTime.now(), note: it.name));
    }
    await repo.deleteItem(it.id);
  }

  @override
  Widget build(BuildContext context) {
    final items = repo.itemsOf('bazar');
    final total = items.fold(0.0, (s, e) => s + e.estPrice);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Align(alignment: Alignment.centerLeft,
            child: Text('Tap to add', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))),
      ),
      // short chips that wrap onto 2-3 rows (no sideways scrolling)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 6,
            runSpacing: 0,
            children: _bazarQuickItems.map((q) => ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 12.5)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  onPressed: () => repo.saveItem(
                      ListItem(id: newId(), listType: 'bazar', name: q, category: 'Bazar')),
                )).toList(),
          ),
        ),
      ),
      const Divider(height: 16),
      if (items.isEmpty)
        const Expanded(child: EmptyState(icon: Icons.local_grocery_store,
            message: 'Bazar list is empty.\nTap a suggestion above, or + for items.'))
      else ...[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: items.map((it) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Card(
                child: ListTile(
                  onTap: () => showItemSheet(context, 'bazar', existing: it),
                  leading: IconButton(
                    tooltip: 'Bought (add to expense)',
                    icon: const Icon(Icons.check_circle_outline, color: AppColors.income),
                    onPressed: () => _markBought(it),
                  ),
                  title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([if (it.qty.isNotEmpty) it.qty, if (it.estPrice > 0) taka(it.estPrice)].join(' · ')),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => repo.deleteItem(it.id),
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Text('Est. total: ${taka(total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _completeTrip(context, repo, total),
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Complete Trip'),
              ),
            ]),
          ),
        ),
      ],
    ]);
  }

  Future<void> _completeTrip(BuildContext context, Repo repo, double est) async {
    final controller = TextEditingController(text: est == 0 ? '' : est.toStringAsFixed(0));
    final total = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Complete shopping trip'),
        content: TextField(
          controller: controller, autofocus: true, keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(prefixText: '৳ ', labelText: 'Actual total spent'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, double.tryParse(controller.text.trim()) ?? 0), child: const Text('Log & Clear')),
        ],
      ),
    );
    if (total == null) return;
    if (total > 0) {
      await repo.saveTxn(Txn(id: newId(), type: 'expense', category: 'Bazar', amount: total,
          date: DateTime.now(), note: 'Bazar trip'));
    }
    for (final it in repo.itemsOf('bazar')) {
      await repo.deleteItem(it.id);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged ${taka(total)} expense · list cleared')));
    }
  }
}

class _FutureTab extends StatelessWidget {
  const _FutureTab({required this.repo});
  final Repo repo;
  @override
  Widget build(BuildContext context) {
    final items = repo.itemsOf('future')..sort((a, b) => a.priorityRank.compareTo(b.priorityRank));
    if (items.isEmpty) {
      return const EmptyState(icon: Icons.star_border, message: 'No future needs yet.\nLaptop, furniture, etc.');
    }
    Color pColor(String p) => p == 'high' ? AppColors.expense : p == 'low' ? AppColors.savings : AppColors.warning;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: items.map((it) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PadCard(
          onTap: () => showItemSheet(context, 'future', existing: it),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: pColor(it.priority).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.flag, color: pColor(it.priority)),
            ),
            Gap.m,
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: pColor(it.priority).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                  child: Text(it.priority.toUpperCase(), style: TextStyle(color: pColor(it.priority), fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                if (it.note.isNotEmpty) ...[const SizedBox(width: 8),
                  Expanded(child: Text(it.note, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)))],
              ]),
            ])),
            if (it.estPrice > 0)
              Text(taka(it.estPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => repo.deleteItem(it.id)),
          ]),
        ),
      )).toList(),
    );
  }
}

/// For bazar-add (no existing) shows a multi-select sheet; otherwise a single-item form.
void showItemSheet(BuildContext context, String type, {ListItem? existing}) {
  showModalBottomSheet(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: (type == 'bazar' && existing == null)
          ? const _BazarMultiSheet()
          : _ItemSheet(type: type, existing: existing),
    ),
  );
}

class _BazarMultiSheet extends ConsumerStatefulWidget {
  const _BazarMultiSheet();
  @override
  ConsumerState<_BazarMultiSheet> createState() => _BazarMultiSheetState();
}

class _BazarMultiSheetState extends ConsumerState<_BazarMultiSheet> {
  final _selected = <String>{};
  final _extra = <String>[];
  final _custom = TextEditingController();

  void _addCustom() {
    final n = _custom.text.trim();
    if (n.isEmpty) return;
    setState(() {
      if (!_bazarQuickItems.contains(n) && !_extra.contains(n)) _extra.add(n);
      _selected.add(n);
      _custom.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = [..._bazarQuickItems, ..._extra];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Add Bazar Items', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('Select multiple, then add', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
        Gap.m,
        Wrap(spacing: 8, runSpacing: 8, children: all.map((q) => FilterChip(
              label: Text(q),
              selected: _selected.contains(q),
              onSelected: (v) => setState(() => v ? _selected.add(q) : _selected.remove(q)),
            )).toList()),
        Gap.m,
        Row(children: [
          Expanded(child: TextField(controller: _custom,
              decoration: const InputDecoration(labelText: 'Custom item'),
              onSubmitted: (_) => _addCustom())),
          IconButton.filledTonal(onPressed: _addCustom, icon: const Icon(Icons.add)),
        ]),
        Gap.l,
        FilledButton(
          onPressed: _selected.isEmpty ? null : () async {
            final repo = ref.read(repoProvider);
            for (final name in _selected) {
              await repo.saveItem(ListItem(id: newId(), listType: 'bazar', name: name, category: 'Bazar'));
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(_selected.isEmpty ? 'Select items' : 'Add ${_selected.length} item(s)'),
        ),
        Gap.s,
      ]),
    );
  }
}

class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet({required this.type, this.existing});
  final String type;
  final ListItem? existing;
  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();
  String _priority = 'med';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _qty.text = e.qty;
      _price.text = e.estPrice == 0 ? '' : e.estPrice.toStringAsFixed(0);
      _note.text = e.note;
      _priority = e.priority;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bazar = widget.type == 'bazar';
    final editing = widget.existing != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(editing ? 'Edit Item' : (bazar ? 'Add Bazar Item' : 'Add Future Need'),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Gap.m,
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Item name')),
        Gap.s,
        Row(children: [
          if (bazar) Expanded(child: TextField(controller: _qty,
              decoration: const InputDecoration(labelText: 'Qty (e.g. 2 kg)'))),
          if (bazar) Gap.s,
          Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Price (৳)'))),
        ]),
        if (!bazar) ...[
          Gap.s,
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
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note / details')),
        ],
        Gap.l,
        FilledButton(
          onPressed: () async {
            if (_name.text.trim().isEmpty) return;
            await ref.read(repoProvider).saveItem(ListItem(
              id: widget.existing?.id ?? newId(), listType: widget.type,
              name: _name.text.trim(), qty: _qty.text.trim(),
              category: bazar ? 'Bazar' : '', priority: _priority,
              note: _note.text.trim(), estPrice: double.tryParse(_price.text.trim()) ?? 0,
            ));
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(editing ? 'Update' : 'Add'),
        ),
        Gap.s,
      ]),
    );
  }
}
