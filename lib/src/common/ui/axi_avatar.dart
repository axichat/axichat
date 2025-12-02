import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum AxiAvatarShape { circle, squircle }

class AxiAvatar extends StatefulWidget {
  const AxiAvatar({
    super.key,
    required this.jid,
    this.subscription = Subscription.none,
    this.presence,
    this.status,
    this.active = false,
    this.shape = AxiAvatarShape.circle,
    this.size = 50.0,
  });

  final String jid;
  final Subscription subscription;
  final Presence? presence;
  final String? status;
  final bool active;
  final AxiAvatarShape shape;
  final double size;

  @override
  State<AxiAvatar> createState() => _AxiAvatarState();
}

class _AxiAvatarState extends State<AxiAvatar> {
  late final ShadPopoverController popoverController;

  @override
  void initState() {
    super.initState();
    popoverController = ShadPopoverController();
  }

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.size * 0.45;
    final ShapeBorder avatarShape = widget.shape == AxiAvatarShape.circle
        ? const CircleBorder()
        : ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          );

    Widget child = SizedBox.square(
      dimension: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              final baseJid = widget.jid;
              final initial = baseJid.isNotEmpty
                  ? baseJid.substring(0, 1).toUpperCase()
                  : '?';
              final backgroundColor = state.colorfulAvatars
                  ? stringToColor(widget.jid)
                  : context.colorScheme.secondary;
              final textColor = state.colorfulAvatars
                  ? Colors.white
                  : context.colorScheme.secondaryForeground;
              final textStyle = TextStyle(
                color: textColor,
                fontSize: widget.size * 0.45,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              );
              return ClipPath(
                clipper: ShapeBorderClipper(shape: avatarShape),
                child: ColoredBox(
                  color: backgroundColor,
                  child: Center(
                    child: Text(
                      initial,
                      style: textStyle,
                    ),
                  ),
                ),
              );
            },
          ),
          widget.presence == null ||
                  widget.subscription.isNone ||
                  widget.subscription.isFrom
              ? const SizedBox()
              : Positioned.fill(
                  child: FractionallySizedBox(
                    widthFactor: 0.35,
                    heightFactor: 0.35,
                    alignment: Alignment.bottomRight,
                    child: PresenceIndicator(
                      presence: widget.presence!,
                      status: widget.status,
                    ),
                  ),
                ),
        ],
      ),
    );
    if (widget.active && widget.presence != null) {
      final locate = context.read;
      child = ShadPopover(
        controller: popoverController,
        popover: (context) {
          return BlocProvider.value(
            value: locate<ProfileCubit>(),
            child: IntrinsicWidth(
              child: Material(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final value
                        in Presence.values.toList()..remove(Presence.unknown))
                      ListTile(
                        title: Text(value.tooltip),
                        leading: PresenceCircle(presence: value),
                        selected: widget.presence?.name == value.name,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        selectedColor: context.colorScheme.accentForeground,
                        selectedTileColor: context.colorScheme.accent,
                        onTap: () {
                          context
                              .read<ProfileCubit>()
                              .updatePresence(presence: value);
                          popoverController.toggle();
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        child: ShadGestureDetector(
          cursor: SystemMouseCursors.click,
          onTap: popoverController.toggle,
          child: child,
        ),
      );
    }
    final sizedChild = SizedBox.square(dimension: widget.size, child: child);
    final statusText = widget.status?.trim();
    final presenceLabel = widget.presence?.tooltip;
    final tooltipText = () {
      if (statusText != null && statusText.isNotEmpty) {
        return presenceLabel == null
            ? statusText
            : '$statusText ($presenceLabel)';
      }
      return presenceLabel;
    }();
    if (tooltipText == null) return sizedChild;
    return AxiTooltip(
      builder: (_) => Text(tooltipText),
      child: sizedChild,
    );
  }
}
