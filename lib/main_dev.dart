// DEVELOPMENT ONLY entrypoint: runs the whole UI against in-memory fakes.
//   flutter run -t lib/main_dev.dart
// A demo account is pre-created: demo@creative.moments / demo-password
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'dev/fake_backend.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  const signedIn = bool.fromEnvironment('SIGNED_IN', defaultValue: true);
  const onboarded = bool.fromEnvironment('ONBOARDED', defaultValue: true);
  final backend = FakeBackend()..createDemoAccount(onboarded: onboarded);
  if (signedIn) backend.currentEmail = 'demo@creative.moments';
  runApp(ProviderScope(retry: (_, _) => null, overrides: backend.overrides, child: const CreativeMomentsApp()));
}
