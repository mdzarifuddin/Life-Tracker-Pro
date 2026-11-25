import 'package:flutter/material.dart';

import 'l10n.dart';
import 'theme.dart';

/// Seven day buttons (Mon…Sun) that always fit in ONE row, whatever the screen width,
/// text size or language. [selected] holds day indexes, 0 = Monday.
class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({super.key, required this.selected, required this.onChanged});
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      for (var i = 0; i < 7; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _Day(
              label: tr(weekdayNames[i]),
              on: selected.contains(i),
              cs: cs,
              onTap: () {
                final next = {...selected};
                next.contains(i) ? next.remove(i) : next.add(i);
                onChanged(next);
              },
            ),
          ),
        ),
    ]);
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.label, required this.on, required this.cs, required this.onTap});
  final String label;
  final bool on;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = on ? AppColors.primary : cs.surfaceContainer;
    final fg = on ? Colors.white : cs.onSurface;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: on ? null : Border.all(color: cs.outline),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            // Shrinks the label instead of wrapping, so the row never breaks.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  maxLines: 1,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}
