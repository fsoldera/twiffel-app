import 'dart:io';

import 'package:flutter/services.dart';

/// Hides the Android navigation bar (back/home/recents) in immersive sticky mode.
Future<void> hideAndroidNavigationBar() async {
  if (!Platform.isAndroid) return;
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}
