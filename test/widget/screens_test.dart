import 'dart:ui' show Tristate;

import 'package:creative_moments/core/constants/catalog.dart';
import 'package:creative_moments/core/theme/app_theme.dart';
import 'package:creative_moments/core/theme/tokens.dart';
import 'package:creative_moments/core/theme/typography.dart';
import 'package:creative_moments/data/providers.dart';
import 'package:creative_moments/dev/fake_backend.dart';
import 'package:creative_moments/features/creation/create_type_screen.dart';
import 'package:creative_moments/features/creation/details_screen.dart';
import 'package:creative_moments/features/creation/draft.dart';
import 'package:creative_moments/features/creation/editor_screen.dart';
import 'package:creative_moments/features/home/home_screen.dart';
import 'package:creative_moments/features/moments/moment_detail_screen.dart';
import 'package:creative_moments/shared/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/harness.dart';

/// Mounts a single screen (real theme, fake data, real GoRouter) on top of a
/// blank home route so push/pop behave exactly as in the app.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  FakeBackend backend,
  Widget screen, {
  void Function(ProviderContainer c)? before,
  Size size = const Size(390, 844),
}) async {
  AppType.systemFonts = true;
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME ROUTE')),
      ),
      GoRoute(path: '/screen', builder: (_, _) => screen),
      GoRoute(path: '/create', builder: (_, _) => const Text('CREATE ROUTE')),
      GoRoute(path: '/create/edit', builder: (_, _) => const Text('EDIT ROUTE')),
      GoRoute(path: '/create/details', builder: (_, _) => const Text('DETAILS ROUTE')),
      GoRoute(path: '/create/draw', builder: (_, _) => const Text('DRAW ROUTE')),
      GoRoute(path: '/customize', builder: (_, _) => const Text('CUSTOMIZE ROUTE')),
      GoRoute(path: '/moment/:id', builder: (_, s) => Text('MOMENT ${s.pathParameters['id']}')),
    ],
  );
  final container = ProviderContainer(retry: (_, _) => null, overrides: backend.overrides);
  addTearDown(container.dispose);
  container.listen(sessionUserProvider, (_, _) {});
  before?.call(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.build(CmColors.dark),
        darkTheme: AppTheme.build(CmColors.dark),
        themeMode: ThemeMode.dark,
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/screen');
  await tester.pumpAndSettle();
  return container;
}

Future<void> tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
}

