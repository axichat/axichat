part of '../chat.dart';

class _ChatMessageList extends StatefulWidget {
  const _ChatMessageList({
    required this.items,
    required this.itemBuilder,
    required this.messageListOptions,
    required this.scrollToBottomOptions,
    required this.onRenderedMessagesChanged,
    required this.renderedMessagesHydrationKey,
    required this.onTimelineItemMounted,
    required this.onTimelineItemUnmounted,
    required this.onUserScrollIntent,
    required this.isLoadingEarlier,
    this.readOnly = false,
  });

  final List<ChatTimelineItem> items;
  final Widget Function(
    ChatTimelineItem item,
    ChatTimelineItem? previous,
    ChatTimelineItem? next,
    int visualOrder,
  )
  itemBuilder;
  final MessageListOptions messageListOptions;
  final ScrollToBottomOptions scrollToBottomOptions;
  final ValueChanged<List<Message>> onRenderedMessagesChanged;
  final Object? renderedMessagesHydrationKey;
  final ValueChanged<String> onTimelineItemMounted;
  final ValueChanged<String> onTimelineItemUnmounted;
  final VoidCallback onUserScrollIntent;
  final bool isLoadingEarlier;
  final bool readOnly;

  @override
  State<_ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListRow extends StatefulWidget {
  const _ChatMessageListRow({
    required this.item,
    required this.previousItem,
    required this.nextItem,
    required this.visualOrder,
    required this.itemBuilder,
    required this.messageListOptions,
    required this.onTimelineItemMounted,
    required this.onTimelineItemUnmounted,
    required this.onMessageRowMounted,
    required this.onMessageRowUnmounted,
  });

  final ChatTimelineItem item;
  final ChatTimelineItem? previousItem;
  final ChatTimelineItem? nextItem;
  final int visualOrder;
  final Widget Function(
    ChatTimelineItem item,
    ChatTimelineItem? previous,
    ChatTimelineItem? next,
    int visualOrder,
  )
  itemBuilder;
  final MessageListOptions messageListOptions;
  final ValueChanged<String> onTimelineItemMounted;
  final ValueChanged<String> onTimelineItemUnmounted;
  final ValueChanged<ChatTimelineMessageItem> onMessageRowMounted;
  final ValueChanged<ChatTimelineMessageItem> onMessageRowUnmounted;

  @override
  State<_ChatMessageListRow> createState() => _ChatMessageListRowState();
}

class _ChatMessageListRowState extends State<_ChatMessageListRow> {
  ChatTimelineMessageItem? get _messageItem {
    final item = widget.item;
    return item is ChatTimelineMessageItem ? item : null;
  }

  @override
  void initState() {
    super.initState();
    widget.onTimelineItemMounted(widget.item.id);
    final item = _messageItem;
    if (item != null) {
      widget.onMessageRowMounted(item);
    }
  }

  @override
  void didUpdateWidget(covariant _ChatMessageListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldItem = oldWidget.item;
    if (oldItem.id != widget.item.id) {
      oldWidget.onTimelineItemUnmounted(oldItem.id);
      widget.onTimelineItemMounted(widget.item.id);
    }
    final oldMessageItem = oldItem is ChatTimelineMessageItem ? oldItem : null;
    final oldMessage = oldMessageItem?.messageModel;
    final messageItem = _messageItem;
    final message = messageItem?.messageModel;
    final oldMessageKey = oldMessage == null
        ? null
        : _renderedMessageKey(oldMessage);
    final messageKey = message == null ? null : _renderedMessageKey(message);
    if (oldMessageKey == messageKey) {
      if (messageItem != null) {
        widget.onMessageRowMounted(messageItem);
      }
      return;
    }
    if (oldMessageItem != null) {
      oldWidget.onMessageRowUnmounted(oldMessageItem);
    }
    if (messageItem != null) {
      widget.onMessageRowMounted(messageItem);
    }
  }

  @override
  void dispose() {
    widget.onTimelineItemUnmounted(widget.item.id);
    final item = _messageItem;
    if (item != null) {
      widget.onMessageRowUnmounted(item);
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
        widget.itemBuilder(
          widget.item,
          widget.previousItem,
          widget.nextItem,
          widget.visualOrder,
        ),
      ],
    );
  }
}

