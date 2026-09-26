import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'data/providers.dart';

class CreativeMomentsApp extends ConsumerWidget {
  const CreativeMomentsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(prefsProvider.select((p) => p.darkMode));
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Creative Moments',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.build(CmColors.light),
      darkTheme: AppTheme.build(CmColors.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: Mo.base,
      builder: (context, child) {
        // Respect Dynamic Type / font scaling, but cap it so layouts survive.
        final mq = MediaQuery.of(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.6)),
            child: child!,
          ),
        );
      },
    );
  }
}