/// Lets any debounced autosave fire so no timer outlives the test.
Future<void> flush(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  group('Home', () {
    testWidgets('greets the person, asks the question and offers to create — no dashboard', (tester) async {
      await pumpScreen(tester, signedInBackend(), const HomeScreen());
      expect(find.textContaining('Astro'), findsOneWidget);
      expect(find.text('Create a Moment'), findsWidgets);
      // The exact wording depends on the real time of day (see promptForHour);
      // check for whatever it actually is right now instead of a substring
      // that only some of its variants contain.
      expect(find.text(promptForHour(DateTime.now().hour)), findsOneWidget);
      expect(find.text('Your recent moments'), findsOneWidget);
    });

    testWidgets('empty state invites the first moment', (tester) async {
      // Taller viewport: the greeting/prompt above this section wraps to a
      // different number of lines depending on the real time of day, which
      // would otherwise sometimes push this content below the fold.
      await pumpScreen(tester, signedInBackend(), const HomeScreen(), size: const Size(390, 1400));
      expect(find.text('Your story starts here.'), findsOneWidget);
      expect(find.text('Create something worth remembering.'), findsOneWidget);
    });

    testWidgets('shows recent moments as visual cards and opens one', (tester) async {
      final b = signedInBackend(seed: true);
      await pumpScreen(tester, b, const HomeScreen(), size: const Size(390, 1400));
      expect(find.text('Loneliness, but peaceful'), findsOneWidget);
      expect(find.text('Rain on the window'), findsOneWidget);
      expect(find.text('Your story starts here.'), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Loneliness, but peaceful'));
      await tester.pumpAndSettle();
      expect(find.textContaining('MOMENT '), findsOneWidget);
    });

    testWidgets('gives every recent moment a tappable star in the sky', (tester) async {
      await pumpScreen(tester, signedInBackend(seed: true), const HomeScreen());
      expect(find.bySemanticsLabel(RegExp('Open moment: ')), findsAtLeastNWidgets(3));
    });

    testWidgets('a loading failure is friendly and can be retried', (tester) async {
      final b = signedInBackend(seed: true);
      b.offline = true;
      final c = await pumpScreen(tester, b, const HomeScreen());
      await tester.scrollUntilVisible(find.text('Try Again'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('offline'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      b.offline = false;
      await tapVisible(tester, find.text('Try Again'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Loneliness, but peaceful'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Loneliness, but peaceful'), findsOneWidget);
      expect(c.read(momentsProvider).hasError, isFalse);
    });
  });

  group('Create Moment', () {
    testWidgets('offers every creation type plus "I don\'t know yet"', (tester) async {
      await pumpScreen(tester, signedInBackend(), const CreateTypeScreen());
      for (final t in CreationType.selectable) {
        expect(find.text(t.label), findsOneWidget, reason: t.label);
      }
      expect(find.text('What are you\ncreating?'), findsOneWidget);
      expect(find.text("I don't know yet"), findsOneWidget);
    });

    testWidgets('choosing a type starts a draft of that type and opens the editor', (tester) async {
      final c = await pumpScreen(tester, signedInBackend(), const CreateTypeScreen());
      await tester.tap(find.text('Story'));
      await tester.pumpAndSettle();
      expect(c.read(draftProvider).type, CreationType.story);
      expect(c.read(draftProvider).active, isTrue);
      expect(find.text('EDIT ROUTE'), findsOneWidget);
    });

    testWidgets('"I don\'t know yet" starts a freeform moment without further decisions', (tester) async {
      final c = await pumpScreen(tester, signedInBackend(), const CreateTypeScreen());
      await tester.tap(find.text("I don't know yet"));
      await tester.pumpAndSettle();
      expect(c.read(draftProvider).type, CreationType.freeform);
    });

    testWidgets('can be dismissed without starting anything', (tester) async {
      final c = await pumpScreen(tester, signedInBackend(), const CreateTypeScreen());
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('HOME ROUTE'), findsOneWidget);
      expect(c.read(draftProvider).active, isFalse);
    });
  });

  group('Writing', () {
    Future<ProviderContainer> writing(WidgetTester tester, FakeBackend b, {CreationType type = CreationType.writing}) =>
        pumpScreen(tester, b, const EditorScreen(), before: (c) => c.read(draftProvider.notifier).start(type));

    testWidgets('has a title, a body, undo/redo, focus mode and a word count', (tester) async {
      await writing(tester, signedInBackend());
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Begin anywhere…'), findsOneWidget);
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(find.byTooltip('Redo'), findsOneWidget);
      expect(find.byTooltip('Focus mode'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);
    });

    testWidgets('typing autosaves after a pause and then says Saved — not before', (tester) async {
      final b = signedInBackend();
      final c = await writing(tester, b);
      await tester.enterText(find.widgetWithText(TextField, 'Begin anywhere…'), 'A line of a poem');
      await tester.pump();
      expect(find.text('Not saved yet'), findsOneWidget);
      expect(b.moments, isEmpty); // debounced: nothing sent per keystroke
      await flush(tester);
      expect(find.text('Saved'), findsOneWidget);
      expect(b.moments.length, 1);
      expect(c.read(draftProvider).status, SaveStatus.saved);
    });

    testWidgets('many keystrokes make one save, not one per keystroke', (tester) async {
      final b = signedInBackend();
      await writing(tester, b);
      final field = find.widgetWithText(TextField, 'Begin anywhere…');
      for (final t in ['H', 'He', 'Hel', 'Hell', 'Hello']) {
        await tester.enterText(field, t);
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(b.moments, isEmpty);
      await flush(tester);
      expect(b.moments.values.single.text, 'Hello');
    });

    testWidgets('when saving fails it says so honestly and offers a retry', (tester) async {
      final b = signedInBackend();
      await writing(tester, b);
      b.offline = true;
      await tester.enterText(find.widgetWithText(TextField, 'Begin anywhere…'), 'words');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('Not saved · tap to retry'), findsOneWidget);
      expect(find.text('Saved'), findsNothing);
      b.offline = false;
      await tester.tap(find.text('Not saved · tap to retry'));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(b.moments.length, 1);
    });

    testWidgets('leaving with unsaved words asks first', (tester) async {
      final b = signedInBackend();
      final c = await writing(tester, b);
      b.offline = true;
      await tester.enterText(find.widgetWithText(TextField, 'Begin anywhere…'), 'unsent');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Leave anyway'), findsOneWidget);
      await tester.tap(find.text('Keep editing').evaluate().isEmpty ? find.text('Cancel') : find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Title'), findsOneWidget); // still editing, nothing lost
      expect(c.read(draftProvider).body, 'unsent');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave anyway')); // also stops the retry timer
      await tester.pumpAndSettle();
      expect(find.text('HOME ROUTE'), findsOneWidget);
    });

    testWidgets('leaving after a confirmed save does not nag', (tester) async {
      final b = signedInBackend();
      await writing(tester, b);
      await tester.enterText(find.widgetWithText(TextField, 'Begin anywhere…'), 'kept');
      await flush(tester);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Leave anyway'), findsNothing);
      expect(find.text('HOME ROUTE'), findsOneWidget);
      expect(b.moments.length, 1);
    });

    testWidgets('word count appears when asked', (tester) async {
      await writing(tester, signedInBackend());
      await tester.enterText(find.widgetWithText(TextField, 'Begin anywhere…'), 'one two three');
      await tester.tap(find.text('Words'));
      await tester.pump();
      expect(find.text('3 words'), findsOneWidget);
      await flush(tester);
    });

    testWidgets('focus mode hides the chrome and can be exited', (tester) async {
      await writing(tester, signedInBackend());
      await tester.tap(find.byTooltip('Focus mode'));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsNothing);
      expect(find.byTooltip('Exit focus mode'), findsOneWidget);
      await tester.tap(find.byTooltip('Exit focus mode'));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('a letter has its own prompt', (tester) async {
      await writing(tester, signedInBackend(), type: CreationType.letter);
      expect(find.text('Dear…'), findsOneWidget);
    });

    testWidgets('freeform can add a drawing and photos', (tester) async {
      await writing(tester, signedInBackend(), type: CreationType.freeform);
      expect(find.byTooltip('Add a drawing'), findsOneWidget);
      expect(find.byTooltip('Add photo'), findsOneWidget);
    });
  });

  group('Inspiration', () {
    Future<ProviderContainer> details(WidgetTester tester) => pumpScreen(
      tester,
      signedInBackend(),
      const DetailsScreen(),
      before: (c) {
        c.read(draftProvider.notifier)
          ..start(CreationType.writing)
          ..setBody('hello');
      },
    );

    testWidgets('asks what is inspiring and offers all fifteen inspirations', (tester) async {
      await details(tester);
      expect(find.textContaining('inspiring'), findsOneWidget);
      for (final o in inspirationOptions) {
        expect(find.text(o.label), findsOneWidget, reason: o.label);
      }
      await flush(tester);
    });

    testWidgets('selections toggle, can be several, and the button reads Skip when empty', (tester) async {
      final c = await details(tester);
      expect(find.text('Skip'), findsOneWidget);
      await tapVisible(tester, find.text('Moon'));
      await tapVisible(tester, find.text('City'));
      await tapVisible(tester, find.text('Music'));
      await tester.pumpAndSettle();
      expect(c.read(draftProvider).inspirations.map((e) => e.type), ['moon', 'city', 'music']);
      expect(find.text('Continue'), findsOneWidget);
      await tapVisible(tester, find.text('City'));
      await tester.pumpAndSettle();
      expect(c.read(draftProvider).inspirations.length, 2);
      await flush(tester);
    });

    testWidgets('"Something else" takes free text', (tester) async {
      final c = await details(tester);
      await tapVisible(tester, find.text('Something else'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'What was it?'), 'a train at dawn');
      expect(c.read(draftProvider).inspirations.single.name, 'a train at dawn');
      await flush(tester);
    });

    testWidgets('mood step offers every mood and free text for "Other"', (tester) async {
      final c = await details(tester);
      await tapVisible(tester, find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('How does this\nmoment feel?'), findsOneWidget);
      for (final o in moodOptions) {
        expect(find.text(o.label), findsOneWidget, reason: o.label);
      }
      await tapVisible(tester, find.text('Other'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'In your own words'), 'wistful');
      expect(c.read(draftProvider).mood, 'wistful');
      await flush(tester);
    });

    testWidgets('the question can be answered, replaced with another, or skipped', (tester) async {
      final c = await details(tester);
      for (var i = 0; i < 4; i++) {
        await tapVisible(tester, find.text('Skip'));
        await tester.pumpAndSettle();
      }
      expect(find.text('A thought to\nsit with'), findsOneWidget);
      final first = c.read(draftProvider).question!.text;
      expect(find.text(first), findsOneWidget);
      await tapVisible(tester, find.text('Another question'));
      await tester.pumpAndSettle();
      expect(c.read(draftProvider).question!.text, isNot(first));
      expect(find.text('Skip'), findsOneWidget); // no answer needed
      await flush(tester);
    });
  });

  group('Moment detail', () {
    testWidgets('reads like an editorial memory', (tester) async {
      final b = signedInBackend(seed: true);
      final m = b.moments.values.firstWhere((e) => e.title == 'Loneliness, but peaceful');
      await pumpScreen(tester, b, MomentDetailScreen(id: m.id));
      expect(find.text('INSPIRED BY'), findsOneWidget);
      expect(find.text('Moon · City · Music'), findsOneWidget);
      expect(find.text('Peaceful'), findsOneWidget);
      expect(find.textContaining('Nuvole Bianche'), findsWidgets);
      expect(find.textContaining('Milano'), findsWidgets);
      await tester.scrollUntilVisible(find.textContaining('Loneliness, but peaceful.'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('IS THE RAIN PART OF WHAT YOU ARE TRYING TO SAY?'), findsOneWidget);
    });

    testWidgets('delete asks first, then removes the moment', (tester) async {
      final b = signedInBackend(seed: true);
      final m = b.moments.values.firstWhere((e) => e.title == 'Rain on the window');
      await pumpScreen(tester, b, MomentDetailScreen(id: m.id));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this moment?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(b.moments.containsKey(m.id), isTrue);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(b.moments.containsKey(m.id), isFalse);
      expect(find.text('HOME ROUTE'), findsOneWidget);
    });

    testWidgets('edit loads the moment back into the editor', (tester) async {
      final b = signedInBackend(seed: true);
      final m = b.moments.values.firstWhere((e) => e.title == 'Rain on the window');
      final c = await pumpScreen(tester, b, MomentDetailScreen(id: m.id));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(c.read(draftProvider).isEditing, isTrue);
      expect(c.read(draftProvider).title, 'Rain on the window');
      expect(find.text('EDIT ROUTE'), findsOneWidget);
    });

    testWidgets('a missing moment shows a calm not-found state', (tester) async {
      await pumpScreen(tester, signedInBackend(), const MomentDetailScreen(id: 'nope'));
      expect(find.text('Moment not found'), findsOneWidget);
    });
  });

  group('Accessibility', () {
    Future<void> bigText(WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    testWidgets('Home, Create and the inspiration step survive the largest text size', (tester) async {
      await bigText(tester);
      await pumpScreen(tester, signedInBackend(seed: true), const HomeScreen());
      expect(tester.takeException(), isNull);
      await pumpScreen(tester, signedInBackend(), const CreateTypeScreen());
      expect(tester.takeException(), isNull);
      await pumpScreen(tester, signedInBackend(), const DetailsScreen(), before: (c) => c.read(draftProvider.notifier).start(CreationType.writing));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the moment detail and editor survive the largest text size', (tester) async {
      await bigText(tester);
      final b = signedInBackend(seed: true);
      final m = b.moments.values.firstWhere((e) => e.title == 'Loneliness, but peaceful');
      await pumpScreen(tester, b, MomentDetailScreen(id: m.id));
      expect(tester.takeException(), isNull);
      await pumpScreen(tester, signedInBackend(), const EditorScreen(), before: (c) => c.read(draftProvider.notifier).start(CreationType.letter));
      expect(tester.takeException(), isNull);
    });

    testWidgets('primary actions are announced to screen readers with real labels', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, signedInBackend(seed: true), const HomeScreen());
      expect(find.bySemanticsLabel(RegExp('Customize your world')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Create a Moment')), findsWidgets);
      handle.dispose();
    });

    testWidgets('choices report their selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, signedInBackend(), const DetailsScreen(), before: (c) => c.read(draftProvider.notifier).start(CreationType.writing));
      await tapVisible(tester, find.text('Moon'));
      await tester.pumpAndSettle();
      final moon = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Moon')).first);
      expect(moon.label, startsWith('Moon'));
      expect(moon.flagsCollection.isSelected, Tristate.isTrue);
      expect(moon.flagsCollection.isButton, isTrue);
      final rain = tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Rain')).first);
      expect(rain.flagsCollection.isSelected, Tristate.isFalse);
      handle.dispose();
      await flush(tester);
    });

    testWidgets('touch targets are at least 48 logical pixels', (tester) async {
      await pumpScreen(tester, signedInBackend(), const CreateTypeScreen());
      for (final t in CreationType.selectable) {
        final size = tester.getSize(find.ancestor(of: find.text(t.label), matching: find.byType(Glass)).first);
        expect(size.height, greaterThanOrEqualTo(48), reason: t.label);
        expect(size.width, greaterThanOrEqualTo(48), reason: t.label);
      }
    });
  });
}
