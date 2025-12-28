import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/view/calendar_availability_share_sheet.dart';
import 'package:axichat/src/calendar/view/calendar_experience_state.dart';
import 'package:axichat/src/calendar/view/calendar_task_search.dart';
import 'package:axichat/src/calendar/view/calendar_widget.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/task_sidebar.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_hover_title_scope.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_mobile_tab_shell.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_task_feedback_observer.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';

const double _participantAvatarSize = 28.0;
const double _participantAvatarOverlap = 10.0;
const double _participantOverflowGap = 6.0;
const double _participantAvatarBorderWidth = 1.6;
const int _participantMaxAvatars = 7;
const String _participantOverflowLabel = '...';
const double _chatCalendarShareActionSpacing = 8.0;
const String _chatCalendarAvailabilityShareTooltip = 'Share availability';
const String _chatCalendarAvailabilityShareMissingJidMessage =
    'Calendar sharing is unavailable.';

CalendarAvailabilityShareCoordinator? _maybeReadAvailabilityShareCoordinator(
  BuildContext context,
) {
  try {
    return RepositoryProvider.of<CalendarAvailabilityShareCoordinator>(
      context,
      listen: false,
    );
  } on FlutterError {
    return null;
  }
}

String? _resolveAvailabilityOwnerJid({
  required XmppService xmppService,
  required Chat chat,
}) {
  final String? accountJid = xmppService.myJid?.trim();
  if (chat.type != ChatType.groupChat) {
    return accountJid;
  }
  final String? occupantId =
      xmppService.roomStateFor(chat.jid)?.myOccupantId?.trim();
  if (occupantId != null && occupantId.isNotEmpty) {
    return occupantId;
  }
  return null;
}

class ChatCalendarWidget extends StatefulWidget {
  const ChatCalendarWidget({
    super.key,
    required this.onBackPressed,
    required this.chat,
    required this.participants,
    required this.avatarPaths,
  });

  final VoidCallback onBackPressed;
  final Chat chat;
  final List<String> participants;
  final Map<String, String> avatarPaths;

  @override
  State<ChatCalendarWidget> createState() => _ChatCalendarWidgetState();
}

