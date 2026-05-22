import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'data.dart';

/// Writes all app data to a JSON file and opens the share sheet
/// (so it can be saved to Google Drive, etc.). Returns the file name.
Future<String> exportBackup(Repo repo) async {
  final json = const JsonEncoder.withIndent('  ').convert(repo.exportAll());
  final dir = await getTemporaryDirectory();
  final name = 'life_tracker_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';
  final file = File('${dir.path}/$name');
  await file.writeAsString(json);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: 'Life Tracker Pro backup'),
  );
  return name;
}

/// Lets the user pick a backup JSON file and restores all data from it.
/// Returns true if data was imported.
Future<bool> importBackup(Repo repo) async {
  final res = await FilePicker.pickFiles(
    type: FileType.custom, allowedExtensions: ['json'],
  );
  final path = res?.files.single.path;
  if (path == null) return false;
  final content = await File(path).readAsString();
  final data = jsonDecode(content);
  if (data is! Map) return false;
  await repo.importAll(data);
  return true;
}
