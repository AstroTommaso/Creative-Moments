import 'package:flutter/material.dart';

import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';

/// Renders a photo from a ready-to-use (already signed) URL provided by the
/// backend. Shows a placeholder while `url` is null (still loading) and a
/// "not supported" icon if it fails to load.
class SignedImage extends StatelessWidget {
  const SignedImage({super.key, required this.url, this.fit = BoxFit.cover, this.cacheWidth, this.semanticLabel});
  final String? url;
  final BoxFit fit;
  final int? cacheWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    final u = url;
    if (u == null) return ColoredBox(color: c.surfaceHigh);
    return Image.network(
      u,
      fit: fit,
      cacheWidth: cacheWidth,
      semanticLabel: semanticLabel ?? context.l10n.uiPhotoLabel,
      gaplessPlayback: true,
      frameBuilder: (_, child, frame, sync) => AnimatedOpacity(opacity: frame == null && !sync ? 0 : 1, duration: Mo.slow, child: child),
      errorBuilder: (_, _, _) => ColoredBox(
        color: c.surfaceHigh,
        child: Center(child: Icon(Icons.image_not_supported_outlined, color: c.muted)),
      ),
    );
  }
}
