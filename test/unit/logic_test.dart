import 'package:creative_moments/core/animations/sky.dart';
import 'package:creative_moments/core/constants/catalog.dart';
import 'package:creative_moments/core/errors/app_error.dart';
import 'package:creative_moments/core/routing/router.dart';
import 'package:creative_moments/core/services/api_client.dart';
import 'package:creative_moments/core/services/weather_service.dart';
import 'package:creative_moments/data/insights.dart';
import 'package:creative_moments/data/models/moment.dart';
import 'package:creative_moments/features/home/environment/evolution.dart';
import 'package:creative_moments/features/moments/moment_detail_screen.dart';
import 'package:creative_moments/features/world/constellation_layout.dart';
import 'package:creative_moments/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Moment mk(
  String id, {
  String type = 'writing',
  String? mood,
  List<String> insp = const [],
  String tod = 'night',
  DateTime? at,
  String? place,
  String? atmosphere,
}) {
  final t = at ?? DateTime(2026, 9, 1, 22);
  return Moment(
    id: id,
    userId: 'u',
    title: id,
    type: CreationType.parse(type),
    mood: mood,
    atmosphere: atmosphere,
    timeOfDay: tod,
    locationName: place,
    createdAt: t,
    updatedAt: t,
    inspirations: [for (final i in insp) Inspiration(type: i, name: i)],
  );
}

