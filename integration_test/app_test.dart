// Runs the core user journey on a device or simulator:
//   flutter test integration_test                         (in-memory fake backend)
//   flutter test integration_test --dart-define-from-file=.env --dart-define=REAL_BACKEND=true
// The real-backend run creates a fresh account per run and requires that email
// confirmation is disabled on the Supabase project (see README).
import 'package:creative_moments/app.dart';
import 'package:creative_moments/core/services/config.dart';
import 'package:creative_moments/dev/fake_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test/support/journey.dart';

const _real = bool.fromEnvironment('REAL_BACKEND');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('core journey', (tester) async {
    // Scenes animate forever, which pumpAndSettle cannot wait out: run the journey with Reduce Motion.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final email = 'journey+${DateTime.now().millisecondsSinceEpoch}@example.com';
    if (_real) {
      expect(AppConfig.isConfigured, isTrue, reason: 'pass --dart-define-from-file=.env');
      await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
      await tester.pumpWidget(const ProviderScope(child: CreativeMomentsApp()));
    } else {
      await tester.pumpWidget(ProviderScope(overrides: FakeBackend().overrides, child: const CreativeMomentsApp()));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
    await runCoreJourney(tester, email: email);
  });
}
