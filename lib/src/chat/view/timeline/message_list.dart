part of '../chat.dart';

class _ChatMessageList extends StatefulWidget {
  const _ChatMessageList({
    required this.items,
    required this.itemBuilder,
    required this.messageListOptions,
    required this.scrollToBottomOptions,
    required this.onRenderedMessagesChanged,
    required this.renderedMessagesHydrationKey,
    this.readOnly = false,
  });

  final List<ChatTimelineItem> items;
  final Widget Function(
    ChatTimelineItem item,
    ChatTimelineItem? previous,
    ChatTimelineItem? next,
  )
  itemBuilder;
  final MessageListOptions messageListOptions;
  final ScrollToBottomOptions scrollToBottomOptions;
  final ValueChanged<List<Message>> onRenderedMessagesChanged;
  final Object? renderedMessagesHydrationKey;
  final bool readOnly;

  @override
  State<_ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListRow extends StatefulWidget {
  const _ChatMessageListRow({
    required this.item,
    required this.previousItem,
    required this.nextItem,
    required this.itemBuilder,
    required this.messageListOptions,
    required this.onMessageRowMounted,
    required this.onMessageRowUnmounted,
  });

  final ChatTimelineItem item;
  final ChatTimelineItem? previousItem;
  final ChatTimelineItem? nextItem;
  final Widget Function(
    ChatTimelineItem item,
    ChatTimelineItem? previous,
    ChatTimelineItem? next,
  )
  itemBuilder;
  final MessageListOptions messageListOptions;
  final ValueChanged<Message> onMessageRowMounted;
  final ValueChanged<Message> onMessageRowUnmounted;

  @override
  State<_ChatMessageListRow> createState() => _ChatMessageListRowState();
}

class _ChatMessageListRowState extends State<_ChatMessageListRow> {
  Message? get _message {
    final item = widget.item;
    return item is ChatTimelineMessageItem ? item.messageModel : null;
  }

  @override
  void initState() {
    super.initState();
    final message = _message;
    if (message != null) {
      widget.onMessageRowMounted(message);
    }
  }

  @override
  void didUpdateWidget(covariant _ChatMessageListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldItem = oldWidget.item;
    final oldMessage = oldItem is ChatTimelineMessageItem
        ? oldItem.messageModel
        : null;
    final message = _message;
    final oldMessageKey = oldMessage == null
        ? null
        : _renderedMessageKey(oldMessage);
    final messageKey = message == null ? null : _renderedMessageKey(message);
    if (oldMessageKey == messageKey) {
      if (message != null && oldMessage != message) {
        widget.onMessageRowMounted(message);
      }
      return;
    }
    if (oldMessage != null) {
      oldWidget.onMessageRowUnmounted(oldMessage);
    }
    if (message != null) {
      widget.onMessageRowMounted(message);
    }
  }

  @override
  void dispose() {
    final message = _message;
    if (message != null) {
      widget.onMessageRowUnmounted(message);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAfterDateSeparator = _shouldShowChatTimelineDateSeparator(
      widget.previousItem,
      widget.item,
      widget.messageListOptions,
    );
    return Column(
      children: [
        if (isAfterDateSeparator)
          widget.messageListOptions.dateSeparatorBuilder != null
              ? widget.messageListOptions.dateSeparatorBuilder!(
                  widget.item.createdAt,
                )
              : DefaultDateSeparator(
                  date: widget.item.createdAt,
                  messageListOptions: widget.messageListOptions,
                ),
        widget.itemBuilder(widget.item, widget.previousItem, widget.nextItem),
      ],
    );
  }
}

class _ChatMessageListState extends State<_ChatMessageList> {
  bool _scrollToBottomVisible = false;
  bool _isLoadingMore = false;
  bool _renderedMessagesNotificationScheduled = false;
  bool _renderedMessagesNotificationForced = false;
  int? _loadEarlierStartingCount;
  late final ScrollController _scrollController;
  final Map<String, Message> _renderedMessagesById = {};
  List<String> _lastRenderedMessageIds = const <String>[];

