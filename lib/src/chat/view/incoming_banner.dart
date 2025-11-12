import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;
import 'package:flutter/material.dart';

class IncomingBanner extends StatelessWidget {
  const IncomingBanner({
    super.key,
    required this.participants,
    this.onParticipantTap,
  });

  final List<chat_models.Chat> participants;
  final void Function(chat_models.Chat participant)? onParticipantTap;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final nameChips = participants
        .map(
          (chat) => GestureDetector(
            onTap:
                onParticipantTap == null ? null : () => onParticipantTap!(chat),
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                chat.title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                  decoration: onParticipantTap == null
                      ? TextDecoration.none
                      : TextDecoration.underline,
                ),
              ),
            ),
          ),
        )
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt, size: 14, color: colors.onSecondaryContainer),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              children: [
                Text(
                  'Also sent to: ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
                ...nameChips,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
