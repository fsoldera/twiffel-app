import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/decision_models.dart';

/// Result of a Worker analyze call.
class AnalyzeOutcome {
  const AnalyzeOutcome._({
    this.analysis,
    this.transportFailed = false,
    this.errorMessage,
  });

  factory AnalyzeOutcome.ok(DecisionAnalysis analysis) {
    return AnalyzeOutcome._(analysis: analysis);
  }

  /// Timeout, network, or 5xx. Caller may use local fallback.
  factory AnalyzeOutcome.transportFailed() {
    return const AnalyzeOutcome._(transportFailed: true);
  }

  /// 4xx or a 200 body that could not be parsed.
  factory AnalyzeOutcome.rejected([String? errorMessage]) {
    return AnalyzeOutcome._(errorMessage: errorMessage);
  }

  final DecisionAnalysis? analysis;
  final bool transportFailed;
  final String? errorMessage;
}

class AiClient {
  AiClient({http.Client? client, this.baseUrl = kApiBase})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  bool get isConfigured => baseUrl.isNotEmpty;

  Future<AnalyzeOutcome> analyze(DecisionRequest request) async {
    if (!isConfigured) return AnalyzeOutcome.transportFailed();
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/api/analyze'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 65));
      if (res.statusCode >= 500) return AnalyzeOutcome.transportFailed();
      if (res.statusCode != 200) {
        return AnalyzeOutcome.rejected(_errorMessageFromBody(res.body));
      }
      final data = jsonDecode(res.body);
      if (data is! Map) return AnalyzeOutcome.rejected();
      final parsed = DecisionAnalysis.fromJson(
        Map<String, dynamic>.from(unwrapAnalysisMap(data)),
      );
      if (parsed.verdictPoints.isEmpty) return AnalyzeOutcome.rejected();
      return AnalyzeOutcome.ok(parsed);
    } catch (error, stack) {
      debugPrint('AiClient.analyze failed: $error\n$stack');
      return AnalyzeOutcome.transportFailed();
    }
  }

  void dispose() => _client.close();
}

String? _errorMessageFromBody(String body) {
  try {
    final data = jsonDecode(body);
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
  } catch (_) {
    // Ignore malformed error bodies.
  }
  return null;
}
