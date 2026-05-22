import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup.dart';
import '../../core/providers.dart';
import '../../core/updater.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../finance/finance_screen.dart' show hashPin;

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
                leading: const Icon(Icons.upload_file, color: AppColors.income),
                title: const Text('Export backup'),
                subtitle: const Text('Save all data to a file (upload to Google Drive)'),
                onTap: () async {
                  await exportBackup(ref.read(repoProvider));
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: AppColors.savings),
                title: const Text('Import backup'),
                subtitle: const Text('Restore all data from a backup file'),
                onTap: () async {
                  final ok = await importBackup(ref.read(repoProvider));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'Data imported. Restart the app to apply everything.' : 'Import cancelled')));
                  }
                },
              ),
            ])),
            Gap.l,
            const SectionTitle('General'),
            Card(child: Column(children: [
              ListTile(
                leading: const Icon(Icons.system_update, color: AppColors.primary),
                title: const Text('Check for updates'),
                subtitle: const Text('Download the latest version from GitHub'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Checking for updates…')));
                  runUpdateCheck(context);
                },
              ),
              const ListTile(leading: Icon(Icons.language), title: Text('Language'), subtitle: Text('English (বাংলা coming soon)')),
              const ListTile(leading: Icon(Icons.info_outline), title: Text('Life Tracker Pro'), subtitle: Text('Version 1.0.0')),
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
      ref.read(repoProvider).pinHash = hashPin(pin);
      ref.read(vaultProvider.notifier).unlock();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vault PIN set')));
      }
    }
  }
}
