import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    );
  }
}
