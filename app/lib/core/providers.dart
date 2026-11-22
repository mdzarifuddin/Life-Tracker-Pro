import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'appearance.dart';
import 'data.dart';
import 'l10n.dart';

final repoProvider = Provider<Repo>((ref) => Repo());

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(repoProvider).themeMode;

  void set(ThemeMode m) {
    ref.read(repoProvider).themeMode = m;
    state = m;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Background presets / custom background / text size, saved in settings.
class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() {
    final s = ref.read(repoProvider).settings;
    return Appearance.fromSettings(s.get);
  }

  void set(Appearance a) {
    final s = ref.read(repoProvider).settings;
    a.toSettings().forEach((k, v) => v == null ? s.delete(k) : s.put(k, v));
    state = a;
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, Appearance>(AppearanceNotifier.new);

/// App language, saved in settings ('lang'). Changing it rebuilds every screen.
class LangNotifier extends Notifier<AppLang> {
  @override
  AppLang build() {
    final l = AppLang.parse(ref.read(repoProvider).settings.get('lang'));
    setLangSilently(l);
    return l;
  }

  void set(AppLang l) {
    ref.read(repoProvider).settings.put('lang', l.name);
    state = l;
    applyLang(l);
  }
}

final langProvider = NotifierProvider<LangNotifier, AppLang>(LangNotifier.new);

/// Re-reads theme, appearance and language from settings (after a restore).
void reloadPreferences(WidgetRef ref) {
  ref.invalidate(themeModeProvider);
  ref.invalidate(appearanceProvider);
  ref.invalidate(langProvider);
  applyLang(ref.read(langProvider), force: true);
}

/// Currently selected month (first day) for the Finance screen.
class MonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  void shift(int months) =>
      state = DateTime(state.year, state.month + months);
}

final monthProvider = NotifierProvider<MonthNotifier, DateTime>(MonthNotifier.new);

/// Whether the Finance vault is unlocked for this session.
class VaultNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void unlock() => state = true;
  void lock() => state = false;
}

final vaultProvider = NotifierProvider<VaultNotifier, bool>(VaultNotifier.new);
