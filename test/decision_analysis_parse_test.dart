import 'dart:async';
import 'dart:convert';

import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:twiffel_app/src/config/app_config.dart';
import 'package:twiffel_app/src/models/decision_models.dart';
import 'package:twiffel_app/src/services/ai_client.dart';
import 'package:twiffel_app/src/state/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fromJson keeps comparison points and object verdict items', () {
    final analysis = DecisionAnalysis.fromJson(
      unwrapAnalysisMap(<String, dynamic>{
        'analysis': <String, dynamic>{
          'mode': 'comparison',
          'optionA': 'buy a snake',
          'optionB': 'buy a bike',
          'optionAPros': [
            <String, Object>{
              'tagline': 'Habitat fit',
              'description':
                  'A snake needs far less outdoor space than a bike commute.',
              'weight': 84,
            },
          ],
          'verdict': [
            <String, String>{'sentence': 'The snake is the lighter lift this month.'},
            'Keep the bike if daily movement is the real goal.',
          ],
        },
      }),
    );

    expect(analysis.optionAPros.single.tagline, 'Habitat fit');
    expect(analysis.optionAPros.single.description,
        'A snake needs far less outdoor space than a bike commute.');
    expect(analysis.optionAPros.single.weight, 84);
    expect(analysis.verdictPoints, [
      'The snake is the lighter lift this month.',
      'Keep the bike if daily movement is the real goal.',
    ]);
  });

  test('fromJson requires tagline, description, and weight, then sorts by weight',
      () {
    final analysis = DecisionAnalysis.fromJson(
      <String, dynamic>{
        'mode': 'comparison',
        'optionA': 'Stay',
        'optionB': 'Go',
        'optionAPros': [
          <String, Object>{
            'tagline': 'Low',
            'description': 'A weak point.',
            'weight': 20,
          },
          <String, Object>{
            'tagline': 'High',
            'description': 'A strong point.',
            'weight': 90,
          },
          <String, String>{
            'tagline': 'Missing weight',
            'description': 'This point is dropped.',
          },
        ],
        'verdict': <String>['Lean yes.'],
      },
    );

    expect(analysis.optionAPros.map((point) => point.tagline), ['High', 'Low']);
    expect(analysis.optionAPros.first.weight, 90);
  });

  test('AiClient returns parsed analysis from HTTP 200', () async {
    final client = AiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'analysis': <String, dynamic>{
              'mode': 'comparison',
              'optionA': 'buy a snake',
              'optionB': 'buy a bike',
              'optionAPros': [
                <String, Object>{
                  'tagline': 'Habitat fit',
                  'description': 'Less space than a bike.',
                  'weight': 84,
                },
              ],
              'verdict': <String>[
                'Lean snake if space is the blocker.',
                'Lean bike if movement is the goal.',
              ],
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final outcome = await client.analyze(
      const DecisionRequest(
        optionA: 'buy a snake',
        optionB: 'buy a bike',
        obstacle: 'Space',
        timing: 'Soon',
      ),
    );

    expect(outcome.analysis, isNotNull);
    expect(outcome.analysis!.verdictPoints.first, contains('Lean snake'));
    expect(outcome.analysis!.optionAPros.single.tagline, 'Habitat fit');
    expect(outcome.analysis!.optionAPros.single.weight, 84);
  });

  test('timeout uses local fallback instead of the error screen', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final license = LicenseController(appLicenseConfig);
    await license.init();
    final session = SessionController(
      license: license,
      ai: AiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          throw TimeoutException('timed out');
        }),
      ),
    );

    await session.submitDecision(
      const DecisionRequest(
        optionA: 'buy a snake',
        optionB: 'buy a bike',
        obstacle: 'Space',
        timing: 'Soon',
      ),
    );

    expect(session.phase, SessionPhase.ready);
    expect(session.analysis, isNotNull);
    expect(session.analysis!.optionAPros.first.tagline, 'Forward movement');
    expect(session.analysis!.optionAPros.first.weight, 78);
  });

  test('HTTP 400 does not use canned fallback copy', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final license = LicenseController(appLicenseConfig);
    await license.init();
    final session = SessionController(
      license: license,
      ai: AiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          return http.Response('{"error":"Invalid decision payload"}', 400);
        }),
      ),
    );

    await session.submitDecision(
      const DecisionRequest(
        optionA: 'buy a snake',
        optionB: 'buy a bike',
        obstacle: 'Space',
        timing: 'Soon',
      ),
    );

    expect(session.phase, SessionPhase.error);
    expect(session.analysis, isNull);
    expect(session.inputError, 'Invalid decision payload');
  });
}
