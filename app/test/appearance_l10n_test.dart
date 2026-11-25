import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker_pro/core/appearance.dart';
import 'package:life_tracker_pro/core/l10n.dart';

void main() {
  test('language lookup: Bangla, fallback and placeholders', () {
    expect(trIn(AppLang.en, 'Save'), 'Save');
    expect(trIn(AppLang.bn, 'Save'), 'সেভ');
    expect(trIn(AppLang.bn, 'Not translated yet'), 'Not translated yet');
    expect(trIn(AppLang.bn, 'Current ({n})', {'n': 3}), 'বর্তমান (3)');
    expect(trIn(AppLang.en, '{n} classes', {'n': 5}), '5 classes');
    expect(AppLang.parse('bn'), AppLang.bn);
    expect(AppLang.parse(null), AppLang.en);
    expect(AppLang.parse('xx'), AppLang.en);
    setLangSilently(AppLang.bn);
    expect(tr('Home'), 'হোম');
    setLangSilently(AppLang.en);
    expect(tr('Home'), 'Home');
  });

  test('appearance defaults (Aurora, dark) when nothing or junk is saved', () {
    final a = Appearance.fromSettings((_) => null);
    expect(a.bg, 'aurora');
    expect(a.themeMode, ThemeMode.dark);
    expect(a.textScale, 1.0);
    final junk = {'bg': 'nope', 'bgDark': 42, 'bgCustomDark': 'bad|zz', 'textScale': 'x'};
    final b = Appearance.fromSettings((k) => junk[k]);
    expect(b.bg, 'aurora');
    expect(b.textScale, 1.0);
    expect(bgOptions.map((o) => o.id), ['pastel', 'aurora', 'midnight']);
    expect(pastelBg.brightness, Brightness.light);
  });

  test('old settings map to the nearest of the three backgrounds', () {
    Appearance from(Map<String, Object?> m) => Appearance.fromSettings((k) => m[k]);
    expect(from({'themeMode': 'light', 'bgLight': 'mint'}).bg, 'pastel');
    expect(from({'themeMode': 'dark', 'bgDark': 'graphite'}).bg, 'midnight');
    expect(from({'themeMode': 'dark', 'bgDark': 'midnight'}).bg, 'midnight');
    expect(from({'themeMode': 'dark', 'bgDark': 'sunset'}).bg, 'aurora');
    expect(from({'themeMode': 'system', 'bgDark': 'ocean'}).bg, 'aurora');
    // a light custom background used in dark mode -> Pastel
    expect(from({'bgDark': 'custom', 'bgCustomDark': 'horizontal|ffe8fff4,ffeaf5ff,fffde8f7'}).bg, 'pastel');
  });

  test('appearance survives a JSON backup round-trip and clears old keys', () {
    const a = Appearance(bg: 'midnight', textScale: 1.15);
    final json = jsonDecode(jsonEncode(a.toSettings())) as Map<String, dynamic>;
    final b = Appearance.fromSettings((k) => json[k]);
    expect(b.bg, 'midnight');
    expect(b.textScale, 1.15);
    expect(b.themeMode, ThemeMode.dark);
    for (final k in Appearance.legacyKeys) {
      expect(json.containsKey(k) && json[k] != null, isFalse);
    }
  });
}