class _ChatCalendarWidgetState
    extends CalendarExperienceState<ChatCalendarWidget, ChatCalendarBloc> {
  bool _mobileInitialScrollSynced = false;
  late final CalendarHoverTitleController _hoverTitleController =
      CalendarHoverTitleController();

  @override
  CalendarChatAcl? buildNavigationChatAcl(CalendarState state) =>
      widget.chat.type.calendarDefaultAcl;

  @override
  String? buildNavigationChatTitle(CalendarState state) => widget.chat.title;

  @override
  void dispose() {
    _hoverTitleController.dispose();
    super.dispose();
  }

  @override
  void handleStateChanges(BuildContext context, CalendarState state) {
    if (state.error != null && mounted) {
      FeedbackSystem.showError(context, state.error!);
    }
  }

  @override
  void onLayoutModeResolved(CalendarState state, bool usesDesktopLayout) {
    if (usesDesktopLayout && _mobileInitialScrollSynced) {
      _mobileInitialScrollSynced = false;
    }
    if (!usesDesktopLayout) {
      _maybeSyncMobileInitialScroll();
    }
  }

  void _maybeSyncMobileInitialScroll() {
    if (_mobileInitialScrollSynced) {
      return;
    }
    _mobileInitialScrollSynced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      calendarBloc.add(
        CalendarEvent.dateSelected(
          date: DateTime.now(),
        ),
      );
    });
  }

  @override
  CalendarMobileTabShell buildMobileTabShell(
    BuildContext context,
    Widget tabSwitcher,
    Widget cancelBucket,
  ) {
    final colors = context.colorScheme;
    return CalendarMobileTabShell(
      tabBar: tabSwitcher,
      cancelBucket: cancelBucket,
      backgroundColor: colors.background,
      borderColor: colors.border,
      dividerColor: colors.border,
      showTopBorder: false,
      showDivider: true,
    );
  }

  @override
  Widget? buildDesktopTopHeader(Widget navigation, Widget? errorBanner) {
    return CalendarNavSurface(child: navigation);
  }

  @override
  Widget? buildDesktopBodyHeader(Widget navigation, Widget? errorBanner) {
    return errorBanner;
  }

  @override
  Widget buildMobileHeader(
    BuildContext context,
    bool showingPrimary,
    Widget navigation,
    Widget? errorBanner,
  ) {
    final headerChildren = <Widget>[];
    if (showingPrimary) {
      Widget navContent = CalendarNavSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            navigation,
            if (errorBanner != null) errorBanner,
          ],
        ),
      );
      headerChildren.add(
        navContent,
      );
    } else if (errorBanner != null) {
      headerChildren.add(errorBanner);
    }
    if (headerChildren.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: headerChildren,
    );
  }

  @override
  Widget buildScaffoldBody(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
    Widget layout,
  ) {
    final Widget tintedLayout = CalendarNavSurface(child: layout);
    final availabilityCoordinator = _maybeReadAvailabilityShareCoordinator(
      context,
    );
    return CalendarHoverTitleScope(
      controller: _hoverTitleController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChatCalendarAppBar(
            onBackPressed: widget.onBackPressed,
            participants: widget.participants,
            avatarPaths: widget.avatarPaths,
            onShareAvailability: availabilityCoordinator == null
                ? null
                : () => _openAvailabilityShareSheet(
                      state,
                      availabilityCoordinator,
                    ),
          ),
          Expanded(child: tintedLayout),
        ],
      ),
    );
  }

  @override
  VoidCallback? buildNavigationSearchAction(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
  ) {
    final locate = context.read;
    return () => _openTaskSearch(locate<ChatCalendarBloc>(), locate: locate);
  }

  Future<void> _openTaskSearch(
    ChatCalendarBloc bloc, {
    T Function<T>()? locate,
  }) async {
    final TaskSidebarState<ChatCalendarBloc>? sidebarState =
        sidebarKey.currentState;
    await showCalendarTaskSearch(
      context: context,
      bloc: bloc,
      locate: locate,
      requiresLongPressForDrag: sidebarState?.requiresLongPressForDrag ?? false,
      taskTileBuilder: sidebarState == null
          ? null
          : (
              CalendarTask task, {
              Widget? trailing,
              bool requiresLongPress = false,
              VoidCallback? onTap,
              VoidCallback? onDragStart,
              bool allowContextMenu = false,
            }) =>
              sidebarState.buildSearchTaskTile(
                task,
                trailing: trailing,
                requiresLongPress: requiresLongPress,
                onTap: onTap,
                onDragStart: onDragStart,
                allowContextMenu: allowContextMenu,
              ),
    );
  }

  Future<void> _openAvailabilityShareSheet(
    CalendarState state,
    CalendarAvailabilityShareCoordinator coordinator,
  ) async {
    final xmpp = context.read<XmppService>();
    final String? ownerJid = _resolveAvailabilityOwnerJid(
      xmppService: xmpp,
      chat: widget.chat,
    );
    if (ownerJid == null || ownerJid.isEmpty) {
      FeedbackSystem.showError(
        context,
        _chatCalendarAvailabilityShareMissingJidMessage,
      );
      return;
    }
    await showCalendarAvailabilityShareSheet(
      context: context,
      coordinator: coordinator,
      source: CalendarAvailabilityShareSource.chat(
        chatJid: widget.chat.jid,
      ),
      model: state.model,
      ownerJid: ownerJid,
      onAvailabilitySaved: (availability) => calendarBloc.add(
        CalendarEvent.availabilityUpdated(availability: availability),
      ),
      initialChat: widget.chat,
    );
  }

  @override
  Widget wrapWithTaskFeedback(BuildContext context, Widget child) {
    return CalendarTaskFeedbackObserver<ChatCalendarBloc>(child: child);
  }

  @override
  Color resolveSurfaceColor(BuildContext context) =>
      CalendarNavSurface.backgroundColor(context);

  @override
  String get dragLogTag => 'chat-calendar';

  @override
  bool shouldUseDesktopLayout(
    CalendarSizeClass sizeClass,
    MediaQueryData mediaQuery,
  ) {
    return sizeClass == CalendarSizeClass.expanded;
  }
}

class _ChatCalendarAppBar extends StatelessWidget {
  const _ChatCalendarAppBar({
    required this.onBackPressed,
    required this.participants,
    required this.avatarPaths,
    this.onShareAvailability,
  });

