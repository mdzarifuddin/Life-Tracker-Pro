import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';

class ThesisScreen extends ConsumerStatefulWidget {
  const ThesisScreen({super.key});
  @override
  ConsumerState<ThesisScreen> createState() => _ThesisScreenState();
}

class _ThesisScreenState extends ConsumerState<ThesisScreen> {
  final _live = <String, double>{};

  Future<String?> _askName(String title, String initial) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c, autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Literature Review'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final repo = ref.read(repoProvider);
    final name = await _askName('New stage', '');
    if (name == null || name.isEmpty) return;
    final next = repo.thesisStages.fold(-1, (m, s) => s.order > m ? s.order : m) + 1;
    await repo.saveThesis(ThesisStage(id: newId(), stage: name, order: next));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('MSc Thesis')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: repo.thesisL,
          builder: (context, _) {
            final stages = repo.thesisStages;
            if (stages.isEmpty) {
              return EmptyState(
                icon: Icons.school_outlined,
                message: 'No stages yet.\nAdd your own, e.g. Literature Review, Writing…',
                cta: 'Add stage',
                onCta: _add,
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                PadCard(child: ProgressRow(
                    label: 'Overall Progress', percent: repo.thesisProgress, color: AppColors.primary)),
                Gap.l,
                ...stages.map((s) {
                  final value = _live[s.id] ?? s.progress.toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PadCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(s.stage, style: const TextStyle(fontWeight: FontWeight.w700))),
                          Text('${value.round()}%',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'rename') {
                                final n = await _askName('Rename stage', s.stage);
                                if (n != null && n.isNotEmpty) {
                                  await repo.saveThesis(ThesisStage(id: s.id, stage: n,
                                      progress: s.progress, notes: s.notes, order: s.order));
                                }
                              } else {
                                await repo.deleteThesis(s.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'rename', child: Text('Rename')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ]),
                        Slider(
                          value: value, min: 0, max: 100, divisions: 20,
                          onChanged: (v) => setState(() => _live[s.id] = v),
                          onChangeEnd: (v) => repo.saveThesis(ThesisStage(
                              id: s.id, stage: s.stage, progress: v.round(),
                              notes: s.notes, order: s.order)),
                        ),
                      ]),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addThesisStage',
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Stage'),
      ),
    );
  }
}
