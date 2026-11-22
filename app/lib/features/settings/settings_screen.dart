import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backup.dart';
import '../../core/providers.dart';
import '../../core/updater.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repoProvider);
    final mode = ref.watch(themeModeProvider);
    final hasPin = repo.pinHash != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle('Appearance'),
            Card(child: RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (v) {
                if (v != null) ref.read(themeModeProvider.notifier).set(v);
              },
              child: const Column(children: [
                RadioListTile<ThemeMode>(value: ThemeMode.dark, title: Text('Dark (default)')),
                RadioListTile<ThemeMode>(value: ThemeMode.light, title: Text('Light')),
                RadioListTile<ThemeMode>(value: ThemeMode.system, title: Text('Follow system')),
              ]),
            )),
            Gap.l,
            const SectionTitle('Security'),
            Card(child: Column(children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(hasPin ? 'Change Vault PIN' : 'Set Vault PIN'),
                subtitle: const Text('Locks the Finance tab'),
                onTap: () => _setPin(context, ref),
              ),
              if (hasPin)
                ListTile(
                  leading: const Icon(Icons.lock_open, color: AppColors.expense),
                  title: const Text('Remove PIN', style: TextStyle(color: AppColors.expense)),
                  onTap: () {
                    repo.pinHash = null;
                    ref.read(vaultProvider.notifier).unlock();
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vault PIN removed')));
                  },
                ),
            ])),
            Gap.l,
            const SectionTitle('Backup'),
            Card(child: Column(children: [
              ListTile(
                leading: const Icon(Icons.history, color: AppColors.savings),
                title: const Text('Tuition history (JSON)'),
                subtitle: const Text('All classes and payments per student: view, export, import'),
                onTap: () => context.go('/more/history'),
              ),
              ListTile(
                leading: const Icon(Icons.save_alt, color: AppColors.income),
                title: const Text('Save backup to device'),
                subtitle: const Text('All data as one JSON file, saved where you choose'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final path = await saveBackupToDevice(ref.read(repoProvider));
                    messenger.showSnackBar(SnackBar(
                        content: Text(path == null ? 'Save cancelled' : 'Backup saved')));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text("Couldn't save backup: $e")));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: AppColors.income),
                title: const Text('Share backup'),
                subtitle: const Text('Send the JSON file via WhatsApp, Google Drive, email…'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await exportBackup(ref.read(repoProvider));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text("Couldn't share backup: $e")));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: AppColors.savings),
                title: const Text('Import backup'),
                subtitle: const Text('Restore all data from a backup file (replaces current data)'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final go = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Restore a backup?'),
                      content: const Text('This replaces everything in the app with the backup. '
                          'A safety copy of your current data is kept automatically.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Choose file')),
                      ],
                    ),
                  );
                  if (go != true) return;
                  try {
                    final ok = await importBackup(ref.read(repoProvider));
                    messenger.showSnackBar(SnackBar(
                        content: Text(ok ? 'Data imported. Restart the app to apply everything.' : 'Import cancelled')));
                  } on FormatException catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(e.message)));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text("Couldn't import: $e")));
                  }
                },
              ),
            ])),
            Gap.l,
            const SectionTitle('General'),
            Card(child: Column(children: [
              ValueListenableBuilder<VersionStatus>(
                valueListenable: versionStatus,
                builder: (context, v, _) => ListTile(
                  leading: Icon(Icons.system_update,
                      color: v.updateAvailable ? AppColors.income : AppColors.primary),
                  title: Text(v.updateAvailable ? 'Update available' : 'Check for updates'),
                  subtitle: Text(v.label.isEmpty ? 'Download the latest version from GitHub' : v.label),
                  onTap: () => installLatestVersion(context),
                ),
              ),
              const ListTile(leading: Icon(Icons.language), title: Text('Language'), subtitle: Text('English (বাংলা coming soon)')),
              ValueListenableBuilder<VersionStatus>(
                valueListenable: versionStatus,
                builder: (context, v, _) => ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Life Tracker Pro'),
                  subtitle: Text(v.installed.isEmpty ? 'Version —' : 'Version ${v.installed}'),
                ),
              ),
            ])),
          ],
        ),
      ),
    );
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Vault PIN'),
        content: TextField(
          controller: controller, autofocus: true, obscureText: true, obscuringCharacter: '*',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'Enter 4–6 digit PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (pin != null && pin.length >= 4) {
      ref.read(repoProvider).setPin(pin);
      ref.read(vaultProvider.notifier).unlock();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vault PIN set')));
      }
    }
  }
}
