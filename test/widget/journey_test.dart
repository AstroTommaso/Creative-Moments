import 'package:creative_moments/dev/fake_backend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';
import '../support/journey.dart';

void main() {
  testWidgets('core journey: register → onboarding → home → create → write → inspire → save → open', (tester) async {
    final backend = FakeBackend();
    await pumpApp(tester, backend);
    await runCoreJourney(tester, email: 'luna@example.com');
    // persisted in the (fake) backend, with its details
    expect(backend.moments.length, 1);
    final m = backend.moments.values.single;
    expect(m.title, 'Night walk');
    expect(m.text, 'The streetlights hum a slow song.');
    expect(m.inspirations.map((e) => e.type), ['moon']);
    expect(m.mood, 'peaceful');
  });
}
