// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/home/view/home_screen.dart';

class _HomeSearchPanel extends StatefulWidget {
  const _HomeSearchPanel({required this.tabs});

  final List<HomeTabEntry> tabs;

  @override
  State<_HomeSearchPanel> createState() => _HomeSearchPanelState();
}

class _HomeSearchPanelState extends State<_HomeSearchPanel> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _programmaticChange = false;
  ValueListenable<FolderHomeSection?>? _foldersSectionNotifier;

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
    _foldersSectionNotifier?.removeListener(_handleFoldersSectionChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextFoldersSection = _HomeShellScope.maybeOf(context)?.foldersSection;
    if (_foldersSectionNotifier != nextFoldersSection) {
      _foldersSectionNotifier?.removeListener(_handleFoldersSectionChanged);
      _foldersSectionNotifier = nextFoldersSection;
      _foldersSectionNotifier?.addListener(_handleFoldersSectionChanged);
    }
    _syncSearchAvailability();
  }

  void _handleTextChanged() {
    if (_programmaticChange) return;
    final locate = context.read;
    final state = locate<HomeBloc>().state;
    final searchSlot = _resolveHomeSearchSlot(
      activeTab: state.activeTab,
      foldersSection: _HomeShellScope.maybeOf(context)?.foldersSection.value,
    );
    locate<HomeBloc>().add(
      HomeSearchQueryChanged(_controller.text, slot: searchSlot),
    );
    setState(() {});
  }

  void _syncController(String text) {
    if (_controller.text == text) return;
    _programmaticChange = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _programmaticChange = false;
    setState(() {});
  }

  void _handleFoldersSectionChanged() {
    if (!mounted) {
      return;
    }
    _syncSearchAvailability();
    setState(() {});
  }

  void _syncSearchAvailability() {
    final state = context.read<HomeBloc>().state;
    final searchPresentation = _resolveHomeSearchPresentation(
      context,
      tabs: widget.tabs,
      activeTab: state.activeTab,
    );
    if (!searchPresentation.available && state.active) {
      context.read<HomeBloc>().add(const HomeSearchVisibilityChanged(false));
    }
  }

  String _filterLabel(List<HomeSearchFilter> filters, SearchFilterId? id) {
    for (final filter in filters) {
      if (filter.id == id) return filter.label;
    }
    return filters.isNotEmpty ? filters.first.label : '';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listener: (context, state) {
        final searchSlot = _resolveHomeSearchSlot(
          activeTab: state.activeTab,
          foldersSection: _HomeShellScope.maybeOf(
            context,
          )?.foldersSection.value,
        );
        final query = state.stateForSlot(searchSlot).query;
        final searchPresentation = _resolveHomeSearchPresentation(
          context,
          tabs: widget.tabs,
          activeTab: state.activeTab,
        );
        _syncController(query);
        if (!searchPresentation.available) {
          if (_focusNode.hasFocus) {
            _focusNode.unfocus();
          }
          if (state.active) {
            context.read<HomeBloc>().add(
              const HomeSearchVisibilityChanged(false),
            );
          }
          return;
        }
        if (state.active) {
          if (!mounted || _focusNode.hasFocus) return;
          _focusNode.requestFocus();
        } else if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      },
      builder: (context, state) {
        final locate = context.read;
        final l10n = context.l10n;
        final spacing = context.spacing;
        final tab = state.activeTab;
        final searchSlot = _resolveHomeSearchSlot(
          activeTab: tab,
          foldersSection: _HomeShellScope.maybeOf(
            context,
          )?.foldersSection.value,
        );
        final searchPresentation = _resolveHomeSearchPresentation(
          context,
          tabs: widget.tabs,
          activeTab: tab,
        );
        final active = state.active && searchPresentation.available;
        final filters = searchPresentation.filters;
        final currentTabState = state.stateForSlot(searchSlot);
        final sortValue = currentTabState.sort;
        final sortLabel = searchPresentation.sortLabels.label(sortValue, l10n);
        final selectedFilterId = currentTabState.filterId;
        final effectiveFilterId = filters.isEmpty
            ? null
            : (selectedFilterId ?? filters.first.id);
        final placeholder = searchPresentation.label == null
            ? l10n.homeSearchPlaceholderTabs
            : l10n.homeSearchPlaceholderForTab(searchPresentation.label!);
        final filterLabel = filters.isEmpty
            ? null
            : _filterLabel(filters, effectiveFilterId);
        return AnimatedCrossFade(
          crossFadeState: active
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: context.watch<SettingsCubit>().animationDuration,
          reverseDuration: context.watch<SettingsCubit>().animationDuration,
          sizeCurve: Curves.easeInOutCubic,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.m,
              vertical: spacing.s,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.card,
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
                        placeholder: Text(placeholder),
                        clearTooltip: l10n.commonClear,
                        onClear: () => locate<HomeBloc>().add(
                          HomeSearchQueryChanged(
                            '',
                            tab: tab,
                            slot: searchSlot,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.s),
                    AxiButton.ghost(
                      onPressed: () => locate<HomeBloc>().add(
                        const HomeSearchVisibilityChanged(false),
                      ),
                      child: Text(l10n.commonCancel),
                    ),
                  ],
                ),
                SizedBox(height: spacing.s),
                Row(
                  children: [
                    Expanded(
                      child: AxiSelect<SearchSortOrder>(
                        initialValue: sortValue,
                        onChanged: (value) {
                          if (value == null) return;
                          locate<HomeBloc>().add(
                            HomeSearchSortChanged(
                              value,
                              tab: tab,
                              slot: searchSlot,
                            ),
                          );
                        },
                        options: SearchSortOrder.values
                            .map(
                              (order) => ShadOption<SearchSortOrder>(
                                value: order,
                                child: Text(
                                  searchPresentation.sortLabels.label(
                                    order,
                                    l10n,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        selectedOptionBuilder: (_, _) => Text(sortLabel),
                      ),
                    ),
                    if (filters.length > 1 && effectiveFilterId != null) ...[
                      SizedBox(width: spacing.s),
                      Expanded(
                        child: AxiSelect<SearchFilterId>(
                          initialValue: effectiveFilterId,
                          onChanged: (value) {
                            locate<HomeBloc>().add(
                              HomeSearchFilterChanged(
                                value,
                                tab: tab,
                                slot: searchSlot,
                              ),
                            );
                          },
                          options: filters
                              .map(
                                (filter) => ShadOption<SearchFilterId>(
                                  value: filter.id,
                                  child: Text(filter.label),
                                ),
                              )
                              .toList(),
                          selectedOptionBuilder: (_, value) =>
                              Text(_filterLabel(filters, value)),
                        ),
                      ),
                    ],
                  ],
                ),
                if (filterLabel != null && filters.length > 1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: spacing.s),
                      child: Text(
                        l10n.homeSearchFilterLabel(filterLabel),
                        style: context.textTheme.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