class _ChatMessageListState extends State<_ChatMessageList> {
  bool _scrollToBottomVisible = false;
  bool _renderedMessagesNotificationScheduled = false;
  bool _renderedMessagesNotificationForced = false;
  int? _viewportFillLoadEarlierStartingCount;
  bool _viewportFillLoadEarlierScheduled = false;
  bool _loadEarlierEdgePinScheduled = false;
  late final ScrollController _scrollController;
  final Map<String, ChatTimelineMessageItem> _renderedMessagesById = {};
  List<String> _lastRenderedMessageIds = const <String>[];

  @override
  void initState() {
    super.initState();
    final controller =
        widget.messageListOptions.scrollController ?? ScrollController();
    _scrollController = controller..addListener(_handleScroll);
    _scheduleViewportFillLoadEarlier();
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
    if (oldWidget.items.length != widget.items.length) {
      _viewportFillLoadEarlierStartingCount = null;
      _scheduleViewportFillLoadEarlier();
    } else if (oldWidget.messageListOptions.onLoadEarlier !=
        widget.messageListOptions.onLoadEarlier) {
      _scheduleViewportFillLoadEarlier();
    }
    if (!oldWidget.isLoadingEarlier && widget.isLoadingEarlier) {
      _scheduleLoadEarlierEdgePin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final itemBuilder = widget.itemBuilder;
    final messageListOptions = widget.messageListOptions;
    final scrollToBottomOptions = widget.scrollToBottomOptions;
    final shouldShowLoadEarlierSpinner = widget.isLoadingEarlier;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: Listener(
                  onPointerSignal: _handlePointerSignal,
                  child: ListView.builder(
                    scrollCacheExtent: const ScrollCacheExtent.viewport(3),
                    physics: messageListOptions.scrollPhysics,
                    padding: EdgeInsets.zero,
                    controller: _scrollController,
                    reverse: true,
                    itemCount:
                        items.length + (shouldShowLoadEarlierSpinner ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return messageListOptions.loadEarlierBuilder ??
                            Padding(
                              padding: EdgeInsets.all(context.spacing.m),
                              child: const Center(
                                child: AxiProgressIndicator(),
                              ),
                            );
                      }
                      final ChatTimelineItem? previousItem =
                          index < items.length - 1 ? items[index + 1] : null;
                      final ChatTimelineItem? nextItem = index > 0
                          ? items[index - 1]
                          : null;
                      final visualOrder = items.length - index;
                      return RepaintBoundary(
                        key: ValueKey<String>(items[index].id),
                        child: _ChatMessageListRow(
                          item: items[index],
                          previousItem: previousItem,
                          nextItem: nextItem,
                          visualOrder: visualOrder,
                          itemBuilder: itemBuilder,
                          messageListOptions: messageListOptions,
                          onTimelineItemMounted: widget.onTimelineItemMounted,
                          onTimelineItemUnmounted:
                              widget.onTimelineItemUnmounted,
                          onMessageRowMounted: _handleMessageRowMounted,
                          onMessageRowUnmounted: _handleMessageRowUnmounted,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (messageListOptions.chatFooterBuilder != null)
              messageListOptions.chatFooterBuilder!,
          ],
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

  void _handleScroll() {
    if (_loadEarlierIfNeeded(fillViewport: false)) {
      return;
    }
    const double scrollToBottomThreshold = 200.0;
    if (_scrollController.offset > scrollToBottomThreshold) {
      _showScrollToBottom();
    } else {
      _hideScrollToBottom();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      widget.onUserScrollIntent();
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      widget.onUserScrollIntent();
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      widget.onUserScrollIntent();
    }
    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification ||
        notification is ScrollEndNotification) {
      if (_isAtLoadEarlierEdge(notification.metrics)) {
        _loadEarlierIfNeeded(
          fillViewport: false,
          metrics: notification.metrics,
        );
      }
    }
    return false;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      widget.onUserScrollIntent();
    }
  }

  void _scheduleViewportFillLoadEarlier() {
    if (_viewportFillLoadEarlierScheduled) {
      return;
    }
    _viewportFillLoadEarlierScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportFillLoadEarlierScheduled = false;
      if (!mounted) {
        return;
      }
      _loadEarlierIfNeeded(fillViewport: true);
    });
  }

  void _scheduleLoadEarlierEdgePin() {
    if (_loadEarlierEdgePinScheduled) {
      return;
    }
    _loadEarlierEdgePinScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEarlierEdgePinScheduled = false;
      if (!mounted ||
          !widget.isLoadingEarlier ||
          !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final maxScrollExtent = position.maxScrollExtent;
      if ((maxScrollExtent - position.pixels).abs() <=
          precisionErrorTolerance) {
        return;
      }
      _scrollController.jumpTo(maxScrollExtent);
    });
  }

