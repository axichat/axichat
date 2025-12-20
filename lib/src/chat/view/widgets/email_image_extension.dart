import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

/// Creates a flutter_html extension that blocks or allows external images.
///
/// When [shouldLoad] is false, displays a placeholder that can be tapped
/// to trigger [onLoadRequested].
TagExtension createEmailImageExtension({
  required bool shouldLoad,
  VoidCallback? onLoadRequested,
}) {
  return TagExtension(
    tagsToExtend: {'img'},
    builder: (extensionContext) {
      if (shouldLoad) {
        final src = extensionContext.attributes['src'];
        if (src == null || src.isEmpty) {
          return const SizedBox.shrink();
        }
        return Image.network(
          src,
          errorBuilder: (context, error, stackTrace) {
            return const EmailImagePlaceholder(isError: true);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
        );
      }
      return EmailImagePlaceholder(onTap: onLoadRequested);
    },
  );
}

/// Placeholder widget shown when external images are blocked.
class EmailImagePlaceholder extends StatelessWidget {
  const EmailImagePlaceholder({
    super.key,
    this.onTap,
    this.isError = false,
  });

  final VoidCallback? onTap;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.broken_image_outlined : Icons.image_outlined,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              isError ? 'Image failed' : 'Image blocked',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
