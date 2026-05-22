import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// GitHub repo that hosts the releases (APK attached to each release).
const _repo = 'mdzarifuddin/Life-Tracker-Pro';

class UpdateInfo {
  final String version, url, notes;
  UpdateInfo({required this.version, required this.url, required this.notes});
}

int _verCode(String v) {
  final cleaned = v.replaceAll(RegExp(r'[^0-9.]'), '');
  final nums = [for (final p in cleaned.split('.')) int.tryParse(p) ?? 0];
  while (nums.length < 3) {
    nums.add(0);
  }
  return nums[0] * 1000000 + nums[1] * 1000 + nums[2];
}

/// Returns update info if the latest GitHub release is newer than the installed build.
Future<UpdateInfo?> checkForUpdate() async {
  try {
    final pkg = await PackageInfo.fromPlatform();
    final res = await http.get(
      Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] ?? '').toString();
    if (tag.isEmpty || _verCode(tag) <= _verCode(pkg.version)) return null;
    String? apk;
    for (final a in (json['assets'] as List? ?? const [])) {
      if ((a['name'] ?? '').toString().toLowerCase().endsWith('.apk')) {
        apk = (a['browser_download_url'] ?? '').toString();
        break;
      }
    }
    if (apk == null || apk.isEmpty) return null;
    return UpdateInfo(version: tag, url: apk, notes: (json['body'] ?? '').toString());
  } catch (_) {
    return null;
  }
}

/// Downloads the APK (0..1 progress) and opens the system installer.
/// Because the applicationId is unchanged, installing over the app keeps all data.
Future<void> downloadAndInstall(UpdateInfo info, void Function(double) onProgress) async {
  final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
  final file = File('${dir.path}/life_tracker_pro_${info.version}.apk');
  final client = http.Client();
  try {
    final resp = await client.send(http.Request('GET', Uri.parse(info.url)));
    final total = resp.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    await for (final chunk in resp.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress(received / total);
    }
    await sink.close();
  } finally {
    client.close();
  }
  await OpenFilex.open(file.path);
}

bool _autoChecked = false;

/// Runs an auto-check once per app launch (silent if already up to date).
void autoUpdateOnce(BuildContext context) {
  if (_autoChecked) return;
  _autoChecked = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) runUpdateCheck(context, silent: true);
  });
}

/// Checks for an update and, if found, prompts to download + install.
Future<void> runUpdateCheck(BuildContext context, {bool silent = false}) async {
  final info = await checkForUpdate();
  if (!context.mounted) return;
  if (info == null) {
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're on the latest version.")));
    }
    return;
  }
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Update available · ${info.version}'),
      content: Text(info.notes.trim().isEmpty
          ? 'A new version is available. Update now? Your data stays safe.'
          : info.notes.trim()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
        FilledButton(
          onPressed: () { Navigator.pop(ctx); _startDownload(context, info); },
          child: const Text('Update'),
        ),
      ],
    ),
  );
}

void _startDownload(BuildContext context, UpdateInfo info) {
  final progress = ValueNotifier<double>(0);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Downloading update…'),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, v, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(value: v == 0 ? null : v),
          const SizedBox(height: 12),
          Text('${(v * 100).toStringAsFixed(0)}%'),
        ]),
      ),
    ),
  );
  downloadAndInstall(info, (v) => progress.value = v).then((_) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }).catchError((Object e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')));
    }
  });
}
