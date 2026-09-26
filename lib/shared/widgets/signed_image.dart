import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../data/repositories/storage_repository.dart';

/// Loads a private storage object through a signed URL.
class SignedImage extends ConsumerWidget {
  const SignedImage({super.key, required this.path, this.bucket = StorageRepository.mediaBucket, this.fit = BoxFit.cover, this.cacheWidth, this.semanticLabel});
  final String path, bucket;
  final BoxFit fit;
  final int? cacheWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(signedUrlProvider((bucket: bucket, path: path)));
    final c = context.cm;
    return url.when(
      data: (u) => Image.network(
        u,
        fit: fit,
        cacheWidth: cacheWidth,
        semanticLabel: semanticLabel ?? 'Photo',
        gaplessPlayback: true,
        frameBuilder: (_, child, frame, sync) => AnimatedOpacity(opacity: frame == null && !sync ? 0 : 1, duration: Mo.slow, child: child),
        errorBuilder: (_, _, _) => ColoredBox(
          color: c.surfaceHigh,
          child: Center(child: Icon(Icons.image_not_supported_outlined, color: c.muted)),
        ),
      ),
      loading: () => ColoredBox(color: c.surfaceHigh),
      error: (_, _) => ColoredBox(
        color: c.surfaceHigh,
        child: Center(child: Icon(Icons.image_not_supported_outlined, color: c.muted)),
      ),
    );
  }
}
