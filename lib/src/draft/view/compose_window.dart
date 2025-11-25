import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/compose_window_cubit.dart';
import 'package:axichat/src/draft/view/draft_form.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _composeHeaderHeight = 48;
const double _composeWindowPadding = 12;
const double _composeWindowWidth = 520;
const double _composeWindowExpandedWidth = 720;
const double _composeWindowHeight = 520;
const double _composeWindowExpandedHeight = 640;
const double _composeWindowMinWidth = 360;
const double _composeWindowMinHeight = 260;

class ComposeWindowOverlay extends StatelessWidget {
  const ComposeWindowOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ComposeWindowCubit, ComposeWindowState>(
      builder: (context, state) {
        if (!state.visible) return const SizedBox.shrink();
        final mediaSize = MediaQuery.sizeOf(context);
        final colors = context.colorScheme;
        final cardRadius = context.radius;
        final isMinimized = state.isMinimized;
        final isExpanded = state.isExpanded;

        final double availableWidth =
            math.max(mediaSize.width - (_composeWindowPadding * 2), 0);
        final double targetWidth = math.max(
          math.min(
            isExpanded ? _composeWindowExpandedWidth : _composeWindowWidth,
            availableWidth,
          ),
          math.min(availableWidth, _composeWindowMinWidth),
        );

        final double availableHeight =
            math.max(mediaSize.height - (_composeWindowPadding * 2), 0);
        final double constrainedHeight = math.min(
          isExpanded ? _composeWindowExpandedHeight : _composeWindowHeight,
          availableHeight,
        );
        final double targetHeight = isMinimized
            ? _composeHeaderHeight
            : math.max(
                constrainedHeight,
                math.min(availableHeight, _composeWindowMinHeight),
              );
        final double bodyHeight =
            math.max(targetHeight - _composeHeaderHeight, 0);

        return SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(_composeWindowPadding),
              child: AnimatedContainer(
                width: targetWidth,
                height: targetHeight,
                duration: baseAnimationDuration,
                curve: Curves.easeOutCubic,
                decoration: ShapeDecoration(
                  color: colors.card,
                  shadows: calendarMediumShadow,
                  shape: ContinuousRectangleBorder(
                    borderRadius: cardRadius,
                    side: BorderSide(color: colors.border),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _ComposeWindowHeader(
                      seed: state.seed,
                      minimized: isMinimized,
                      expanded: isExpanded,
                      onMinimize: () => isMinimized
                          ? context.read<ComposeWindowCubit>().restore()
                          : context.read<ComposeWindowCubit>().minimize(),
                      onToggleExpanded: () =>
                          context.read<ComposeWindowCubit>().toggleExpanded(),
                      onClose: () => context.read<ComposeWindowCubit>().hide(),
                    ),
                    Expanded(
                      child: Offstage(
                        offstage: isMinimized,
                        child: AnimatedOpacity(
                          opacity: isMinimized ? 0 : 1,
                          duration: baseAnimationDuration,
                          curve: Curves.easeInOut,
                          child: _ComposeWindowBody(
                            key: ValueKey(state.session),
                            seed: state.seed,
                            availableHeight: bodyHeight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ComposeWindowHeader extends StatelessWidget {
  const _ComposeWindowHeader({
    required this.seed,
    required this.minimized,
    required this.expanded,
    required this.onMinimize,
    required this.onToggleExpanded,
    required this.onClose,
  });

  final ComposeDraftSeed seed;
  final bool minimized;
  final bool expanded;
  final VoidCallback onMinimize;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final subject = seed.subject.trim();
    final recipients =
        seed.jids.where((jid) => jid.trim().isNotEmpty).take(3).join(', ');
    final detailLabel = subject.isNotEmpty
        ? subject
        : (recipients.isNotEmpty ? recipients : 'New message');
    final minimizeIcon = minimized ? LucideIcons.chevronUp : LucideIcons.minus;
    final expandIcon = expanded ? LucideIcons.minimize2 : LucideIcons.maximize2;

    return Container(
      height: _composeHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.pencilLine,
            size: 18,
            color: colors.foreground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compose',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detailLabel,
                  overflow: TextOverflow.ellipsis,
                  style:
                      textTheme.muted.copyWith(color: colors.mutedForeground),
                ),
              ],
            ),
          ),
          _ComposeHeaderButton(
            tooltip: minimized ? 'Restore' : 'Minimize',
            icon: minimizeIcon,
            onPressed: onMinimize,
          ),
          const SizedBox(width: 6),
          _ComposeHeaderButton(
            tooltip: expanded ? 'Exit fullscreen' : 'Expand',
            icon: expandIcon,
            onPressed: onToggleExpanded,
          ),
          const SizedBox(width: 6),
          _ComposeHeaderButton(
            tooltip: 'Close composer',
            icon: LucideIcons.x,
            onPressed: onClose,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

class _ComposeHeaderButton extends StatelessWidget {
  const _ComposeHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final foreground = destructive ? colors.destructive : colors.foreground;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: AxiIconButton(
        iconData: icon,
        semanticLabel: tooltip,
        onPressed: onPressed,
        color: foreground,
        backgroundColor: colors.card,
        borderColor: colors.border,
        borderWidth: 1.2,
        buttonSize: 34,
        tapTargetSize: 36,
        iconSize: 18,
        cornerRadius: 12,
      ),
    );
  }
}

class _ComposeWindowBody extends StatelessWidget {
  const _ComposeWindowBody({
    super.key,
    required this.seed,
    required this.availableHeight,
  });

  final ComposeDraftSeed seed;
  final double availableHeight;

  @override
  Widget build(BuildContext context) {
    final xmppService = context.read<XmppService>();
    final emailService = context.read<EmailService?>();
    final suggestionAddresses = <String>{
      if (xmppService.myJid?.isNotEmpty == true) xmppService.myJid!,
      if (emailService?.activeAccount?.address.isNotEmpty == true)
        emailService!.activeAccount!.address,
    };
    final suggestionDomains = <String>{
      EndpointConfig.defaultDomain,
      ...suggestionAddresses.map(_domainFromAddress).whereType<String>(),
    };

    final chatsCubit = context.read<ChatsCubit?>();
    return MultiBlocProvider(
      providers: [
        if (chatsCubit != null) BlocProvider.value(value: chatsCubit),
      ],
      child: SizedBox(
        height: availableHeight,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DraftForm(
            id: seed.id,
            jids: seed.jids,
            body: seed.body,
            subject: seed.subject,
            attachmentMetadataIds: seed.attachmentMetadataIds,
            suggestionAddresses: suggestionAddresses,
            suggestionDomains: suggestionDomains,
            onClosed: () => context.read<ComposeWindowCubit>().hide(),
            onDiscarded: () => context.read<ComposeWindowCubit>().hide(),
          ),
        ),
      ),
    );
  }
}

String? _domainFromAddress(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || !trimmed.contains('@')) {
    return null;
  }
  final parts = trimmed.split('@');
  if (parts.length != 2) return null;
  final domain = parts.last.trim().toLowerCase();
  return domain.isEmpty ? null : domain;
}
