part of '../chat.dart';

class _MessageFilterOption {
  const _MessageFilterOption(this.filter, this.label);

  final MessageTimelineFilter filter;
  final String label;
}

class _CalendarTaskShare {
  const _CalendarTaskShare({required this.task, required this.text});

  final CalendarTask? task;
  final String text;
}

List<_MessageFilterOption> _messageFilterOptions(AppLocalizations l10n) => [
  _MessageFilterOption(
    MessageTimelineFilter.directOnly,
    MessageTimelineFilter.directOnly.menuLabel(l10n),
  ),
  _MessageFilterOption(
    MessageTimelineFilter.allWithContact,
    MessageTimelineFilter.allWithContact.menuLabel(l10n),
  ),
];

extension MessageTimelineFilterLabels on MessageTimelineFilter {
  String menuLabel(AppLocalizations l10n) => switch (this) {
    MessageTimelineFilter.directOnly => l10n.chatFilterDirectOnly,
    MessageTimelineFilter.allWithContact => l10n.chatFilterAllWithContact,
  };

  String statusLabel(AppLocalizations l10n) => switch (this) {
    MessageTimelineFilter.directOnly => l10n.chatShowingDirectOnly,
    MessageTimelineFilter.allWithContact => l10n.chatShowingAll,
  };
}

String _sortLabel(SearchSortOrder order, AppLocalizations l10n) =>
    switch (order) {
      SearchSortOrder.newestFirst => l10n.chatSearchSortNewestFirst,
      SearchSortOrder.oldestFirst => l10n.chatSearchSortOldestFirst,
    };

String _collapsedEmailPreviewText(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return normalized;
  }
  final lines = normalized
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) {
    return normalized;
  }
  final preview = lines.take(2).join('\n');
  const maxChars = 280;
  if (preview.length > maxChars) {
    return preview.substring(0, maxChars).trimRight();
  }
  return preview;
}

class _ChatSearchPanel extends StatefulWidget {
  const _ChatSearchPanel();

  @override
  State<_ChatSearchPanel> createState() => _ChatSearchPanelState();
}

class _ChatSearchPanelState extends State<_ChatSearchPanel> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _programmatic = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (_programmatic) return;
    context.read<ChatSearchCubit>().updateQuery(_controller.text);
  }

  void _syncController(String text) {
    if (_controller.text == text) return;
    _programmatic = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _programmatic = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatSearchCubit, ChatSearchState>(
      listener: (context, state) {
        _syncController(state.query);
        if (state.active) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _focusNode.hasFocus) return;
            _focusNode.requestFocus();
          });
        } else if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      },
      builder: (context, state) {
        final l10n = context.l10n;
        final spacing = context.spacing;
        final colors = context.colorScheme;
        final messageFilterOptions = _messageFilterOptions(l10n);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.m,
            vertical: spacing.s,
          ),
          decoration: BoxDecoration(
            color: colors.card,
            border: Border(bottom: context.borderSide),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchInputField(
                      controller: _controller,
                      focusNode: _focusNode,
                      placeholder: Text(l10n.chatSearchMessages),
                      clearTooltip: l10n.commonClear,
                      onClear: _controller.clear,
                    ),
                  ),
                  SizedBox(width: spacing.s),
                  AxiButton(
                    variant: AxiButtonVariant.ghost,
                    onPressed: () =>
                        context.read<ChatSearchCubit>().setActive(false),
                    child: Text(l10n.commonCancel),
                  ),
                ],
              ),
              SizedBox(height: spacing.s),
              Row(
                children: [
                  Expanded(
                    child: AxiSelect<SearchSortOrder>(
                      initialValue: state.sort,
                      onChanged: (value) {
                        if (value == null) return;
                        context.read<ChatSearchCubit>().updateSort(value);
                      },
                      options: SearchSortOrder.values
                          .map(
                            (order) => ShadOption<SearchSortOrder>(
                              value: order,
                              child: Text(_sortLabel(order, l10n)),
                            ),
                          )
                          .toList(),
                      selectedOptionBuilder: (_, value) =>
                          Text(_sortLabel(value, l10n)),
                    ),
                  ),
                  SizedBox(width: spacing.s),
                  Expanded(
                    child: AxiSelect<MessageTimelineFilter>(
                      initialValue: state.filter,
                      onChanged: (value) {
                        if (value == null) return;
                        context.read<ChatSearchCubit>().updateFilter(value);
                      },
                      options: messageFilterOptions
                          .map(
                            (option) => ShadOption<MessageTimelineFilter>(
                              value: option.filter,
                              child: Text(option.label),
                            ),
                          )
                          .toList(),
                      selectedOptionBuilder: (_, value) => Text(
                        messageFilterOptions
                            .firstWhere((option) => option.filter == value)
                            .label,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.s),
              Row(
                children: [
                  Expanded(
                    child: AxiSelect<String>(
                      initialValue: state.subjectFilter ?? '',
                      onChanged: (value) {
                        context.read<ChatSearchCubit>().updateSubjectFilter(
                          value?.isEmpty == true ? null : value,
                        );
                      },
                      options: [
                        ShadOption<String>(
                          value: '',
                          child: Text(l10n.chatSearchAnySubject),
                        ),
                        ...state.subjects.map(
                          (subject) => ShadOption<String>(
                            value: subject,
                            child: Text(subject),
                          ),
                        ),
                      ],
                      selectedOptionBuilder: (_, value) => Text(
                        value.isNotEmpty ? value : l10n.chatSearchAnySubject,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.s),
                  ShadSwitch(
                    value: state.excludeSubject,
                    onChanged: (value) => context
                        .read<ChatSearchCubit>()
                        .toggleExcludeSubject(value),
                  ),
                  SizedBox(width: spacing.s),
                  Text(
                    l10n.chatSearchExcludeSubject,
                    style: context.textTheme.muted,
                  ),
                ],
              ),
              SizedBox(height: spacing.s),
              Row(
                children: [
                  ShadSwitch(
                    value: state.importantOnly,
                    onChanged: (value) => context
                        .read<ChatSearchCubit>()
                        .updateImportantOnly(value),
                  ),
                  SizedBox(width: spacing.s),
                  Text(
                    l10n.chatSearchImportantOnly,
                    style: context.textTheme.muted,
                  ),
                ],
              ),
              SizedBox(height: spacing.s),
              Builder(
                builder: (context) {
                  final trimmedQuery = state.query.trim();
                  final hasSubject = state.subjectFilter?.isNotEmpty == true;
                  final queryEmpty =
                      trimmedQuery.isEmpty &&
                      !hasSubject &&
                      !state.importantOnly;
                  Widget? statusChild;
                  if (state.error != null) {
                    statusChild = Text(
                      state.error ?? l10n.chatSearchFailed,
                      style: TextStyle(color: context.colorScheme.destructive),
                    );
                  } else if (state.status.isLoading) {
                    statusChild = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.chatSearchInProgress,
                          style: context.textTheme.muted,
                        ),
                      ],
                    );
                  } else if (queryEmpty) {
                    statusChild = Text(
                      l10n.chatSearchEmptyPrompt,
                      style: context.textTheme.muted,
                    );
                  } else if (state.status.isSuccess) {
                    final matchCount = state.results.length;
                    statusChild = Text(
                      matchCount == 0
                          ? l10n.chatSearchNoMatches
                          : l10n.chatSearchMatchCount(matchCount),
                      style: context.textTheme.muted,
                    );
                  }
                  if (statusChild == null) {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: statusChild,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
