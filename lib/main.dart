import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/services/config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'core/theme/typography.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  if (!AppConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
  runApp(ProviderScope(retry: (_, _) => null, child: const CreativeMomentsApp()));
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(CmColors.dark),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Sp.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Almost there', style: AppType.display(40, color: CmColors.dark.text)),
                const SizedBox(height: Sp.md),
                Text(
                  'This build has no Supabase configuration. Run with\n--dart-define-from-file=.env\nsee README.md',
                  textAlign: TextAlign.center,
                  style: AppType.ui(15, color: CmColors.dark.muted, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
