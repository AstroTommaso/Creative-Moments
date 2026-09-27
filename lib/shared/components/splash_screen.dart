import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_error.dart';
import '../../core/services/l10n_ext.dart';
import '../../core/theme/typography.dart';
import '../../data/providers.dart';
import '../widgets/ui.dart';

/// Shown while the session and preferences load; offers a retry if they cannot.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    return AtmoScaffold(
      intensity: 1,
      body: Center(
        child: prefs.hasError && !prefs.hasValue
            ? ErrorState(message: friendlyError(prefs.error!), onRetry: () => ref.invalidate(preferencesProvider))
            : Text(
                context.l10n.appBrandName,
                textAlign: TextAlign.center,
                style: AppType.display(48, color: Colors.white, height: 1),
              ),
      ),
    );
  }
}
