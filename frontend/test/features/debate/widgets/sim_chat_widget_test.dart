import 'dart:async';
import 'package:agents_council/app/theme.dart';
import 'package:agents_council/features/debate/widgets/sim_chat_widget.dart';
import 'package:agents_council/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'SimChatWidget renders agree (left) and disagree (right) correctly',
      (WidgetTester tester) async {
    // Setup data
    final agreeResponse = AgentResponse(
      agentId: '1',
      agentName: 'ProBot',
      role: RoleType.techStrategist,
      provider: ProviderType.openai,
      content: 'I agree with this.',
      vote: VoteType.agree,
      timestamp: DateTime.now(),
    );

    final disagreeResponse = AgentResponse(
      agentId: '2',
      agentName: 'ConBot',
      role: RoleType.devilsAdvocate,
      provider: ProviderType.anthropic,
      content: 'I disagree with this.',
      vote: VoteType.disagree,
      timestamp: DateTime.now(),
    );

    final streamController = StreamController<dynamic>();

    // Build widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SimChatWidget(
            debateId: 'test_debate',
            eventStream: streamController.stream,
            initialResponses: [agreeResponse, disagreeResponse],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Agree Response
    final agreeFinder = find.text('I agree with this.');
    expect(agreeFinder, findsOneWidget);

    // Find the Outer Row containing the Agree Avatar (computer icon)
    final agreeAvatarFinder = find.text('💻');
    final agreeOuterRowFinder = find
        .ancestor(
          of: agreeAvatarFinder,
          matching: find.byType(Row),
        )
        .first; // This should be the outer row because the avatar text is directly in a Container in the Row (well, Container -> Center -> Text)

    final agreeRowWidget = tester.widget<Row>(agreeOuterRowFinder);

    // Check alignment
    expect(agreeRowWidget.mainAxisAlignment, MainAxisAlignment.start);

    // Check children order: Avatar first
    // Child 0: Container (Avatar)
    // Child 1: SizedBox
    // Child 2: Flexible
    expect(agreeRowWidget.children.length, 3);
    expect(agreeRowWidget.children[0], isA<Container>());
    expect(agreeRowWidget.children[2], isA<Flexible>());

    // Verify Disagree Response
    final disagreeFinder = find.text('I disagree with this.');
    expect(disagreeFinder, findsOneWidget);

    // Find the Outer Row containing the Disagree Avatar (devil icon)
    final disagreeAvatarFinder = find.text('😈');
    final disagreeOuterRowFinder = find
        .ancestor(
          of: disagreeAvatarFinder,
          matching: find.byType(Row),
        )
        .first;

    final disagreeRowWidget = tester.widget<Row>(disagreeOuterRowFinder);

    // Check alignment
    expect(disagreeRowWidget.mainAxisAlignment, MainAxisAlignment.end);

    // Check children order: Avatar last
    // Child 0: Flexible
    // Child 1: SizedBox
    // Child 2: Container (Avatar)
    expect(disagreeRowWidget.children.length, 3);
    expect(disagreeRowWidget.children[0], isA<Flexible>());
    expect(disagreeRowWidget.children[2], isA<Container>());

    streamController.close();
  });
}
