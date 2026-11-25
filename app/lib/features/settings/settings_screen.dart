import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/appearance.dart';
import '../../core/backup.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/updater.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Text scale while the slider is being dragged (saved on release).
  double? _dragScale;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repoProvider);
    final hasPin = repo.pinHash != null;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Settings'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SectionTitle(tr('Appearance'), icon: Icons.palette_outlined, color: AppColors.primary),
            _appearanceCard(context),
            Gap.l,
            SectionTitle(tr('Language'), icon: Icons.translate, color: AppColors.accent),
            _languageCard(context),
            Gap.l,
            SectionTitle(tr('Security'), icon: Icons.shield_outlined, color: AppColors.income),
            Card(child: Column(children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(hasPin ? tr('Change Vault PIN') : tr('Set Vault PIN')),
                subtitle: Text(tr('Locks the Finance tab')),
                onTap: () => _setPin(context, ref),
              ),
              if (hasPin)
                ListTile(
                  leading: const Icon(Icons.lock_open, color: AppColors.expense),
                  title: Text(tr('Remove PIN'), style: const TextStyle(color: AppColors.expense)),
                  onTap: () {
                    repo.pinHash = null;
                    ref.read(vaultProvider.notifier).unlock();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('Vault PIN removed'))));
                  },
                ),
            ])),
            Gap.l,
            SectionTitle(tr('Backup'), icon: Icons.cloud_upload_outlined, color: AppColors.savings),
            Card(child: Column(children: [
              ListTile(
                leading: const Icon(Icons.history, color: AppColors.savings),
                title: Text(tr('Tuition history (JSON)')),
                subtitle: Text(tr('All classes and payments per student: view, export, import')),
                onTap: () => context.push('/students/history'),
              ),
              ListTile(
                leading: const Icon(Icons.save_alt, color: AppColors.income),
                title: Text(tr('Save backup to device')),
                subtitle: Text(tr('All data as one JSON file, saved where you choose')),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final path = await saveBackupToDevice(ref.read(repoProvider));
                    messenger.showSnackBar(SnackBar(
                        content: Text(path == null ? tr('Save cancelled') : tr('Backup saved'))));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(tr("Couldn't save backup: {e}", {'e': e}))));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: AppColors.income),
                title: Text(tr('Share backup')),
                subtitle: Text(tr('Send the JSON file via WhatsApp, Google Drive, email…')),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await exportBackup(ref.read(repoProvider));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(tr("Couldn't share backup: {e}", {'e': e}))));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: AppColors.savings),
                title: Text(tr('Import backup')),
                subtitle: Text(tr('Restore all data from a backup file (replaces current data)')),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final go = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text(tr('Restore a backup?')),
                      content: Text(tr('This replaces everything in the app with the backup. '
                          'A safety copy of your current data is kept automatically.')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Choose file'))),
                      ],
                    ),
                  );
                  if (go != true) return;
                  try {
                    final ok = await importBackup(ref.read(repoProvider));
                    if (ok) reloadPreferences(ref);
                    messenger.showSnackBar(SnackBar(
                        content: Text(ok ? tr('Data imported. Restart the app to apply everything.') : tr('Import cancelled'))));
                  } on FormatException catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(e.message)));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(tr("Couldn't import: {e}", {'e': e}))));
                  }
                },
              ),
            ])),
            Gap.l,
            SectionTitle(tr('General'), icon: Icons.tune, color: AppColors.warning),
            Card(child: Column(children: [
              ValueListenableBuilder<VersionStatus>(
                valueListenable: versionStatus,
                builder: (context, v, _) => ListTile(
                  leading: Icon(Icons.system_update,
                      color: v.updateAvailable ? AppColors.income : AppColors.primary),
                  title: Text(v.updateAvailable ? tr('Update available') : tr('Check for updates')),
                  subtitle: Text(v.label.isEmpty ? tr('Download the latest version from GitHub') : v.label),
                  onTap: () => installLatestVersion(context),
                ),
              ),
              ValueListenableBuilder<VersionStatus>(
                valueListenable: versionStatus,
                builder: (context, v, _) => ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Life Tracker Pro'),
                  subtitle: Text(v.installed.isEmpty ? tr('Version —') : tr('Version {v}', {'v': v.installed})),
                ),
              ),
            ])),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- appearance

  Widget _appearanceCard(BuildContext context) {
    final look = ref.watch(appearanceProvider);
    final scale = _dragScale ?? look.textScale;
    final hint = Theme.of(context).hintColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(context, tr('Background')),
          // three fixed looks; each card is a small live preview of that background
          Row(children: [
            for (final o in bgOptions) ...[
              if (o != bgOptions.first) const SizedBox(width: 10),
              Expanded(child: _BgCard(
                option: o,
                selected: look.bg == o.id,
                onTap: () => ref.read(appearanceProvider.notifier).set(look.copyWith(bg: o.id)),
              )),
            ],
          ]),
          Gap.l,
          _BackgroundPreview(gradient: look.gradient, scale: scale),
          Gap.l,
          Row(children: [
            Expanded(child: _label(context, tr('Text size'))),
            Text('${(scale * 100).round()}%', style: TextStyle(color: hint, fontWeight: FontWeight.w600)),
          ]),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final st in textScaleSteps)
              ChoiceChip(
                showCheckmark: false,
                label: Text(tr(st.$1)),
                selected: (scale - st.$2).abs() < 0.001,
                onSelected: (_) => _setScale(st.$2),
              ),
          ]),
          Row(children: [
            Text('A', style: TextStyle(fontSize: 13, color: hint, fontWeight: FontWeight.w700)),
            Expanded(
              child: Slider(
                value: scale,
                min: minTextScale,
                max: maxTextScale,
                divisions: ((maxTextScale - minTextScale) / 0.05).round(),
                label: '${(scale * 100).round()}%',
                onChanged: (v) => setState(() => _dragScale = v),
                onChangeEnd: _setScale,
              ),
            ),
            Text('A', style: TextStyle(fontSize: 22, color: hint, fontWeight: FontWeight.w700)),
          ]),
          Text(tr("Applies to the whole app, on top of the phone's font size."),
              style: TextStyle(color: hint, fontSize: 12)),
        ]),
      ),
    );
  }

  void _setScale(double v) {
    final n = ref.read(appearanceProvider.notifier);
    n.set(ref.read(appearanceProvider).copyWith(textScale: double.parse(v.toStringAsFixed(2))));
    setState(() => _dragScale = null);
  }

  Widget _label(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
      );

  // ------------------------------------------------------------------ language

  Widget _languageCard(BuildContext context) {
    final lang = ref.watch(langProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(context, tr('App language')),
          Row(children: [
            for (final l in AppLang.values) ...[
              if (l != AppLang.values.first) Gap.m,
              Expanded(child: _LangTile(
                lang: l,
                selected: lang == l,
                onTap: () => ref.read(langProvider.notifier).set(l),
              )),
            ],
          ]),
          if (lang == AppLang.bn) ...[
            Gap.s,
            Text(tr('Some screens are still in English.'),
                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
          ],
        ]),
      ),
    );
  }

  // ----------------------------------------------------------------------- PIN

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Vault PIN')),
        content: TextField(
          controller: controller, autofocus: true, obscureText: true, obscuringCharacter: '*',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          decoration: InputDecoration(hintText: tr('Enter 4–6 digit PIN')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: Text(tr('Save'))),
        ],
      ),
    );
    if (pin != null && pin.length >= 4) {
      ref.read(repoProvider).setPin(pin);
      ref.read(vaultProvider.notifier).unlock();
      if (context.mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Vault PIN set'))));
      }
    }
  }
}

