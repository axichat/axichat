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
    return BlocSelector<ChatBloc, ChatState, bool>(
      selector: (state) => state.chat?.defaultTransport.isEmail == true,
      builder: (context, emailSearchScope) {
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
            final locate = context.read;
            final l10n = context.l10n;
            final spacing = context.spacing;
            final colors = context.colorScheme;
            final messageFilterOptions = _messageFilterOptions(l10n);
            final historyLocation =
                '${l10n.profileTitle} > ${l10n.settingsSectionData}';
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
                          placeholder: Text(
                            emailSearchScope
                                ? l10n.chatSearchOnDeviceEmailPlaceholder
                                : l10n.chatSearchMessages,
                          ),
                          clearTooltip: l10n.commonClear,
                          onClear: _controller.clear,
                        ),
                      ),
                      SizedBox(width: spacing.s),
                      AxiButton(
                        variant: AxiButtonVariant.ghost,
                        onPressed: () =>
                            locate<ChatSearchCubit>().setActive(false),
                        child: Text(l10n.commonCancel),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.s),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: spacing.s,
                      runSpacing: spacing.s,
                      children: [
                        AxiDropdown<SearchSortOrder>(
                          value: state.sort,
                          onChanged: (value) =>
                              locate<ChatSearchCubit>().updateSort(value),
                          options: SearchSortOrder.values
                              .map(
                                (order) => AxiDropdownOption<SearchSortOrder>(
                                  value: order,
                                  label: _sortLabel(order, l10n),
                                  child: Text(_sortLabel(order, l10n)),
                                ),
                              )
                              .toList(),
                          selectedBuilder: (_, value) => Text(
                            l10n.commonLabeledValue(
                              l10n.commonSort,
                              _sortLabel(value, l10n),
                            ),
                          ),
                        ),
                        AxiDropdown<MessageTimelineFilter>(
                          value: state.filter,
                          onChanged: (value) =>
                              locate<ChatSearchCubit>().updateFilter(value),
                          options: messageFilterOptions
                              .map(
                                (option) =>
                                    AxiDropdownOption<MessageTimelineFilter>(
                                      value: option.filter,
                                      label: option.label,
                                      child: Text(option.label),
                                    ),
                              )
                              .toList(),
                          selectedBuilder: (_, value) {
                            final label = messageFilterOptions
                                .firstWhere((option) => option.filter == value)
                                .label;
                            return Text(
                              l10n.commonLabeledValue(l10n.commonFilter, label),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.s),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: spacing.s,
                      runSpacing: spacing.s,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AxiDropdown<String>(
                          value: state.subjectFilter ?? '',
                          onChanged: (value) {
                            locate<ChatSearchCubit>().updateSubjectFilter(
                              value.isEmpty ? null : value,
                            );
                          },
                          options: [
                            AxiDropdownOption<String>(
                              value: '',
                              label: l10n.chatSearchAnySubject,
                              child: Text(l10n.chatSearchAnySubject),
                            ),
                            ...state.subjects.map(
                              (subject) => AxiDropdownOption<String>(
                                value: subject,
                                label: subject,
                                child: Text(subject),
                              ),
                            ),
                          ],
                          selectedBuilder: (_, value) => Text(
                            l10n.commonLabeledValue(
                              l10n.chatMessageSubjectLabel,
                              value.isNotEmpty
                                  ? value
                                  : l10n.chatSearchAnySubject,
                            ),
                          ),
                        ),
                        ShadSwitch(
                          value: state.excludeSubject,
                          onChanged: (value) => locate<ChatSearchCubit>()
                              .toggleExcludeSubject(value),
                        ),
                        Text(
                          l10n.chatSearchExcludeSubject,
                          style: context.textTheme.muted,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.s),
                  Row(
                    children: [
                      ShadSwitch(
                        value: state.importantOnly,
                        onChanged: (value) => locate<ChatSearchCubit>()
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
                      final hasSubject =
                          state.subjectFilter?.isNotEmpty == true;
                      final queryEmpty =
                          trimmedQuery.isEmpty &&
                          !hasSubject &&
                          !state.importantOnly;
                      Widget? statusChild;
                      if (state.error != null) {
                        statusChild = Text(
                          state.error ?? l10n.chatSearchFailed,
                          style: context.textTheme.muted.copyWith(
                            color: context.colorScheme.destructive,
                          ),
                        );
                      } else if (state.status.isLoading) {
                        statusChild = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AxiProgressIndicator(
                              color: context.colorScheme.primary,
                            ),
                            SizedBox(width: spacing.s),
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
                  if (emailSearchScope) ...[
                    SizedBox(height: spacing.s),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AxiHighlightedSubstringText(
                        text: l10n.emailSearchOnDeviceHistoryHint(
                          historyLocation,
                        ),
                        substring: historyLocation,
                        style: context.textTheme.muted,
                        highlightStyle: context.textTheme.muted.strong,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