  @override
  void initState() {
    super.initState();
    final controller =
        widget.messageListOptions.scrollController ?? ScrollController();
    _scrollController = controller..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    if (widget.messageListOptions.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.renderedMessagesHydrationKey !=
        widget.renderedMessagesHydrationKey) {
      _scheduleRenderedMessagesChanged(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final itemBuilder = widget.itemBuilder;
    final messageListOptions = widget.messageListOptions;
    final scrollToBottomOptions = widget.scrollToBottomOptions;
    const double loadEarlierTopInset = 8.0;
    final shouldShowLoadEarlierSpinner =
        _isLoadingMore &&
        (_loadEarlierStartingCount == null ||
            items.length <= _loadEarlierStartingCount!);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewportExtent = constraints.hasBoundedHeight
                      ? constraints.maxHeight
                      : MediaQuery.sizeOf(context).height;
                  final cacheExtent = viewportExtent * 3;
                  return ListView.builder(
                    cacheExtent: cacheExtent,
                    physics: messageListOptions.scrollPhysics,
                    padding: EdgeInsets.zero,
                    controller: _scrollController,
                    reverse: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final ChatTimelineItem? previousItem =
                          index < items.length - 1 ? items[index + 1] : null;
                      final ChatTimelineItem? nextItem = index > 0
                          ? items[index - 1]
                          : null;
                      return RepaintBoundary(
                        key: ValueKey<String>(items[index].id),
                        child: _ChatMessageListRow(
                          item: items[index],
                          previousItem: previousItem,
                          nextItem: nextItem,
                          itemBuilder: itemBuilder,
                          messageListOptions: messageListOptions,
                          onMessageRowMounted: _handleMessageRowMounted,
                          onMessageRowUnmounted: _handleMessageRowUnmounted,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (messageListOptions.chatFooterBuilder != null)
              messageListOptions.chatFooterBuilder!,
          ],
        ),
        if (shouldShowLoadEarlierSpinner)
          Positioned(
            top: loadEarlierTopInset,
            right: 0,
            left: 0,
            child:
                messageListOptions.loadEarlierBuilder ??
                const Center(
                  child: SizedBox(child: CircularProgressIndicator()),
                ),
          ),
        if (!scrollToBottomOptions.disabled && _scrollToBottomVisible)
          scrollToBottomOptions.scrollToBottomBuilder != null
              ? scrollToBottomOptions.scrollToBottomBuilder!(_scrollController)
              : DefaultScrollToBottom(
                  scrollController: _scrollController,
                  readOnly: widget.readOnly,
                  backgroundColor: context.colorScheme.background,
                  textColor: context.colorScheme.primary,
                ),
      ],
    );
  }

  Future<void> _handleScroll() async {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange &&
        widget.messageListOptions.onLoadEarlier != null &&
        !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
        _loadEarlierStartingCount = widget.items.length;
      });
      _showScrollToBottom();
      await widget.messageListOptions.onLoadEarlier!();
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingMore = false;
        _loadEarlierStartingCount = null;
      });
      return;
    }
    const double scrollToBottomThreshold = 200.0;
    if (_scrollController.offset > scrollToBottomThreshold) {
      _showScrollToBottom();
    } else {
      _hideScrollToBottom();
    }
  }

  void _handleMessageRowMounted(Message message) {
    _renderedMessagesById[_renderedMessageKey(message)] = message;
    _scheduleRenderedMessagesChanged();
  }

  void _handleMessageRowUnmounted(Message message) {
    _renderedMessagesById.remove(_renderedMessageKey(message));
    _scheduleRenderedMessagesChanged();
  }

  void _scheduleRenderedMessagesChanged({bool force = false}) {
    if (force) {
      _renderedMessagesNotificationForced = true;
    }
    if (_renderedMessagesNotificationScheduled) {
      return;
    }
    _renderedMessagesNotificationScheduled = true;
    scheduleMicrotask(() {
      final forced = _renderedMessagesNotificationForced;
      _renderedMessagesNotificationScheduled = false;
      _renderedMessagesNotificationForced = false;
      if (!mounted) {
        return;
      }
      final messageIds =
          _renderedMessagesById.entries
              .map(
                (entry) =>
                    '${entry.key}\n${entry.value.deltaMsgId ?? ''}'
                    '\n${entry.value.hasRfc822BodyContent}',
              )
              .toList(growable: false)
            ..sort();
      if (!forced && listEquals(messageIds, _lastRenderedMessageIds)) {
        return;
      }
      _lastRenderedMessageIds = messageIds;
      if (_renderedMessagesById.isEmpty) {
        return;
      }
      widget.onRenderedMessagesChanged(
        List<Message>.unmodifiable(_renderedMessagesById.values),
      );
    });
  }

  void _showScrollToBottom() {
    if (_scrollToBottomVisible) return;
    setState(() {
      _scrollToBottomVisible = true;
    });
  }

  void _hideScrollToBottom() {
    if (!_scrollToBottomVisible) return;
    setState(() {
      _scrollToBottomVisible = false;
    });
  }
}

String _renderedMessageKey(Message message) {
  return '${message.chatJid}\n${message.stanzaID}';
}

@visibleForTesting
Widget debugChatMessageListForTesting({
  required List<ChatTimelineItem> items,
  required Widget Function(
    ChatTimelineItem item,
    ChatTimelineItem? previous,
    ChatTimelineItem? next,
  )
  itemBuilder,
  required MessageListOptions messageListOptions,
  required ScrollToBottomOptions scrollToBottomOptions,
  required ValueChanged<List<Message>> onRenderedMessagesChanged,
  Object? renderedMessagesHydrationKey,
  bool readOnly = false,
}) {
  return _ChatMessageList(
    items: items,
    itemBuilder: itemBuilder,
    messageListOptions: messageListOptions,
    scrollToBottomOptions: scrollToBottomOptions,
    onRenderedMessagesChanged: onRenderedMessagesChanged,
    renderedMessagesHydrationKey: renderedMessagesHydrationKey,
    readOnly: readOnly,
  );
}

bool _shouldShowChatTimelineDateSeparator(
  ChatTimelineItem? previousItem,
  ChatTimelineItem item,
  MessageListOptions messageListOptions,
) {
  if (!messageListOptions.showDateSeparator) {
    return false;
  }
  if (previousItem == null) {
    return true;
  }
  switch (messageListOptions.separatorFrequency) {
    case SeparatorFrequency.days:
      final previousDate = DateTime(
        previousItem.createdAt.year,
        previousItem.createdAt.month,
        previousItem.createdAt.day,
      );
      final messageDate = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );
      return previousDate.difference(messageDate).inDays.abs() > 0;
    case SeparatorFrequency.hours:
      final previousDate = DateTime(
        previousItem.createdAt.year,
        previousItem.createdAt.month,
        previousItem.createdAt.day,
        previousItem.createdAt.hour,
      );
      final messageDate = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
        item.createdAt.hour,
      );
      return previousDate.difference(messageDate).inHours.abs() > 0;
  }
}
