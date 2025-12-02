import 'package:axichat/src/app.dart';
import 'package:axichat/src/blocklist/bloc/blocklist_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BlockButtonInline extends StatelessWidget {
  const BlockButtonInline({
    super.key,
    required this.jid,
    this.emailAddress,
    this.useEmailBlocking = false,
    this.callback,
    this.showIcon = false,
    this.mainAxisAlignment,
  });

  final String jid;
  final String? emailAddress;
  final bool useEmailBlocking;
  final void Function()? callback;
  final bool showIcon;
  final MainAxisAlignment? mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    if (useEmailBlocking) {
      return _EmailBlockButton(
        emailAddress: emailAddress,
        callback: callback,
        showIcon: showIcon,
        mainAxisAlignment: mainAxisAlignment,
      );
    }
    return BlocSelector<BlocklistCubit, BlocklistState, bool>(
      selector: (state) =>
          state is BlocklistLoading && (state.jid == jid || state.jid == null),
      builder: (context, disabled) {
        final onPressed = disabled
            ? null
            : () {
                context.read<BlocklistCubit?>()?.block(jid: jid);
                if (callback != null) {
                  callback!();
                }
              };
        return ShadButton.ghost(
          width: double.infinity,
          mainAxisAlignment: mainAxisAlignment,
          onPressed: onPressed,
          foregroundColor: context.colorScheme.destructive,
          leading: showIcon ? const Icon(LucideIcons.userX) : null,
          child: Text(context.l10n.blocklistBlock),
        ).withTapBounce(enabled: onPressed != null);
      },
    );
  }
}

class _EmailBlockButton extends StatelessWidget {
  const _EmailBlockButton({
    required this.emailAddress,
    this.callback,
    this.showIcon = false,
    this.mainAxisAlignment,
  });

  final String? emailAddress;
  final void Function()? callback;
  final bool showIcon;
  final MainAxisAlignment? mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final EmailService? emailService =
        RepositoryProvider.of<EmailService?>(context);
    final String? address = emailAddress?.trim();
    final disabled = emailService == null || address == null || address.isEmpty;
    if (disabled) {
      return ShadButton.ghost(
        width: double.infinity,
        mainAxisAlignment: mainAxisAlignment,
        onPressed: null,
        foregroundColor: context.colorScheme.destructive,
        leading: showIcon ? const Icon(LucideIcons.userX) : null,
        child: Text(context.l10n.blocklistBlock),
      ).withTapBounce(enabled: false);
    }
    Future<void> handleBlock() async {
      await emailService.blocking.block(address);
      callback?.call();
    }

    return ShadButton.ghost(
      width: double.infinity,
      mainAxisAlignment: mainAxisAlignment,
      onPressed: handleBlock,
      foregroundColor: context.colorScheme.destructive,
      leading: showIcon ? const Icon(LucideIcons.userX) : null,
      child: Text(context.l10n.blocklistBlock),
    ).withTapBounce(enabled: true);
  }
}
