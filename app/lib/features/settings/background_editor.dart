import 'package:flutter/material.dart';

import '../../core/appearance.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';

/// Bottom sheet to build a custom background (2–3 colours + direction).
/// Returns the new background, or null if cancelled.
Future<CustomBg?> showBackgroundEditor(BuildContext context, Brightness b, CustomBg initial) =>
    showModalBottomSheet<CustomBg>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _BackgroundEditor(brightness: b, initial: initial),
    );

/// Quick picks: deep shades for dark mode, pastels for light mode.
const _darkPalette = <int>[
  0xFF3B2D83, 0xFF24408A, 0xFF17506A, 0xFF0B0F1A, 0xFF131A2B, 0xFF4A1942,
  0xFF73283E, 0xFF7A4220, 0xFF0B3C5D, 0xFF0E5A75, 0xFF143D2B, 0xFF1E5639,
  0xFF6B2350, 0xFF3F1A44, 0xFF23262E, 0xFF5B2A86, 0xFF1E3A8A, 0xFF7C2D12,
];
const _lightPalette = <int>[
  0xFFFFD9EC, 0xFFE6D8FF, 0xFFFFF3C4, 0xFFCFF3E0, 0xFFD3E9FF, 0xFFFFDCC7,
  0xFFE6D9FF, 0xFFF3F4F7, 0xFFFFE4E1, 0xFFE0F7FA, 0xFFFFF9DB, 0xFFE8F5E9,
  0xFFFCE4EC, 0xFFEDE7F6, 0xFFE3F2FD, 0xFFFFF3E0, 0xFFF1F8E9, 0xFFFFFFFF,
];

class _BackgroundEditor extends StatefulWidget {
  const _BackgroundEditor({required this.brightness, required this.initial});
  final Brightness brightness;
  final CustomBg initial;
  @override
  State<_BackgroundEditor> createState() => _BackgroundEditorState();
}

class _BackgroundEditorState extends State<_BackgroundEditor> {
  late List<HSVColor> _colors;
  late BgDirection _dir;
  int _sel = 0;

  @override
  void initState() {
    super.initState();
    _colors = [for (final c in widget.initial.colors) HSVColor.fromColor(c)];
    _dir = widget.initial.direction;
  }

  CustomBg get _bg => CustomBg([for (final c in _colors) c.toColor()], _dir);

  void _update(HSVColor c) => setState(() => _colors[_sel] = c);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = _bg;
    final cur = _colors[_sel];
    final palette = widget.brightness == Brightness.dark ? _darkPalette : _lightPalette;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Custom background'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Gap.m,
          // live preview
          Container(
            height: 130,
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: bg.gradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outline),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Preview'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12)),
                child: Text(tr('This is how text will look.'),
                    style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          if (!bg.readableFor(widget.brightness)) ...[
            Gap.s,
            Row(children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(tr('Text may be hard to read on this background.'),
                  style: const TextStyle(color: AppColors.warning, fontSize: 12.5, fontWeight: FontWeight.w600))),
            ]),
          ],
          Gap.l,
          Text(tr('Colours'), style: const TextStyle(fontWeight: FontWeight.w700)),
          Gap.s,
          Row(children: [
            for (var i = 0; i < _colors.length; i++) ...[
              GestureDetector(
                onTap: () => setState(() => _sel = i),
                child: Semantics(
                  label: tr('Colour {n}', {'n': i + 1}),
                  selected: _sel == i,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: _colors[i].toColor(),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _sel == i ? AppColors.primary : cs.outline, width: _sel == i ? 3 : 1),
                    ),
                    child: _sel == i
                        ? Icon(Icons.edit, size: 18,
                            color: _colors[i].toColor().computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                        : null,
                  ),
                ),
              ),
              Gap.m,
            ],
            if (_colors.length < 3)
              IconButton.outlined(
                tooltip: tr('Add colour'),
                onPressed: () => setState(() {
                  _colors.add(_colors.last.withHue((_colors.last.hue + 40) % 360));
                  _sel = _colors.length - 1;
                }),
                icon: const Icon(Icons.add),
              )
            else
              IconButton.outlined(
                tooltip: tr('Remove colour'),
                onPressed: () => setState(() {
                  _colors.removeAt(_sel);
                  _sel = _sel.clamp(0, _colors.length - 1);
                }),
                icon: const Icon(Icons.remove),
              ),
          ]),
          Gap.m,
          _GradientSlider(
            label: tr('Hue'),
            value: cur.hue / 360,
            colors: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()],
            onChanged: (v) => _update(cur.withHue(v * 360)),
          ),
          _GradientSlider(
            label: tr('Saturation'),
            value: cur.saturation,
            colors: [cur.withSaturation(0).toColor(), cur.withSaturation(1).toColor()],
            onChanged: (v) => _update(cur.withSaturation(v)),
          ),
          _GradientSlider(
            label: tr('Brightness'),
            value: cur.value,
            colors: [cur.withValue(0).toColor(), cur.withValue(1).toColor()],
            onChanged: (v) => _update(cur.withValue(v)),
          ),
          Gap.s,
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final v in palette)
              GestureDetector(
                onTap: () => _update(HSVColor.fromColor(Color(v))),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Color(v),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cur.toColor().toARGB32() == v ? AppColors.primary : cs.outline,
                      width: cur.toColor().toARGB32() == v ? 2.5 : 1,
                    ),
                  ),
                ),
              ),
          ]),
          Gap.l,
          Text(tr('Direction'), style: const TextStyle(fontWeight: FontWeight.w700)),
          Gap.s,
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final d in BgDirection.values)
              ChoiceChip(
                showCheckmark: false,
                avatar: Icon(d.icon, size: 16),
                label: Text(tr(d.label)),
                selected: _dir == d,
                onSelected: (_) => setState(() => _dir = d),
              ),
          ]),
          Gap.xl,
          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context), child: Text(tr('Cancel')))),
            Gap.m,
            Expanded(flex: 2, child: FilledButton.icon(
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.pop(context, _bg),
              label: Text(tr('Use this background')),
            )),
          ]),
        ]),
      ),
    );
  }
}

/// A slider drawn over a colour gradient track.
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({required this.label, required this.value, required this.colors, required this.onChanged});
  final String label;
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        SizedBox(
          width: 92,
          child: Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
        ),
        Expanded(
          child: Stack(alignment: Alignment.center, children: [
            Container(
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 14,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11, elevation: 3),
              ),
              child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
            ),
          ]),
        ),
      ]),
    );
  }
}
