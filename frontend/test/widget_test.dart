// Basic widget test for AgentsCouncil

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agents_council/main.dart';

void main() {
  testWidgets('App should load and show login or home screen',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: AgentsCouncilApp()));

    // Wait for async initialization
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify that either login screen or home screen title is shown
    // Login screen has "AgentsCouncil" text, home screen also has "AgentsCouncil"
    expect(find.text('AgentsCouncil'), findsWidgets);
  });
}
