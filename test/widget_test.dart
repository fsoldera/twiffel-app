import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:twiffel_app/src/app.dart';

void main() {
  testWidgets('MyApp smoke test', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.text('Twiffel'), findsOneWidget);
    expect(find.text('Template home screen'), findsOneWidget);
  });
}
