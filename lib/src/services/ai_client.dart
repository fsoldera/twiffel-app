import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/decision_models.dart';

class AiClient {
  AiClient({http.Client? client, this.baseUrl = kApiBase})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  bool get isConfigured => baseUrl.isNotEmpty;

  Future<DecisionAnalysis?> analyze(DecisionRequest request) async {
    if (!isConfigured) return null;
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/api/analyze'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final analysis = data['analysis'];
      if (analysis is! Map) return null;
      final parsed =
          DecisionAnalysis.fromJson(Map<String, dynamic>.from(analysis));
      if (parsed.verdict.trim().isEmpty) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
