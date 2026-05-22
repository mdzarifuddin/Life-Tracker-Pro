import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data.dart';

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
