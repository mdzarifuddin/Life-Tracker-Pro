import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'data.dart';

String _backupName() =>
    'life_tracker_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';

String _backupJson(Repo repo) =>
    const JsonEncoder.withIndent('  ').convert(repo.exportAll());

/// Writes all app data to a JSON file and opens the share sheet
/// (WhatsApp, Google Drive, email…). Returns the file name.
Future<String> exportBackup(Repo repo) async {
  final dir = await getTemporaryDirectory();
  final name = _backupName();
  final file = File('${dir.path}/$name');
  await file.writeAsString(_backupJson(repo));
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: 'Life Tracker Pro backup'),
  );
  return name;
}

/// Lets the user choose where to save the backup JSON on the device.
/// Returns the saved path, or null if cancelled.
Future<String?> saveBackupToDevice(Repo repo) async {
  final bytes = utf8.encode(_backupJson(repo));
  return FilePicker.saveFile(
    dialogTitle: 'Save backup',
    fileName: _backupName(),
    type: FileType.custom,
    allowedExtensions: ['json'],
    bytes: Uint8List.fromList(bytes),
  );
}

/// Lets the user pick a backup JSON file and restores all data from it.
/// Returns true if data was imported, false if cancelled. Throws a
/// [FormatException] (readable message) for a wrong or damaged file.
/// A safety copy of the current data is kept first (see [lastSafetyBackup]).
Future<bool> importBackup(Repo repo) async {
  final res = await FilePicker.pickFiles(
    type: FileType.custom, allowedExtensions: ['json'],
  );
  final path = res?.files.single.path;
  if (path == null) return false;
  final Object? data;
  try {
    data = jsonDecode(await File(path).readAsString());
  } on FormatException {
    throw const FormatException('This file is not valid JSON.');
  }
  if (data is! Map) throw const FormatException('This is not a Life Tracker Pro backup file.');
  Repo.validateBackup(data);
  final dir = await getApplicationDocumentsDirectory();
  await File('${dir.path}/before_restore_backup.json').writeAsString(_backupJson(repo));
  await repo.importAll(data);
  return true;
}

/// The automatic copy made just before the last restore (null if none).
Future<File?> lastSafetyBackup() async {
  final dir = await getApplicationDocumentsDirectory();
  final f = File('${dir.path}/before_restore_backup.json');
  return await f.exists() ? f : null;
}
