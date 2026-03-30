import 'package:flutter_test/flutter_test.dart';

import 'package:fitgo/app.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FitGoApp());
    expect(find.text('FitGo'), findsOneWidget);
  });
}
