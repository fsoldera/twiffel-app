import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AiClient {
  AiClient({http.Client? client, this.baseUrl = kApiBase})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  bool get isConfigured => baseUrl.isNotEmpty;

  Future<List<String>?> generateSteps(String task) async {
    if (!isConfigured) return null;
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/api/steps'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'task': task}),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final steps = (data['steps'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(growable: false);
      if (steps == null || steps.length != 3) return null;
      return steps;
    } catch (_) {
      return null;
    }
  }

  Future<String?> generateMessage({
    required String task,
    required String kind,
  }) async {
    if (!isConfigured) return null;
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/api/message'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'task': task, 'kind': kind}),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final message = data['message']?.toString();
      return (message == null || message.trim().isEmpty) ? null : message;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
