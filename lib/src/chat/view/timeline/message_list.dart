part of '../chat.dart';

class _ChatMessageList extends StatefulWidget {
  const _ChatMessageList({
    required this.items,
    required this.itemBuilder,
    required this.messageListOptions,
    required this.scrollToBottomOptions,
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
  final bool readOnly;

  @override
  State<_ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListRow extends StatelessWidget {
  const _ChatMessageListRow({
    required this.item,
    required this.previousItem,
    required this.nextItem,
    required this.itemBuilder,
    required this.messageListOptions,
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

  @override
  Widget build(BuildContext context) {
    final isAfterDateSeparator = _shouldShowChatTimelineDateSeparator(
      previousItem,
      item,
      messageListOptions,
    );
    return Column(
      children: [
        if (isAfterDateSeparator)
          messageListOptions.dateSeparatorBuilder != null
              ? messageListOptions.dateSeparatorBuilder!(item.createdAt)
              : DefaultDateSeparator(
                  date: item.createdAt,
                  messageListOptions: messageListOptions,
                ),
        itemBuilder(item, previousItem, nextItem),
      ],
    );
  }
}

class _ChatMessageListState extends State<_ChatMessageList> {
  bool _scrollToBottomVisible = false;
  bool _isLoadingMore = false;
  int? _loadEarlierStartingCount;
  late final ScrollController _scrollController;

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
              child: ListView.builder(
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
                  return _ChatMessageListRow(
                    item: items[index],
                    previousItem: previousItem,
                    nextItem: nextItem,
                    itemBuilder: itemBuilder,
                    messageListOptions: messageListOptions,
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
