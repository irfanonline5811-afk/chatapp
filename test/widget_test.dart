import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chatapp1/home_screen.dart';

void main() {
  testWidgets('NewChatDialog smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NewChatDialog(initialIsGroup: false),
        ),
      ),
    );

    expect(find.text('New Chat'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Group Chat'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
  });

  testWidgets('NewStatusDialog smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NewStatusDialog(),
        ),
      ),
    );

    expect(find.text('Add Text Status'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Post'), findsOneWidget);
  });
}