  bool _isAtLoadEarlierEdge(ScrollMetrics metrics) {
    return metrics.extentAfter <= precisionErrorTolerance;
  }

  bool _loadEarlierIfNeeded({
    required bool fillViewport,
    ScrollMetrics? metrics,
  }) {
    if (!_scrollController.hasClients ||
        widget.messageListOptions.onLoadEarlier == null ||
        widget.isLoadingEarlier) {
      return false;
    }
    final position = _scrollController.position;
    final effectiveMetrics = metrics ?? position;
    if (fillViewport) {
      if (position.outOfRange) {
        return false;
      }
      if (position.maxScrollExtent > 0) {
        return false;
      }
      if (_viewportFillLoadEarlierStartingCount == widget.items.length) {
        return false;
      }
      _viewportFillLoadEarlierStartingCount = widget.items.length;
    } else if (!_isAtLoadEarlierEdge(effectiveMetrics)) {
      return false;
    }
    if (!fillViewport) {
      _showScrollToBottom();
    }
    unawaited(widget.messageListOptions.onLoadEarlier!());
    return true;
  }

  void _handleMessageRowMounted(ChatTimelineMessageItem item) {
    _renderedMessagesById[_renderedMessageKey(item.messageModel)] = item;
    _scheduleRenderedMessagesChanged();
  }

  void _handleMessageRowUnmounted(ChatTimelineMessageItem item) {
    _renderedMessagesById.remove(_renderedMessageKey(item.messageModel));
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final forced = _renderedMessagesNotificationForced;
      _renderedMessagesNotificationScheduled = false;
      _renderedMessagesNotificationForced = false;
      if (!mounted) {
        return;
      }
      final renderedEntries = _renderedMessagesById.entries.toList(
        growable: false,
      )..sort((left, right) => left.key.compareTo(right.key));
      final messageIds = renderedEntries
          .map((entry) => _renderedMessageHydrationSignature(entry.value))
          .toList(growable: false);
      if (!forced && listEquals(messageIds, _lastRenderedMessageIds)) {
        return;
      }
      _lastRenderedMessageIds = messageIds;
      widget.onRenderedMessagesChanged(
        List<Message>.unmodifiable(
          renderedEntries.map((entry) => entry.value.messageModel),
        ),
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

String _renderedMessageHydrationSignature(ChatTimelineMessageItem item) {
  final message = item.messageModel;
  return [
    _renderedMessageKey(message),
    message.deltaMsgId ?? '',
    message.displayed ? 1 : 0,
    message.rfc822BodyStatus.index,
    message.body?.hashCode ?? '',
    message.htmlBody?.hashCode ?? '',
    message.subject?.hashCode ?? '',
    message.fileMetadataID ?? '',
    item.attachmentIds.join('\u0000'),
  ].join('\n');
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
  bool isLoadingEarlier = false,
  bool readOnly = false,
}) {
  return _ChatMessageList(
    items: items,
    itemBuilder: (item, previous, next, _) => itemBuilder(item, previous, next),
    messageListOptions: messageListOptions,
    scrollToBottomOptions: scrollToBottomOptions,
    onRenderedMessagesChanged: onRenderedMessagesChanged,
    renderedMessagesHydrationKey: renderedMessagesHydrationKey,
    onTimelineItemMounted: (_) {},
    onTimelineItemUnmounted: (_) {},
    onUserScrollIntent: () {},
    isLoadingEarlier: isLoadingEarlier,
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
