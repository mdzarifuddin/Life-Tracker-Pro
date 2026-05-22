import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Repo.init();
  runApp(const ProviderScope(child: MentoraApp()));
}
