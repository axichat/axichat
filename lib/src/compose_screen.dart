import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/view/compose_draft_content.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _composeScreenMaxWidth = 720;

class ComposeScreen extends StatelessWidget {
  const ComposeScreen({
    super.key,
    required this.seed,
  });

  final ComposeDraftSeed seed;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        shape: Border(
          bottom: BorderSide(color: colors.border),
        ),
        leadingWidth: AxiIconButton.kDefaultSize + 24,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: AxiIconButton.kDefaultSize,
                    height: AxiIconButton.kDefaultSize,
                    child: AxiIconButton(
                      iconData: LucideIcons.arrowLeft,
                      tooltip: l10n.commonBack,
                      color: colors.foreground,
                      borderColor: colors.border,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              )
            : null,
        title: Text(l10n.composeTitle),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _composeScreenMaxWidth),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.card,
                shadows: calendarMediumShadow,
                shape: ContinuousRectangleBorder(
                  borderRadius: ShadTheme.of(context).radius,
                  side: BorderSide(color: colors.border),
                ),
              ),
              child: ComposeDraftContent(
                seed: seed,
                onClosed: () => Navigator.maybePop(context),
                onDiscarded: () => Navigator.maybePop(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