void main() {
  group('time of day', () {
    test('timeOfDayFor buckets the hours', () {
      expect(timeOfDayFor(DateTime(2026, 1, 1, 6)), 'dawn');
      expect(timeOfDayFor(DateTime(2026, 1, 1, 13)), 'day');
      expect(timeOfDayFor(DateTime(2026, 1, 1, 18)), 'sunset');
      expect(timeOfDayFor(DateTime(2026, 1, 1, 23, 40)), 'night');
      expect(timeOfDayFor(DateTime(2026, 1, 1, 2)), 'night');
    });

    test('greetings follow the clock', () {
      expect(greetingForHour(23), 'Good evening.');
      expect(greetingForHour(9), 'Good morning.');
      expect(promptForHour(23), 'What are you inspired by tonight?');
    });

    test('sky nightness moves gradually, not in steps', () {
      final vals = [for (var h = 17.0; h <= 22; h += 0.5) SkyPalette.nightness(h)];
      for (var i = 1; i < vals.length; i++) {
        expect(vals[i] >= vals[i - 1] - 1e-9, isTrue);
        expect(vals[i] - vals[i - 1], lessThan(0.3));
      }
      expect(SkyPalette.nightness(12.5), 0);
      expect(SkyPalette.nightness(1), 1);
      expect(SkyPalette.hourFor('night'), 23);
      expect(SkyPalette.hourFor('auto'), isNull);
    });
  });

  test('relativeDay names tonight, yesterday and weekdays', () {
    final now = DateTime.now();
    expect(relativeDay(DateTime(now.year, now.month, now.day, 23)), 'Tonight');
    expect(relativeDay(DateTime(now.year, now.month, now.day, 9)), 'Today');
    expect(relativeDay(now.subtract(const Duration(days: 1))), 'Yesterday');
    expect(relativeDay(now.subtract(const Duration(days: 3))).length, greaterThan(3));
  });

  group('insights', () {
    test('rank recurring inspirations, moods, places and types', () {
      final ms = [
        mk('a', mood: 'calm', insp: ['moon', 'city'], place: 'Milano', type: 'drawing'),
        mk('b', mood: 'calm', insp: ['moon'], place: 'Milano'),
        mk('c', mood: 'lonely', insp: ['rain'], atmosphere: 'dreamy'),
      ];
      final i = computeInsights(ms);
      expect(i.total, 3);
      expect(i.inspirations.first.key, 'moon');
      expect(i.inspirations.first.count, 2);
      expect(i.moods.first.key, 'calm');
      expect(i.places.single.key, 'Milano');
      expect(i.types.first.key, 'writing');
      expect(i.atmospheres.single.key, 'dreamy');
      expect(computeInsights(const []).total, 0);
    });
  });

  group('home evolution', () {
    Future<Evolution> evo(List<Moment> ms) async {
      final c = ProviderContainer(overrides: [momentsProvider.overrideWith(() => _Fixed(ms))]);
      addTearDown(c.dispose);
      await c.read(momentsProvider.future);
      return c.read(evolutionProvider);
    }

    test('does nothing until there is some history', () async {
      final e = await evo([
        mk('a', insp: ['flowers']),
        mk('b', insp: ['flowers']),
      ]);
      expect(e.bias, isEmpty);
      expect(e.starBoost, 0);
    });

    test('many night moments add stars; many flower moments add botanicals', () async {
      final ms = [
        for (var i = 0; i < 10; i++) mk('m$i', insp: ['flowers'], tod: 'night'),
      ];
      final e = await evo(ms);
      expect(e.bias['flowers'], greaterThan(0));
      expect(e.bias['flowers'], lessThanOrEqualTo(0.45));
      expect(e.bias.containsKey('ocean'), isFalse);
      expect(e.starBoost, greaterThan(0.5));
    });

    test('day moments do not boost the stars as much as night moments', () async {
      final day = await evo([for (var i = 0; i < 6; i++) mk('d$i', tod: 'day')]);
      final night = await evo([for (var i = 0; i < 6; i++) mk('n$i', tod: 'night')]);
      expect(night.starBoost, greaterThan(day.starBoost));
    });
  });

  group('constellation', () {
    test('similar moments are linked and unrelated ones are not', () {
      final a = mk('a', mood: 'calm', insp: ['moon', 'city']);
      final b = mk('b', mood: 'calm', insp: ['moon']);
      final c = mk('c', mood: 'happy', insp: ['desert'], type: 'drawing', at: DateTime(2026, 3, 1, 10), tod: 'day');
      expect(similarity(a, b), greaterThan(similarity(a, c)));
      final l = layoutConstellation([a, b, c]);
      expect(l.nodes.length, 3);
      expect(l.edges.any((e) => e.a == 0 && e.b == 1), isTrue);
      expect(l.edges.any((e) => (e.a == 2 || e.b == 2)), isFalse);
    });

    test('layout is deterministic and finite', () {
      final ms = [
        for (var i = 0; i < 30; i++)
          mk(
            'm$i',
            mood: i.isEven ? 'calm' : 'lonely',
            insp: [i % 3 == 0 ? 'moon' : 'rain'],
            at: DateTime(2026, 9, 1).add(Duration(days: i)),
          ),
      ];
      final l1 = layoutConstellation(ms), l2 = layoutConstellation(ms);
      for (var i = 0; i < ms.length; i++) {
        expect(l1.nodes[i].pos, l2.nodes[i].pos);
        expect(l1.nodes[i].pos.dx.isFinite && l1.nodes[i].pos.dy.isFinite, isTrue);
      }
    });

    test('empty and single-moment histories do not crash', () {
      expect(layoutConstellation(const []).nodes, isEmpty);
      expect(layoutConstellation([mk('a')]).nodes.length, 1);
    });
  });

  group('routing rules', () {
    String? r({String loc = '/home', bool signedIn = true, bool loading = false, bool error = false, bool onboarded = true}) =>
        redirectFor(location: loc, signedIn: signedIn, prefsLoading: loading, prefsError: error, onboarded: onboarded);

    test('signed-out users only see auth routes', () {
      expect(r(signedIn: false), '/welcome');
      expect(r(signedIn: false, loc: '/login'), isNull);
      expect(r(signedIn: false, loc: '/create'), '/welcome');
    });

    test('signed-in users wait on the splash while preferences load', () {
      expect(r(loading: true), '/splash');
      expect(r(loading: true, loc: '/splash'), isNull);
      expect(r(error: true), '/splash');
    });

    test('un-onboarded users are sent to onboarding, onboarded users past it', () {
      expect(r(onboarded: false), '/onboarding');
      expect(r(onboarded: false, loc: '/onboarding'), isNull);
      expect(r(loc: '/onboarding'), '/home');
      expect(r(loc: '/login'), '/home');
      expect(r(loc: '/splash'), '/home');
      expect(r(loc: '/moments'), isNull);
    });
  });

  group('errors', () {
    test('never leak technical text', () {
      for (final e in [Exception('boom: stack trace'), const ApiException(500, 'internal_error'), StateError('bad')]) {
        final m = friendlyError(e);
        expect(m.contains('Exception'), isFalse);
        expect(m.contains('internal_error'), isFalse);
        expect(m.contains('StateError'), isFalse);
      }
    });

    test('auth and network errors get specific, friendly copy', () {
      expect(friendlyError(const ApiException(401, 'invalid_credentials')), contains('do not match'));
      expect(friendlyError(const ApiException(409, 'email_already_registered')), contains('already exists'));
      expect(AppError.from(Exception('SocketException: Failed host lookup')).isNetwork, isTrue);
      expect(friendlyError(const ApiException(404, 'moment_not_found')), contains('found'));
    });
  });

  test('weather codes map to the ambient kinds', () {
    expect(WeatherService.fromCode(0), Weather.clear);
    expect(WeatherService.fromCode(3), Weather.cloudy);
    expect(WeatherService.fromCode(45), Weather.fog);
    expect(WeatherService.fromCode(63), Weather.rain);
    expect(WeatherService.fromCode(95), Weather.rain);
    expect(WeatherService.fromCode(73), Weather.snow);
  });
}

class _Fixed extends MomentsNotifier {
  _Fixed(this.list);
  final List<Moment> list;
  @override
  Future<List<Moment>> build() async => list;
}
