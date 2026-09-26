import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Register → Onboarding → Home → Create → Write → Inspiration → Save → Open.
/// Shared by the widget test (fake backend) and the on-device integration test.
Future<void> runCoreJourney(WidgetTester tester, {required String email, String password = 'correct-horse-9'}) async {
  Future<void> settle() => tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));

  // Welcome → Register
  expect(find.text('Begin'), findsOneWidget);
  await tester.tap(find.text('Begin'));
  await settle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Luna');
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password (8+ characters)'), password);
  await tester.tap(find.text('Create account'));
  await settle();

  // Onboarding: 3 story pages, environment, atmosphere
  expect(find.textContaining('Create what'), findsOneWidget);
  for (var i = 0; i < 3; i++) {
    await tester.tap(find.text('Continue'));
    await settle();
  }
  expect(find.text('What inspires you?'), findsOneWidget);
  await tester.tap(find.text('Ocean'));
  await settle();
  await tester.tap(find.text('Continue'));
  await settle();
  expect(find.text('How should it feel?'), findsOneWidget);
  await tester.tap(find.text('Enter my world'));
  await settle();

  // Home: personalised, empty state, no dashboard
  expect(find.textContaining('Luna'), findsWidgets);
  expect(find.text('Your story starts here.'), findsOneWidget);

  // Create → Writing
  await tester.tap(find.text('Create a Moment').first);
  await settle();
  expect(find.textContaining('creating?'), findsOneWidget);
  await tester.tap(find.text('Writing'));
  await settle();

  // Write
  await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Night walk');
  await tester.enterText(find.widgetWithText(TextField, 'Begin anywhere…'), 'The streetlights hum a slow song.');
  await tester.pump(const Duration(seconds: 3)); // let autosave debounce fire
  await settle();
  expect(find.text('Saved'), findsOneWidget);

  // Details: inspiration, mood, skip music + location, question, save
  await tester.tap(find.text('Continue'));
  await settle();
  expect(find.textContaining('inspiring'), findsOneWidget);
  await tester.tap(find.text('Moon'));
  await settle();
  await tester.tap(find.text('Continue'));
  await settle();
  await tester.tap(find.text('Peaceful'));
  await settle();
  await tester.tap(find.text('Continue'));
  await settle();
  await tester.tap(find.text('Skip')); // music
  await settle();
  await tester.tap(find.text('Skip')); // location
  await settle();
  expect(find.text('A thought to\nsit with'), findsOneWidget);
  await tester.tap(find.text('Skip')); // question
  await settle();
  await tester.tap(find.text('Save Moment'));
  await settle();

  // The new moment opens as an editorial page
  expect(find.text('Night walk'), findsWidgets);
  expect(find.text('Moon'), findsWidgets);
  expect(find.text('Peaceful'), findsWidgets);
}
