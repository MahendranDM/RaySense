import 'package:flutter_test/flutter_test.dart';

import 'package:raysense_app/main.dart';

void main() {
  testWidgets('RaySense dashboard loads', (WidgetTester tester) async {
    await tester.pumpWidget(const RaySenseApp());

    expect(find.text('RaySense'), findsOneWidget);
    expect(find.text('Solar Dashboard'), findsOneWidget);
    expect(find.text("Today's Generation"), findsOneWidget);
  });
}