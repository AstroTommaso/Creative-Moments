import 'package:creative_moments/app.dart';
import 'package:creative_moments/core/theme/typography.dart';
import 'package:creative_moments/data/models/preferences.dart';
import 'package:creative_moments/dev/fake_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A signed-in, onboarded fake account with reduce-motion on so scenes are
/// static and `pumpAndSettle` can finish.
FakeBackend signedInBackend({bool seed = false, bool onboarded = true, bool signedIn = true}) {
  final b = FakeBackend()..createDemoAccount(onboarded: onboarded);
  const email = 'demo@creative.moments';
  final id = b.users[email]!.id;
  b.prefs[id] = UserPreferences(onboarded: onboarded, reduceMotion: true, environments: const ['moon', 'stars']);
  if (!seed) b.moments.clear();
  if (signedIn) b.currentEmail = email;
  return b;
}

void useSystemFontsForTests() {
  AppType.systemFonts = true;
}

Future<void> pumpApp(WidgetTester tester, FakeBackend backend, {Size size = const Size(390, 844)}) async {
  useSystemFontsForTests();
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // OS-level Reduce Motion: scenes render still, so pumpAndSettle can finish.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(ProviderScope(retry: (_, _) => null, overrides: backend.overrides, child: const CreativeMomentsApp()));
  await tester.pumpAndSettle();
}
