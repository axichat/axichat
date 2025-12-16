import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiInputDialog extends StatelessWidget {
  const AxiInputDialog({
    super.key,
    required this.title,
    required this.content,
    this.callback,
    this.callbackText,
    this.loading = false,
    this.actions = const [],
  });

  final Widget title;
  final Widget content;
  final void Function()? callback;
  final String? callbackText;
  final bool loading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final Widget resolvedTitle = DefaultTextStyle.merge(
      style: context.modalHeaderTextStyle,
      child: title,
    );
    final resolvedCallbackText = callbackText ?? context.l10n.commonContinue;
    const loadingSemanticsLabel = 'Loading';
    return ShadDialog(
      title: resolvedTitle,
      actions: [
        ShadButton.outline(
          onPressed: () => context.pop(),
          child: Text(context.l10n.commonCancel),
        ).withTapBounce(),
        ...actions,
        ShadButton(
          enabled: callback != null && !loading,
          onPressed: loading ? null : callback,
          leading: AnimatedCrossFade(
            crossFadeState:
                loading ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            firstChild: const SizedBox(),
            secondChild: AxiProgressIndicator(
              color: context.colorScheme.primaryForeground,
              semanticsLabel: loadingSemanticsLabel,
            ),
          ),
          child: Text(resolvedCallbackText),
        ).withTapBounce(enabled: callback != null && !loading),
      ],
      child: content,
    );
  }
}