  final VoidCallback onBackPressed;
  final List<String> participants;
  final Map<String, String> avatarPaths;
  final VoidCallback? onShareAvailability;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final Color background = CalendarNavSurface.backgroundColor(context);
    final EdgeInsets toolbarPadding =
        calendarMarginLarge.copyWith(top: 0, bottom: 0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: SizedBox(
        height: kToolbarHeight,
        child: Padding(
          padding: toolbarPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AxiIconButton(
                iconData: LucideIcons.arrowLeft,
                tooltip: context.l10n.chatBack,
                color: colors.foreground,
                borderColor: colors.border,
                onPressed: onBackPressed,
              ),
              if (onShareAvailability != null) ...[
                const SizedBox(width: _chatCalendarShareActionSpacing),
                AxiIconButton(
                  iconData: LucideIcons.share2,
                  tooltip: _chatCalendarAvailabilityShareTooltip,
                  color: colors.foreground,
                  borderColor: colors.border,
                  onPressed: onShareAvailability,
                ),
              ],
              const Spacer(),
              if (participants.isNotEmpty)
                Flexible(
                  fit: FlexFit.loose,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ChatCalendarParticipantsStrip(
                      participants: participants,
                      avatarPaths: avatarPaths,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatCalendarParticipantsStrip extends StatelessWidget {
  const ChatCalendarParticipantsStrip({
    super.key,
    required this.participants,
    required this.avatarPaths,
  });

  final List<String> participants;
  final Map<String, String> avatarPaths;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutParticipantStrip(participants, maxWidth);
        final visible = layout.items;
        final overflowed = layout.overflowed;
        final children = <Widget>[];
        for (var i = 0; i < visible.length; i++) {
          final offset =
              i * (_participantAvatarSize - _participantAvatarOverlap);
          children.add(
            Positioned(
              left: offset,
              child: _ChatCalendarAvatar(
                jid: visible[i],
                avatarPath: avatarPaths[visible[i]],
              ),
            ),
          );
        }
        if (overflowed) {
          final offset = visible.isEmpty
              ? 0.0
              : visible.length *
                      (_participantAvatarSize - _participantAvatarOverlap) +
                  _participantOverflowGap;
          children.add(
            Positioned(
              left: offset,
              child: const _ChatCalendarOverflowAvatar(),
            ),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + _participantOverflowGap + _participantAvatarSize
            : math.max(baseWidth, _participantAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: _participantAvatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: children,
          ),
        );
      },
    );
  }
}

class _ChatCalendarAvatar extends StatelessWidget {
  const _ChatCalendarAvatar({
    required this.jid,
    this.avatarPath,
  });

  final String jid;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final borderColor = context.colorScheme.card;
    return Container(
      width: _participantAvatarSize,
      height: _participantAvatarSize,
      padding: const EdgeInsets.all(_participantAvatarBorderWidth),
      decoration: BoxDecoration(
        color: borderColor,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: AxiAvatar(
          jid: jid,
          size: _participantAvatarSize - (_participantAvatarBorderWidth * 2),
          shape: AxiAvatarShape.circle,
          avatarPath: avatarPath,
        ),
      ),
    );
  }
}

class _ChatCalendarOverflowAvatar extends StatelessWidget {
  const _ChatCalendarOverflowAvatar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return SizedBox(
      width: _participantAvatarSize,
      height: _participantAvatarSize,
      child: Center(
        child: Text(
          _participantOverflowLabel,
          style: context.textTheme.small
              .copyWith(
                fontWeight: FontWeight.w700,
                color: colors.mutedForeground,
                height: 1,
              )
              .apply(leadingDistribution: TextLeadingDistribution.even),
        ),
      ),
    );
  }
}

class _ParticipantStripLayout<T> {
  const _ParticipantStripLayout({
    required this.items,
    required this.overflowed,
    required this.totalWidth,
  });

  final List<T> items;
  final bool overflowed;
  final double totalWidth;
}

_ParticipantStripLayout<String> _layoutParticipantStrip(
  List<String> participants,
  double maxContentWidth,
) {
  if (participants.isEmpty || maxContentWidth <= 0) {
    return const _ParticipantStripLayout(
      items: <String>[],
      overflowed: false,
      totalWidth: 0,
    );
  }
  final capped =
      participants.take(_participantMaxAvatars + 1).toList(growable: false);
  final visible = <String>[];
  final additions = <double>[];
  double used = 0;

  for (final participant in capped) {
    if (visible.length >= _participantMaxAvatars) break;
    final addition = visible.isEmpty
        ? _participantAvatarSize
        : _participantAvatarSize - _participantAvatarOverlap;
    if (used + addition > maxContentWidth) {
      break;
    }
    visible.add(participant);
    additions.add(addition);
    used += addition;
  }

  final truncated = visible.length < participants.length;
  double totalWidth = used;

  if (truncated) {
    var ellipsisWidth = visible.isEmpty
        ? _participantAvatarSize
        : _participantAvatarSize - _participantAvatarOverlap;
    while (visible.isNotEmpty && totalWidth + ellipsisWidth > maxContentWidth) {
      totalWidth -= additions.removeLast();
      visible.removeLast();
      ellipsisWidth = visible.isEmpty
          ? _participantAvatarSize
          : _participantAvatarSize - _participantAvatarOverlap;
    }
    if (visible.isEmpty) {
      totalWidth = math.min(ellipsisWidth, maxContentWidth);
    } else {
      totalWidth = math.min(maxContentWidth, totalWidth + ellipsisWidth);
    }
  }

  return _ParticipantStripLayout(
    items: visible,
    overflowed: truncated,
    totalWidth: totalWidth,
  );
}
