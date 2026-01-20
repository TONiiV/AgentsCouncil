// Basic widget test for AgentsCouncil

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agents_council/main.dart';

void main() {
  testWidgets('App should load home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: AgentsCouncilApp()));

    // Verify that app title is shown
    expect(find.text('AgentsCouncil'), findsOneWidget);
  });
}
