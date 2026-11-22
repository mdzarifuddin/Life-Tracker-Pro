import 'package:flutter/material.dart';

import 'theme.dart';

/// A ready-made app background.
class BgPreset {
  const BgPreset(this.id, this.name, this.gradient);
  final String id;

  /// English name, shown through `tr()`.
  final String name;
  final Gradient gradient;
}

LinearGradient _lg(List<int> c) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [for (final v in c) Color(v)],
    );

/// Backgrounds for dark mode: deep enough for light text.
final darkPresets = <BgPreset>[
  const BgPreset('aurora', 'Aurora', AppColors.darkBg),
  BgPreset('midnight', 'Midnight', _lg([0xFF0B0F1A, 0xFF131A2B, 0xFF0A0E17])),
  BgPreset('sunset', 'Sunset', _lg([0xFF4A1942, 0xFF73283E, 0xFF7A4220, 0xFF34192A])),
  BgPreset('ocean', 'Ocean', _lg([0xFF0B3C5D, 0xFF0E5A75, 0xFF123A5C, 0xFF0A2540])),
  BgPreset('forest', 'Forest', _lg([0xFF143D2B, 0xFF1E5639, 0xFF234B33, 0xFF10291E])),
  BgPreset('rose', 'Rose', _lg([0xFF4C1D3D, 0xFF6B2350, 0xFF3F1A44, 0xFF2A1230])),
  BgPreset('graphite', 'Graphite', _lg([0xFF23262E, 0xFF2E333D, 0xFF1A1D23])),
];

/// Backgrounds for light mode: soft pastels for dark text.
final lightPresets = <BgPreset>[
  const BgPreset('pastel', 'Pastel', AppColors.lightBg),
  BgPreset('mint', 'Mint', _lg([0xFFCFF3E0, 0xFFE8FFF4, 0xFFC9EDE3, 0xFFDDF6EA])),
  BgPreset('sky', 'Sky', _lg([0xFFD3E9FF, 0xFFEAF5FF, 0xFFCFE0FF, 0xFFE3EEFF])),
  BgPreset('peach', 'Peach', _lg([0xFFFFDCC7, 0xFFFFEEDD, 0xFFFFD3C6, 0xFFFFE7D3])),
  BgPreset('lavender', 'Lavender', _lg([0xFFE6D9FF, 0xFFF3ECFF, 0xFFDCD6FF, 0xFFEFE6FF])),
  BgPreset('cloud', 'Cloud', _lg([0xFFF3F4F7, 0xFFE6E9F0, 0xFFF8F9FB])),
];

List<BgPreset> presetsFor(Brightness b) => b == Brightness.dark ? darkPresets : lightPresets;

const customBgId = 'custom';

enum BgDirection {
  diagonal('Diagonal', Icons.south_east),
  diagonalReverse('Diagonal (reverse)', Icons.south_west),
  vertical('Top to bottom', Icons.south),
  horizontal('Left to right', Icons.east),
  radial('Radial', Icons.radio_button_checked);

  const BgDirection(this.label, this.icon);

  /// English label, shown through `tr()`.
  final String label;
  final IconData icon;

  static BgDirection parse(String? v) =>
      BgDirection.values.firstWhere((d) => d.name == v, orElse: () => BgDirection.diagonal);
}

/// A background the user made: 2–3 colours and a direction.
@immutable
class CustomBg {
  const CustomBg(this.colors, this.direction);
  final List<Color> colors;
  final BgDirection direction;

  Gradient get gradient {
    final c = colors.length == 1 ? [colors[0], colors[0]] : colors;
    switch (direction) {
      case BgDirection.radial:
        return RadialGradient(center: Alignment.topLeft, radius: 1.6, colors: c);
      case BgDirection.vertical:
        return LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: c);
      case BgDirection.horizontal:
        return LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: c);
      case BgDirection.diagonalReverse:
        return LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: c);
      case BgDirection.diagonal:
        return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c);
    }
  }

  /// Average luminance (0 = black, 1 = white).
  double get luminance =>
      colors.fold(0.0, (t, c) => t + c.computeLuminance()) / colors.length;

  /// Whether the usual text colour of [b] stays readable on this background.
  bool readableFor(Brightness b) => b == Brightness.dark ? luminance < 0.3 : luminance > 0.45;

  /// Stored as "direction|AARRGGBB,AARRGGBB[,AARRGGBB]".
  String encode() =>
      '${direction.name}|${colors.map((c) => c.toARGB32().toRadixString(16).padLeft(8, '0')).join(',')}';

  /// Reads [encode]'s format; null for missing or damaged values.
  static CustomBg? decode(Object? v) {
    if (v is! String || !v.contains('|')) return null;
    final parts = v.split('|');
    final colors = <Color>[];
    for (final h in parts[1].split(',')) {
      final n = int.tryParse(h.trim(), radix: 16);
      if (n == null) return null;
      colors.add(Color(n));
    }
    if (colors.length < 2 || colors.length > 3) return null;
    return CustomBg(colors, BgDirection.parse(parts[0]));
  }

  /// A starting point for the editor, based on the default look of [b].
  static CustomBg seed(Brightness b) => b == Brightness.dark
      ? const CustomBg([Color(0xFF3B2D83), Color(0xFF17506A)], BgDirection.diagonal)
      : const CustomBg([Color(0xFFFFD9EC), Color(0xFFE6D8FF)], BgDirection.diagonal);

  @override
  bool operator ==(Object other) => other is CustomBg && other.encode() == encode();
  @override
  int get hashCode => encode().hashCode;
}

