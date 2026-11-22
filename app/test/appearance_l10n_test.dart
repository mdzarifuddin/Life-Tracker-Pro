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

  test('appearance defaults when nothing (or junk) is saved', () {
    final a = Appearance.fromSettings((_) => null);
    expect(a.darkBg, 'aurora');
    expect(a.lightBg, 'pastel');
    expect(a.textScale, 1.0);
    final junk = {'bgDark': 'nope', 'bgLight': customBgId, 'bgCustomLight': 'bad', 'textScale': 'x'};
    final b = Appearance.fromSettings((k) => junk[k]);
    expect(b.darkBg, 'aurora');
    expect(b.lightBg, 'pastel'); // custom selected but missing -> default
    expect(b.textScale, 1.0);
  });

  test('appearance survives a JSON backup round-trip', () {
    const custom = CustomBg([Color(0xFF112233), Color(0xFF445566), Color(0xFF778899)], BgDirection.radial);
    final a = const Appearance(darkBg: 'ocean', textScale: 1.15).withBg(Brightness.light, customBgId, custom: custom);
    final json = jsonDecode(jsonEncode(a.toSettings())) as Map<String, dynamic>;
    final b = Appearance.fromSettings((k) => json[k]);
    expect(b.darkBg, 'ocean');
    expect(b.lightBg, customBgId);
    expect(b.customLight, custom);
    expect(b.customDark, isNull);
    expect(b.textScale, 1.15);
    expect(b.background(Brightness.light), isA<RadialGradient>());
    expect(CustomBg.decode(custom.encode()), custom);
  });
}
