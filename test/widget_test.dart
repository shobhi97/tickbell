// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tickbell/app.dart';
import 'package:tickbell/core/router/app_router.dart';

void main() {
  testWidgets('app shell builds', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Scaffold(body: SizedBox.shrink())),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWithValue(router)],
        child: const TickBellApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