/// Text size steps shown as chips (the slider allows anything in between).
const textScaleSteps = <(String, double)>[
  ('Small', 0.9),
  ('Normal', 1.0),
  ('Large', 1.15),
  ('Extra large', 1.3),
];
const minTextScale = 0.85, maxTextScale = 1.4;

/// Background + text size choices. Defaults are the app's original look.
@immutable
class Appearance {
  const Appearance({
    this.darkBg = 'aurora',
    this.lightBg = 'pastel',
    this.customDark,
    this.customLight,
    this.textScale = 1.0,
  });

  final String darkBg, lightBg;
  final CustomBg? customDark, customLight;
  final double textScale;

  static const keys = ['bgDark', 'bgLight', 'bgCustomDark', 'bgCustomLight', 'textScale'];

  String bgIdFor(Brightness b) => b == Brightness.dark ? darkBg : lightBg;
  CustomBg? customFor(Brightness b) => b == Brightness.dark ? customDark : customLight;

  Gradient background(Brightness b) {
    final id = bgIdFor(b);
    final custom = customFor(b);
    if (id == customBgId && custom != null) return custom.gradient;
    final list = presetsFor(b);
    return list.firstWhere((p) => p.id == id, orElse: () => list.first).gradient;
  }

  /// Reads saved settings; anything missing or unknown keeps the default.
  factory Appearance.fromSettings(Object? Function(String key) get) {
    String id(String key, List<BgPreset> list, String def) {
      final v = get(key);
      if (v == customBgId) return customBgId;
      return list.any((p) => p.id == v) ? v as String : def;
    }

    final cd = CustomBg.decode(get('bgCustomDark'));
    final cl = CustomBg.decode(get('bgCustomLight'));
    var dark = id('bgDark', darkPresets, 'aurora');
    var light = id('bgLight', lightPresets, 'pastel');
    if (dark == customBgId && cd == null) dark = 'aurora';
    if (light == customBgId && cl == null) light = 'pastel';
    final s = get('textScale');
    final scale = s is num ? s.toDouble().clamp(minTextScale, maxTextScale) : 1.0;
    return Appearance(darkBg: dark, lightBg: light, customDark: cd, customLight: cl, textScale: scale);
  }

  /// JSON-friendly values for the settings box (null = remove the key).
  Map<String, Object?> toSettings() => {
        'bgDark': darkBg,
        'bgLight': lightBg,
        'bgCustomDark': customDark?.encode(),
        'bgCustomLight': customLight?.encode(),
        'textScale': textScale,
      };

  Appearance copyWith({
    String? darkBg,
    String? lightBg,
    CustomBg? customDark,
    CustomBg? customLight,
    double? textScale,
  }) =>
      Appearance(
        darkBg: darkBg ?? this.darkBg,
        lightBg: lightBg ?? this.lightBg,
        customDark: customDark ?? this.customDark,
        customLight: customLight ?? this.customLight,
        textScale: textScale ?? this.textScale,
      );

  /// Selects background [id] for brightness [b] (optionally saving a custom one).
  Appearance withBg(Brightness b, String id, {CustomBg? custom}) => b == Brightness.dark
      ? copyWith(darkBg: id, customDark: custom)
      : copyWith(lightBg: id, customLight: custom);
}

/// Multiplies the system text scaling by the app's own factor.
class AppTextScaler extends TextScaler {
  const AppTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => system.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler && other.system == system && other.factor == factor;
  @override
  int get hashCode => Object.hash(system, factor);
}
