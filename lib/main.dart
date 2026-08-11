import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'src/app.dart';
import 'src/copy/loading_response_texts.dart';
import 'src/services/android_system_ui.dart';

Future<void> main() async {
  appLaunchAt = DateTime.now();
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the native launch plate until Flutter is ready and the min duration elapses.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await LoadingResponseTexts.load();
  runApp(const MyApp());
  // Apply immersive mode after the first frame so Android does not report a
  // 0×0 Flutter viewport (black screen) during cold start on some emulators.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(hideAndroidNavigationBar());
  });
}
