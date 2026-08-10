import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'src/app.dart';
import 'src/copy/loading_response_texts.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the static stacked-logo launch plate until the first Flutter frame.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await LoadingResponseTexts.load();
  runApp(const MyApp());
}
