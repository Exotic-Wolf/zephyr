import 'package:flutter_test/flutter_test.dart';

import 'package:zephyr_mobile/main.dart';

void main() {
  testWidgets('Onboarding screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Zephyr Onboarding'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
    expect(find.text('Display Name'), findsOneWidget);
  });
}
