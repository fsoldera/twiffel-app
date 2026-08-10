import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'src/app.dart';
import 'src/copy/loading_response_texts.dart';

Future<void> main() async {
  appLaunchAt = DateTime.now();
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the native launch plate until Flutter is ready and the min duration elapses.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await LoadingResponseTexts.load();
  runApp(const MyApp());
}
