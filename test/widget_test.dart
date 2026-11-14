import 'package:fitgo/screens/auth_screen.dart';
import 'package:fitgo/ui/components/fitgo_card.dart';
import 'package:fitgo/ui/components/fitgo_ring.dart';
import 'package:fitgo/ui/theme/fitgo_theme.dart';
import 'package:fitgo/ui/theme/fitgo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FitGoCard renders child content and uses tokens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FitGoTheme.light,
        home: const Scaffold(body: FitGoCard(child: Text('Calories left'))),
      ),
    );

    expect(find.text('Calories left'), findsOneWidget);

    final context = tester.element(find.byType(FitGoCard));
    expect(context.tokens.surface, FitGoTokens.light.surface);
    expect(context.tokens.cardRadius, 20);
  });

  testWidgets('FitGoRing exposes progress semantics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FitGoTheme.dark,
        home: const Scaffold(
          body: Center(
            child: FitGoRing(
              progress: 0.62,
              semanticLabel: 'Calories',
              child: Text('62%'),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Calories',
      ),
      findsOneWidget,
    );
    expect(find.text('62%'), findsOneWidget);
  });

  testWidgets('Auth screen reveals the email form on demand', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: FitGoTheme.light, home: const AuthScreen()),
    );

    expect(find.text('Your day, in balance.'), findsOneWidget);
    expect(find.text('Continue without an account'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Email'), findsNothing);

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
