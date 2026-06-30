import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class Analytics {
  Analytics({http.Client? client, this.baseUrl = kApiBase})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  String get _platform {
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      return 'other';
    } catch (_) {
      return 'other';
    }
  }

  void track(String event) {
    if (baseUrl.isEmpty) return;
    () async {
      try {
        await _client
            .post(
              Uri.parse('$baseUrl/api/track'),
              headers: const {'content-type': 'application/json'},
              body: jsonEncode({'event': event, 'platform': _platform}),
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }();
  }
}