/// Mini mock-up of a screen on the chosen background, with sample text.
class _BackgroundPreview extends StatelessWidget {
  const _BackgroundPreview({required this.gradient, required this.scale});
  final Gradient gradient;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // The title sits on the background itself (the selected one = the current theme).
    final onBg = BgInk.of(context).text;
    final mq = MediaQuery.of(context);
    // The app-wide scale already applies; while dragging, preview the new one.
    final sys = mq.textScaler is AppTextScaler ? (mq.textScaler as AppTextScaler).system : mq.textScaler;
    return MediaQuery(
      data: mq.copyWith(textScaler: AppTextScaler(sys, scale)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outline.withValues(alpha: 0.6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(tr('Preview'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: onBg)),
            const Spacer(),
            Icon(Icons.more_horiz, color: onBg),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline),
            ),
            child: Row(children: [
              const IconBadge(icon: Icons.school, color: AppColors.primary, size: 34),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('This is how text will look.'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
                Text(tr('Today: 5 classes · ৳ 27,000 collected'),
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
              ])),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One of the three backgrounds as a tappable mini preview: the gradient with a
/// title in that background's own text colour and a small card in its theme.
class _BgCard extends StatelessWidget {
  const _BgCard({required this.option, required this.selected, required this.onTap});
  final BgOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = option.isDark;
    final ink = BgInk(dark: dark);
    final surface = dark ? AppColors.dSurface : AppColors.lSurface;
    final onSurface = dark ? AppColors.dOnBackground : AppColors.lOnBackground;
    final muted = dark ? AppColors.dMuted : AppColors.lMuted;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: tr(option.name),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            gradient: option.gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : cs.outline,
              width: selected ? 3 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 10)]
                : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(tr(option.name), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ink.text, fontWeight: FontWeight.w800, fontSize: 14))),
              if (selected)
                Container(
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
            ]),
            Text(tr(dark ? 'Dark' : 'Light'),
                style: TextStyle(color: ink.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aa', style: TextStyle(color: onSurface, fontWeight: FontWeight.w800, fontSize: 13)),
                Text('৳ 27,000', maxLines: 1,
                    style: TextStyle(color: muted, fontSize: 10.5)),
              ]),
            ),
            const SizedBox(height: 6),
            Text(tr('See all'), style: TextStyle(color: ink.link, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  const _LangTile({required this.lang, required this.selected, required this.onTap});
  final AppLang lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.16) : cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? AppColors.primary : cs.outline, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: lang == AppLang.bn ? AppColors.incomeGrad : AppColors.savingsGrad,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(lang == AppLang.bn ? 'অ' : 'A',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lang.nativeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(lang.otherName, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
            ])),
            if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ]),
        ),
      ),
    );
  }
}
