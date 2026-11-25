import 'package:flutter/material.dart';

import 'theme.dart';

/// One of the app's three fixed backgrounds. Each one also fixes the theme:
/// Pastel is light, Aurora and Midnight are dark.
class BgOption {
  const BgOption(this.id, this.name, this.brightness, this.gradient);
  final String id;

  /// English name, shown through `tr()`.
  final String name;
  final Brightness brightness;
  final Gradient gradient;

  bool get isDark => brightness == Brightness.dark;
}

const pastelBg = BgOption('pastel', 'Pastel', Brightness.light, AppColors.lightBg);
const auroraBg = BgOption('aurora', 'Aurora', Brightness.dark, AppColors.darkBg);
const midnightBg = BgOption('midnight', 'Midnight', Brightness.dark, AppColors.midnightBg);

/// All backgrounds, in the order shown in Settings.
const bgOptions = <BgOption>[pastelBg, auroraBg, midnightBg];

BgOption bgById(String? id) =>
    bgOptions.firstWhere((o) => o.id == id, orElse: () => auroraBg);

/// Text size steps shown as chips (the slider allows anything in between).
const textScaleSteps = <(String, double)>[
  ('Small', 0.9),
  ('Normal', 1.0),
  ('Large', 1.15),
  ('Extra large', 1.3),
];
const minTextScale = 0.85, maxTextScale = 1.4;

/// Background + text size choices. Defaults: Aurora, normal size.
@immutable
class Appearance {
  const Appearance({this.bg = 'aurora', this.textScale = 1.0});

  /// Id of the chosen [BgOption].
  final String bg;
  final double textScale;

  /// Keys this class writes; [legacyKeys] are older ones it reads once and clears.
  static const keys = ['bg', 'textScale'];
  static const legacyKeys = ['bgDark', 'bgLight', 'bgCustomDark', 'bgCustomLight', 'themeMode'];

  BgOption get option => bgById(bg);
  Brightness get brightness => option.brightness;
  Gradient get gradient => option.gradient;
  ThemeMode get themeMode => option.isDark ? ThemeMode.dark : ThemeMode.light;

  /// Reads saved settings; anything missing or unknown falls back sensibly.
  /// Settings from older versions (light/dark/system mode + many presets or a
  /// custom background) map to the nearest of the three backgrounds.
  factory Appearance.fromSettings(Object? Function(String key) get) {
    final s = get('textScale');
    final scale = s is num ? s.toDouble().clamp(minTextScale, maxTextScale) : 1.0;
    final id = get('bg');
    if (id is String && bgOptions.any((o) => o.id == id)) {
      return Appearance(bg: id, textScale: scale);
    }
    return Appearance(bg: _migrate(get), textScale: scale);
  }

  static String _migrate(Object? Function(String key) get) {
    final mode = get('themeMode');
    if (mode == 'light') return pastelBg.id; // any light background -> Pastel
    final dark = get('bgDark');
    if (dark == 'midnight' || dark == 'graphite') return midnightBg.id;
    if (dark == 'custom') {
      final l = _customLuminance(get('bgCustomDark'));
      if (l != null && l > 0.3) return pastelBg.id; // it was a light background
      if (l != null && l < 0.03) return midnightBg.id;
    }
    return auroraBg.id;
  }

  /// Average luminance of an old custom background ("direction|AARRGGBB,..."), or null.
  static double? _customLuminance(Object? v) {
    if (v is! String || !v.contains('|')) return null;
    final cols = <Color>[];
    for (final h in v.split('|')[1].split(',')) {
      final n = int.tryParse(h.trim(), radix: 16);
      if (n == null) return null;
      cols.add(Color(n));
    }
    if (cols.isEmpty) return null;
    return cols.fold(0.0, (t, c) => t + c.computeLuminance()) / cols.length;
  }

  /// JSON-friendly values for the settings box (null = remove the key).
  Map<String, Object?> toSettings() => {
        'bg': bg,
        'textScale': textScale,
        for (final k in legacyKeys) k: null,
      };

  Appearance copyWith({String? bg, double? textScale}) =>
      Appearance(bg: bg ?? this.bg, textScale: textScale ?? this.textScale);
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
