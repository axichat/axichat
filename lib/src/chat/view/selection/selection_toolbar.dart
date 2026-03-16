part of '../chat.dart';

class _MessageSelectionToolbar extends StatelessWidget {
  const _MessageSelectionToolbar({
    required this.count,
    required this.onClear,
    required this.onCopy,
    required this.onShare,
    required this.shareStatus,
    required this.onForward,
    required this.onAddToCalendar,
    this.showReactions = false,
    this.onReactionSelected,
    this.onReactionPicker,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final RequestStatus shareStatus;
  final VoidCallback onForward;
  final VoidCallback onAddToCalendar;
  final bool showReactions;
  final ValueChanged<String>? onReactionSelected;
  final VoidCallback? onReactionPicker;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final l10n = context.l10n;
    final onReactionSelected = this.onReactionSelected;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final composerHorizontalInset = spacing.m;
    final iconSize = sizing.menuItemIconSize;
    double scaled(double value) => textScaler.scale(value);
    return SelectionPanelShell(
      includeHorizontalSafeArea: false,
      padding: EdgeInsets.fromLTRB(
        scaled(composerHorizontalInset),
        scaled(spacing.m),
        scaled(composerHorizontalInset),
        scaled(spacing.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectionSummaryHeader(count: count, onClear: onClear),
          SizedBox(height: scaled(spacing.m)),
          Wrap(
            spacing: scaled(spacing.s),
            runSpacing: scaled(spacing.s),
            alignment: WrapAlignment.center,
            children: [
              ContextActionButton(
                icon: Icon(LucideIcons.reply, size: iconSize),
                label: l10n.chatActionForward,
                onPressed: onForward,
              ),
              ContextActionButton(
                icon: Icon(LucideIcons.copy, size: iconSize),
                label: l10n.chatActionCopy,
                onPressed: onCopy,
              ),
              ContextActionButton(
                icon: shareStatus.isLoading
                    ? AxiProgressIndicator(
                        color: context.colorScheme.foreground,
                      )
                    : Icon(LucideIcons.share2, size: iconSize),
                label: l10n.chatActionShare,
                onPressed: shareStatus.isLoading ? null : onShare,
              ),
              ContextActionButton(
                icon: Icon(LucideIcons.calendarPlus, size: iconSize),
                label: l10n.chatActionAddToCalendar,
                onPressed: onAddToCalendar,
              ),
            ],
          ),
          if (showReactions && onReactionSelected != null)
            _MultiSelectReactionPanel(
              onEmojiSelected: onReactionSelected,
              onCustomReaction: onReactionPicker,
            ),
        ],
      ),
    );
  }
}

class _MultiSelectReactionPanel extends StatelessWidget {
  const _MultiSelectReactionPanel({
    required this.onEmojiSelected,
    this.onCustomReaction,
  });

  final ValueChanged<String> onEmojiSelected;
  final VoidCallback? onCustomReaction;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: spacing.m),
        Text(context.l10n.chatActionReact, style: context.textTheme.muted),
        SizedBox(height: spacing.s),
        Wrap(
          spacing: spacing.s,
          runSpacing: spacing.s,
          alignment: WrapAlignment.start,
          children: [
            for (final emoji in _reactionQuickChoices)
              _ReactionQuickButton(
                emoji: emoji,
                onPressed: () => onEmojiSelected(emoji),
              ),
          ],
        ),
      ],
    );
  }
}
