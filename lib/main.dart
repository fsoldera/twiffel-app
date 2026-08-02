import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'src/app.dart';

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the static stacked-logo launch plate until the first Flutter frame.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const MyApp());
}
