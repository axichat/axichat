// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart' show ComposerRecipient;
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RecipientChipsBar extends StatefulWidget {
  const RecipientChipsBar({
    super.key,
    required this.recipients,
    required this.availableChats,
    this.rosterItems = const <RosterItem>[],
    this.recipientSuggestionsStream,
    this.selfJid,
    required this.onRecipientAdded,
    required this.onRecipientToggled,
    required this.onRecipientRemoved,
    required this.latestStatuses,
    this.collapsedByDefault = false,
    this.suggestionAddresses = const <String>{},
    this.suggestionDomains = const <String>{},
    this.horizontalPadding = chipsBarHorizontalPadding,
    this.visibilityLabel,
    this.tapRegionGroup,
    this.allowAddressTargets = true,
    this.showSuggestionsWhenEmpty = true,
  });

  final List<ComposerRecipient> recipients;
  final List<Chat> availableChats;
  final List<RosterItem> rosterItems;
  final Stream<List<String>>? recipientSuggestionsStream;
  final String? selfJid;
  final ValueChanged<FanOutTarget> onRecipientAdded;
  final ValueChanged<String> onRecipientToggled;
  final ValueChanged<String> onRecipientRemoved;
  final Map<String, FanOutRecipientState> latestStatuses;
  final bool collapsedByDefault;
  final Set<String> suggestionAddresses;
  final Set<String> suggestionDomains;
  final double horizontalPadding;
  final String? visibilityLabel;
  final Object? tapRegionGroup;
  final bool allowAddressTargets;
  final bool showSuggestionsWhenEmpty;

  @override
  State<RecipientChipsBar> createState() => _RecipientChipsBarState();
}

class _RecipientChipsBarState extends State<RecipientChipsBar>
    with SingleTickerProviderStateMixin {
  static const _collapsedVisibleCount = 4;

  late Object _tapRegionGroup;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  StreamSubscription<List<String>>? _recipientSuggestionSubscription;
  Stream<List<String>>? _recipientSuggestionsStream;
  List<String> _databaseSuggestionAddresses = const [];
  bool _expanded = false;
  late bool _barCollapsed;
  bool _headerFocused = false;
  late List<ComposerRecipient> _renderedRecipients;
  final Set<String> _enteringKeys = <String>{};
  final Set<String> _removingKeys = <String>{};
  List<FanOutTarget> _suggestions = const <FanOutTarget>[];
  final ValueNotifier<int?> _highlightedSuggestionIndex = ValueNotifier<int?>(
    null,
  );
  String? _pendingRemovalKey;
  late final AnimationController _collapseController;
  late final Animation<double> _collapseAnimation;
  String? _ownNormalizedJid;
  List<RosterItem> _lastRosterItems = const <RosterItem>[];
  Map<String, String> _avatarPathsByJid = const <String, String>{};
  List<Chat> _availableAutocompleteChats = const <Chat>[];
  Set<String> _knownDomains = const <String>{};
  Set<String> _knownAddresses = const <String>{};
  Set<String> _knownAddressesLower = const <String>{};

  @override
  void initState() {
    super.initState();
    _tapRegionGroup = widget.tapRegionGroup ?? EditableText;
    _focusNode
      ..onKeyEvent = _handleKeyEvent
      ..addListener(_handleAutocompleteFocusChanged);
    _renderedRecipients = _visibleRecipientsForState();
    _barCollapsed = widget.collapsedByDefault;
    _collapseController = AnimationController(
      vsync: this,
      duration: chipsBarAnimationDuration,
      value: _barCollapsed ? 0 : 1,
    );
    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOutCubic,
    );
    _controller.addListener(_handleTextChanged);
    _lastRosterItems = List<RosterItem>.from(widget.rosterItems);
    _avatarPathsByJid = _computeAvatarPaths(widget.rosterItems);
    final pools = _computeSuggestionPools();
    _availableAutocompleteChats = pools.availableChats;
    _knownDomains = pools.domains;
    _knownAddresses = pools.addresses;
    _knownAddressesLower = pools.addressesLower;
    _updateSuggestionStream(widget.recipientSuggestionsStream);
    _updateOwnJid(widget.selfJid);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSuggestionStream(widget.recipientSuggestionsStream);
    _updateOwnJid(widget.selfJid);
  }

  void _updateSuggestionStream(Stream<List<String>>? stream) {
    if (identical(stream, _recipientSuggestionsStream)) return;
    _recipientSuggestionsStream = stream;
    _recipientSuggestionSubscription?.cancel();
    if (stream == null) {
      if (_databaseSuggestionAddresses.isNotEmpty) {
        if (mounted) {
          setState(() {
            _databaseSuggestionAddresses = const [];
          });
        } else {
          _databaseSuggestionAddresses = const [];
        }
        _refreshSuggestionPools();
      }
      return;
    }
    _recipientSuggestionSubscription = stream.listen((addresses) {
      if (!mounted) return;
      if (listEquals(addresses, _databaseSuggestionAddresses)) return;
      setState(() {
        _databaseSuggestionAddresses = addresses;
      });
      _refreshSuggestionPools();
    });
  }

  void _updateOwnJid(String? jid) {
    final normalized = _normalizeAddress(jid);
    if (normalized == _ownNormalizedJid) return;
    setState(() {
      _ownNormalizedJid = normalized;
    });
    _refreshSuggestionPools();
  }

  @override
  void didUpdateWidget(covariant RecipientChipsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tapRegionGroup, widget.tapRegionGroup)) {
      _tapRegionGroup = widget.tapRegionGroup ?? EditableText;
    }
    if (oldWidget.collapsedByDefault != widget.collapsedByDefault) {
      _barCollapsed = widget.collapsedByDefault;
      _animateCollapse(_barCollapsed);
    }
    if (!identical(
      oldWidget.recipientSuggestionsStream,
      widget.recipientSuggestionsStream,
    )) {
      _updateSuggestionStream(widget.recipientSuggestionsStream);
    }
    if (oldWidget.selfJid != widget.selfJid) {
      _updateOwnJid(widget.selfJid);
    }
    _syncRenderedRecipients();
    _prunePendingRemoval();
    _refreshAvatarPaths();
    _refreshSuggestionPools();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _highlightedSuggestionIndex.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _recipientSuggestionSubscription?.cancel();
    _collapseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final recipients = widget.recipients;
    final avatarPathsByJid = _avatarPathsByJid;
    final visibleRecipients = _visibleRecipientsForState();
    final overflow = recipients.length - visibleRecipients.length;
    final chips = <Widget>[
      for (final recipient in _renderedRecipients)
        _AnimatedChipWrapper(
          key: ValueKey('recipient-${recipient.key}'),
          isEntering: _enteringKeys.contains(recipient.key),
          isRemoving: _removingKeys.contains(recipient.key),
          child: _RecipientChip(
            recipient: recipient,
            avatarPathsByJid: avatarPathsByJid,
            status: _statusFor(recipient),
            pendingRemoval: _pendingRemovalKey == recipient.key,
            onToggle: () => widget.onRecipientToggled(recipient.key),
            onRemove:
                recipient.pinned ? null : () => _removeRecipient(recipient.key),
          ),
        ),
      if (!_barCollapsed && !_expanded && overflow > 0)
        _AnimatedChipWrapper(
          key: ValueKey('show-more-$overflow'),
          child: _ActionChip(
            label: l10n.recipientsOverflowMore(overflow),
            icon: Icons.add,
            onPressed: () => _toggleListExpansion(true),
          ),
        ),
      if (!_barCollapsed && _expanded && overflow > 0)
        _AnimatedChipWrapper(
          key: const ValueKey('collapse'),
          child: _ActionChip(
            label: l10n.recipientsCollapse,
            icon: Icons.expand_less,
            onPressed: () => _toggleListExpansion(false),
          ),
        ),
    ];

    final barBackground = colors.card;
    final availableAutocompleteChats = _availableAutocompleteChats;
    final knownDomains = _knownDomains;
    final knownAddresses = _knownAddresses;
    final headerPadding = EdgeInsets.symmetric(
      horizontal: context.spacing.m,
      vertical: context.spacing.xs,
    );
    final bodyPadding = EdgeInsets.symmetric(
      horizontal: widget.horizontalPadding,
      vertical: context.spacing.s,
    );
    final headerStyle = context.textTheme.small.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.mutedForeground,
    );
    final normalizedVisibilityLabel = widget.visibilityLabel?.trim() ?? '';
    final showVisibilityBadge = normalizedVisibilityLabel.isNotEmpty;
    final arrowIcon =
        _barCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up;
    return ChipsBarSurface(
      backgroundColor: barBackground,
      padding: bodyPadding,
      borderSide: context.borderSide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusableActionDetector(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _toggleBarCollapsed();
                  return null;
                },
              ),
            },
            onShowFocusHighlight: (focused) {
              if (_headerFocused == focused) return;
              setState(() => _headerFocused = focused);
            },
            child: Semantics(
              container: true,
              button: true,
              toggled: !_barCollapsed,
              label: l10n.recipientsSemantics(
                recipients.length,
                _barCollapsed
                    ? l10n.recipientsStateCollapsed
                    : l10n.recipientsStateExpanded,
              ),
              hint: _barCollapsed
                  ? l10n.recipientsHintExpand
                  : l10n.recipientsHintCollapse,
              onTap: _toggleBarCollapsed,
              child: ShadFocusable(
                canRequestFocus: true,
                builder: (context, focused, child) =>
                    child ?? const SizedBox.shrink(),
                child: ShadGestureDetector(
                  cursor: SystemMouseCursors.click,
                  hoverStrategies: mobileHoverStrategies,
                  onTap: _toggleBarCollapsed,
                  child: AxiTapBounce(
                    child: AnimatedContainer(
                      duration: chipsBarAnimationDuration,
                      curve: Curves.easeInOutCubic,
                      padding: headerPadding,
                      decoration: ShapeDecoration(
                        color: context.colorScheme.card,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: context.radius,
                          side: _headerFocused
                              ? context.borderSide
                                  .copyWith(color: context.colorScheme.primary)
                              : context.borderSide,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.recipientsHeaderTitle,
                              style: headerStyle,
                            ),
                          ),
                          if (showVisibilityBadge) ...[
                            AxiModalSurface(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.spacing.s,
                                vertical: context.spacing.xxs,
                              ),
                              child: Text(
                                normalizedVisibilityLabel,
                                style: headerStyle.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: context.spacing.m),
                          ],
                          SizedBox(width: context.spacing.s),
                          ChipsBarCountBadge(
                            count: recipients.length,
                            expanded: !_barCollapsed,
                            colors: context.colorScheme,
                          ),
                          SizedBox(width: context.spacing.xs),
                          AnimatedSwitcher(
                            duration: chipsBarAnimationDuration,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: Icon(
                              arrowIcon,
                              key: ValueKey<bool>(_barCollapsed),
                              size: context.sizing.menuItemIconSize,
                              color: context.colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ClipRect(
            child: SizeTransition(
              sizeFactor: _collapseAnimation,
              axisAlignment: -1,
              child: AnimatedSize(
                duration: chipsBarAnimationDuration,
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacing.m,
                    vertical: context.spacing.s,
                  ),
                  child: Wrap(
                    spacing: context.spacing.s,
                    runSpacing: context.spacing.s,
                    children: [
                      ...chips,
                      Builder(
                        builder: (context) {
                          final settingsState =
                              context.watch<SettingsCubit>().state;
                          return _AnimatedChipWrapper(
                            key: const ValueKey('autocomplete-field'),
                            child: _RecipientAutocompleteField(
                              controller: _controller,
                              focusNode: _focusNode,
                              tapRegionGroup: _tapRegionGroup,
                              fieldOuterPadding: context.spacing.s,
                              fieldInnerPadding: context.spacing.m,
                              backgroundColor: barBackground,
                              avatarPathsByJid: avatarPathsByJid,
                              showSuggestionsWhenEmpty:
                                  widget.showSuggestionsWhenEmpty,
                              optionsBuilder: (raw) => _autocompleteOptions(
                                raw,
                                availableAutocompleteChats,
                                knownDomains,
                                knownAddresses,
                                shareTokenSignatureEnabled:
                                    settingsState.shareTokenSignatureEnabled,
                              ),
                              highlightedIndexListenable:
                                  _highlightedSuggestionIndex,
                              onManualEntry: _handleManualEntry,
                              onOptionsChanged: _updateSuggestions,
                              onSubmitted: _handleAutocompleteSubmit,
                              onRecipientAdded: _handleRecipientAdded,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _computeAvatarPaths(List<RosterItem> rosterItems) {
    final next = <String, String>{};
    for (final item in rosterItems) {
      final path = item.avatarPath?.trim();
      if (path == null || path.isEmpty) continue;
      next[item.jid.toLowerCase()] = path;
    }
    return next;
  }

  void _refreshAvatarPaths() {
    final rosterItems = widget.rosterItems;
    if (listEquals(rosterItems, _lastRosterItems)) {
      return;
    }
    _lastRosterItems = List<RosterItem>.from(rosterItems);
    final next = _computeAvatarPaths(rosterItems);
    if (mapEquals(next, _avatarPathsByJid)) {
      return;
    }
    setState(() {
      _avatarPathsByJid = next;
    });
  }

  ({
    List<Chat> availableChats,
    Set<String> domains,
    Set<String> addresses,
    Set<String> addressesLower,
  }) _computeSuggestionPools() {
    final allowAddressTargets = widget.allowAddressTargets;
    final availableChats = widget.availableChats;
    final recipients = widget.recipients;
    final nextAvailable = availableChats
        .where(
          (chat) => !recipients.any(
            (recipient) => recipient.target.chat?.jid == chat.jid,
          ),
        )
        .toList(growable: false);
    final Set<String> nextDomains;
    final Set<String> nextAddresses;
    if (!allowAddressTargets) {
      nextDomains = const <String>{};
      nextAddresses = const <String>{};
    } else {
      final domains = <String>{EndpointConfig.defaultDomain}
        ..addAll(widget.suggestionDomains);
      void addDomainFrom(String? address) {
        if (_isRoomNick(address)) return;
        if (_isOwnAddress(address)) return;
        final domain = _extractDomain(address);
        if (domain != null) {
          domains.add(domain);
        }
      }

      for (final suggestion in widget.suggestionAddresses) {
        addDomainFrom(suggestion);
      }
      for (final suggestion in _databaseSuggestionAddresses) {
        addDomainFrom(suggestion);
      }
      for (final chat in availableChats) {
        addDomainFrom(chat.emailAddress);
        addDomainFrom(chat.jid);
        addDomainFrom(chat.remoteJid);
      }
      for (final recipient in recipients) {
        final target = recipient.target;
        addDomainFrom(target.chat?.emailAddress ?? target.address);
        addDomainFrom(target.chat?.jid);
        addDomainFrom(target.chat?.remoteJid);
      }

      final addresses = <String>{}
        ..addAll(widget.suggestionAddresses)
        ..addAll(_databaseSuggestionAddresses);
      void addAddress(String? raw) {
        final value = raw?.trim();
        if (value == null || value.isEmpty) return;
        if (_isRoomNick(value)) return;
        if (_isOwnAddress(value)) return;
        addresses.add(value);
      }

      for (final chat in availableChats) {
        addAddress(chat.emailAddress);
        addAddress(chat.jid);
        addAddress(chat.remoteJid);
      }
      for (final recipient in recipients) {
        final target = recipient.target;
        addAddress(target.address);
        addAddress(target.chat?.jid);
        addAddress(target.chat?.emailAddress);
        addAddress(target.chat?.remoteJid);
      }
      nextDomains = domains;
      nextAddresses = addresses;
    }
    final lowerAddresses =
        nextAddresses.map((address) => address.toLowerCase()).toSet();
    return (
      availableChats: nextAvailable,
      domains: nextDomains,
      addresses: nextAddresses,
      addressesLower: lowerAddresses,
    );
  }

  void _refreshSuggestionPools() {
    final pools = _computeSuggestionPools();
    if (listEquals(pools.availableChats, _availableAutocompleteChats) &&
        setEquals(pools.domains, _knownDomains) &&
        setEquals(pools.addresses, _knownAddresses) &&
        setEquals(pools.addressesLower, _knownAddressesLower)) {
      return;
    }
    setState(() {
      _availableAutocompleteChats = pools.availableChats;
      _knownDomains = pools.domains;
      _knownAddresses = pools.addresses;
      _knownAddressesLower = pools.addressesLower;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      return _moveAutocompleteHighlight(1);
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return _moveAutocompleteHighlight(-1);
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _handleAutocompleteSubmit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace && _controller.text.isEmpty) {
      _handleBackspacePress();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _handleManualEntry(String value) {
    if (!widget.allowAddressTargets) {
      return false;
    }
    if (!_looksLikeEmail(value)) {
      return false;
    }
    if (_isRoomNick(value)) {
      return false;
    }
    if (_isOwnAddress(value)) {
      return false;
    }
    _handleRecipientAdded(
      FanOutTarget.address(
        address: value,
        shareSignatureEnabled:
            context.read<SettingsCubit>().state.shareTokenSignatureEnabled,
      ),
    );
    return true;
  }

  void _updateSuggestions(List<FanOutTarget> suggestions) {
    _suggestions = suggestions;
    _highlightedSuggestionIndex.value = null;
  }

  void _handleTextChanged() {
    if (_pendingRemovalKey != null && _controller.text.isNotEmpty) {
      _clearPendingRemoval();
    }
  }

  KeyEventResult _moveAutocompleteHighlight(int delta) {
    if (_suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }
    int? next = _highlightedSuggestionIndex.value;
    if (next == null) {
      if (delta > 0) {
        next = 0;
      } else {
        return KeyEventResult.handled;
      }
    } else {
      final candidate = next + delta;
      if (candidate < 0) {
        next = null;
      } else if (candidate >= _suggestions.length) {
        next = _suggestions.length - 1;
      } else {
        next = candidate;
      }
    }
    if (next == _highlightedSuggestionIndex.value) {
      return KeyEventResult.handled;
    }
    _highlightedSuggestionIndex.value = next;
    return KeyEventResult.handled;
  }

  bool _handleAutocompleteSubmit() {
    final text = _controller.text.trim();
    final highlighted = _highlightedSuggestionIndex.value;
    if (highlighted != null &&
        highlighted >= 0 &&
        highlighted < _suggestions.length) {
      _handleRecipientAdded(_suggestions[highlighted]);
      _controller.clear();
      _updateSuggestions(const <FanOutTarget>[]);
      return true;
    }
    if (text.isEmpty) {
      return false;
    }
    if (_handleManualEntry(text)) {
      _controller.clear();
      _updateSuggestions(const <FanOutTarget>[]);
      return true;
    }
    return false;
  }

  void _handleAutocompleteFocusChanged() {
    if (_focusNode.hasFocus) return;
    final submitted = _handleAutocompleteSubmit();
    if (!submitted) return;
    _controller.clear();
    _updateSuggestions(const <FanOutTarget>[]);
  }

  void _handleBackspacePress() {
    final removable = _removableRecipients();
    if (removable.isEmpty) return;
    final lastKey = removable.last.key;
    if (_pendingRemovalKey == lastKey) {
      _removeRecipient(lastKey);
      return;
    }
    _setPendingRemoval(lastKey);
  }

  void _setPendingRemoval(String key) {
    if (_pendingRemovalKey == key) return;
    setState(() => _pendingRemovalKey = key);
  }

  void _clearPendingRemoval() {
    if (_pendingRemovalKey == null) return;
    setState(() => _pendingRemovalKey = null);
  }

  void _prunePendingRemoval() {
    final key = _pendingRemovalKey;
    if (key == null) return;
    final exists = widget.recipients.any((recipient) => recipient.key == key);
    if (!exists) {
      _clearPendingRemoval();
    }
  }

  void _removeRecipient(String key) {
    if (_pendingRemovalKey == key) {
      _clearPendingRemoval();
    }
    widget.onRecipientRemoved(key);
  }

  List<ComposerRecipient> _removableRecipients() =>
      widget.recipients.where((recipient) => !recipient.pinned).toList();

  void _handleRecipientAdded(FanOutTarget target) {
    _clearPendingRemoval();
    widget.onRecipientAdded(target);
  }

  bool _looksLikeEmail(String value) {
    final pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return pattern.hasMatch(value);
  }

  List<ComposerRecipient> _visibleRecipientsForState() {
    if (_expanded || widget.recipients.length <= _collapsedVisibleCount) {
      return List<ComposerRecipient>.from(widget.recipients);
    }
    return widget.recipients.take(_collapsedVisibleCount).toList();
  }

  void _toggleListExpansion(bool expand) {
    if (_expanded == expand) return;
    setState(() {
      _expanded = expand;
    });
    _syncRenderedRecipients();
  }

  void _toggleBarCollapsed() {
    final next = !_barCollapsed;
    setState(() {
      _barCollapsed = next;
    });
    _animateCollapse(next);
  }

  void _animateCollapse(bool collapsed) {
    if (collapsed) {
      _collapseController.animateTo(0);
    } else {
      _collapseController.animateTo(1);
    }
  }

  void _syncRenderedRecipients() {
    final desired = _visibleRecipientsForState();
    final current = List<ComposerRecipient>.from(_renderedRecipients);

    for (var i = 0; i < desired.length; i++) {
      final recipient = desired[i];
      final index = current.indexWhere((item) => item.key == recipient.key);
      _removingKeys.remove(recipient.key);
      if (index == -1) {
        current.insert(i, recipient);
        _flagEntering(recipient.key);
      } else {
        current[index] = recipient;
        if (index != i) {
          final item = current.removeAt(index);
          current.insert(i, item);
        }
      }
    }

    final desiredKeys = desired.map((recipient) => recipient.key).toSet();
    for (final recipient in current) {
      if (!desiredKeys.contains(recipient.key)) {
        _flagRemoving(recipient.key);
      }
    }

    setState(() {
      _renderedRecipients = current;
    });
  }

  void _flagEntering(String key) {
    if (_enteringKeys.contains(key)) return;
    _enteringKeys.add(key);
    Future.delayed(chipsBarAnimationDuration, () {
      if (!mounted || !_enteringKeys.contains(key)) return;
      setState(() {
        _enteringKeys.remove(key);
      });
    });
  }

  void _flagRemoving(String key) {
    if (_removingKeys.contains(key)) return;
    _removingKeys.add(key);
    Future.delayed(chipsBarAnimationDuration, () {
      if (!mounted || !_removingKeys.remove(key)) return;
      setState(() {
        _renderedRecipients.removeWhere((recipient) => recipient.key == key);
      });
    });
  }

  bool _isRoomNick(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return false;
    return value.contains('/');
  }

  FanOutRecipientState? _statusFor(ComposerRecipient recipient) {
    final targetChat = recipient.target.chat;
    if (targetChat != null) {
      final byJid = widget.latestStatuses[targetChat.jid];
      if (byJid != null) {
        return byJid;
      }
      final emailKey = targetChat.emailAddress.normalizedJidKey;
      if (emailKey != null && emailKey.isNotEmpty) {
        final byEmail = widget.latestStatuses[emailKey];
        if (byEmail != null) {
          return byEmail;
        }
      }
    }
    final addressKey = recipient.target.address.normalizedJidKey;
    if (addressKey != null && addressKey.isNotEmpty) {
      return widget.latestStatuses[addressKey];
    }
    return null;
  }

  String? _extractDomain(String? raw) {
    final domain = addressDomainPart(raw)?.toLowerCase();
    return domain == null || domain.isEmpty ? null : domain;
  }

  String? _normalizeAddress(String? raw) {
    return normalizedAddressValue(raw);
  }

  bool _isOwnAddress(String? raw) {
    final normalized = _normalizeAddress(raw);
    final own = _ownNormalizedJid;
    return normalized != null && own != null && normalized == own;
  }

  Iterable<FanOutTarget> _autocompleteOptions(
    String raw,
    List<Chat> candidates,
    Set<String> knownDomains,
    Set<String> knownAddresses, {
    required bool shareTokenSignatureEnabled,
  }) {
    const maxSuggestions = 8;
    final knownAddressesLower = _knownAddressesLower;
    FanOutTarget chatTarget(Chat chat) => FanOutTarget.chat(
          chat: chat,
          shareSignatureEnabled:
              chat.shareSignatureEnabled ?? shareTokenSignatureEnabled,
        );
    FanOutTarget addressTarget(String address) => FanOutTarget.address(
          address: address,
          shareSignatureEnabled: shareTokenSignatureEnabled,
        );
    final trimmed = raw.trim();
    final query = trimmed.toLowerCase();
    final results = <FanOutTarget>[];
    final seen = <String>{};

    bool addTarget(FanOutTarget target) {
      final key = (target.chat?.jid ?? target.address ?? '').toLowerCase();
      if (key.isEmpty || seen.contains(key)) return false;
      results.add(target);
      seen.add(key);
      return results.length >= maxSuggestions;
    }

    if (query.isEmpty) {
      for (final chat in candidates) {
        if (addTarget(chatTarget(chat))) {
          return results;
        }
      }
      if (results.length < maxSuggestions) {
        for (final address in knownAddresses) {
          if (addTarget(addressTarget(address))) {
            return results;
          }
        }
      }
      return results;
    }

    for (final chat in candidates) {
      if (_chatMatchesQuery(chat, query) && addTarget(chatTarget(chat))) {
        if (results.length >= maxSuggestions) {
          return results;
        }
      }
    }

    for (final address in knownAddresses) {
      if (address.toLowerCase().startsWith(query) &&
          addTarget(addressTarget(address))) {
        if (results.length >= maxSuggestions) {
          return results;
        }
      }
    }

    final atIndex = trimmed.indexOf('@');
    if (atIndex > 0) {
      final localPart = trimmed.substring(0, atIndex).trim();
      final typedDomain = trimmed.substring(atIndex + 1).toLowerCase();
      if (localPart.isNotEmpty) {
        final normalizedLocal = localPart.toLowerCase();
        final domainEntries = knownDomains
            .map(
              (domain) => _DomainCompletion(
                domain: domain,
                hasExactAddress:
                    knownAddressesLower.contains('$normalizedLocal@$domain'),
              ),
            )
            .where(
              (entry) =>
                  typedDomain.isEmpty || entry.domain.startsWith(typedDomain),
            )
            .toList()
          ..sort((a, b) {
            if (a.hasExactAddress != b.hasExactAddress) {
              return a.hasExactAddress ? -1 : 1;
            }
            return a.domain.compareTo(b.domain);
          });
        for (final entry in domainEntries) {
          final suggestion = '$localPart@${entry.domain}';
          if (addTarget(addressTarget(suggestion))) {
            return results;
          }
        }
      }
    }

    return results;
  }

  bool _chatMatchesQuery(Chat chat, String query) {
    final title = chat.title.toLowerCase();
    final jid = chat.jid.toLowerCase();
    final email = chat.emailAddress?.toLowerCase() ?? '';
    final display = chat.contactDisplayName?.toLowerCase() ?? '';
    final remote = chat.remoteJid.toLowerCase();
    return title.startsWith(query) ||
        jid.startsWith(query) ||
        remote.startsWith(query) ||
        (email.isNotEmpty && email.startsWith(query)) ||
        (display.isNotEmpty && display.startsWith(query));
  }
}

class _DomainCompletion {
  const _DomainCompletion({
    required this.domain,
    required this.hasExactAddress,
  });

  final String domain;
  final bool hasExactAddress;
}

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({
    required this.recipient,
    required this.avatarPathsByJid,
    required this.onToggle,
    required this.onRemove,
    this.pendingRemoval = false,
    this.status,
  });

  final ComposerRecipient recipient;
  final Map<String, String> avatarPathsByJid;
  final VoidCallback onToggle;
  final VoidCallback? onRemove;
  final bool pendingRemoval;
  final FanOutRecipientState? status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final included = recipient.included;
    final colorfulAvatars = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.colorfulAvatars,
    );
    final baseBackground = _chipBackgroundColor(colors, colorfulAvatars);
    final baseForeground = _chipForegroundColor(colors, colorfulAvatars);
    final background = pendingRemoval
        ? colors.destructive
        : (included ? colors.primary : baseBackground);
    final foreground = pendingRemoval
        ? colors.destructiveForeground
        : (included ? colors.primaryForeground : baseForeground);
    final borderColor =
        pendingRemoval ? colors.destructive : context.borderSide.color;
    final borderSide = context.borderSide.copyWith(color: borderColor);
    final shape = RoundedSuperellipseBorder(
      borderRadius: context.radius,
      side: borderSide,
    );
    final removeButton = onRemove == null
        ? null
        : AxiIconButton.ghost(
            iconData: LucideIcons.x,
            onPressed: onRemove,
            color: foreground,
            iconSize: sizing.menuItemIconSize,
            buttonSize: sizing.menuItemHeight,
            tapTargetSize: sizing.menuItemHeight,
          );
    final content = DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: shape,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s,
          vertical: spacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RecipientChipAvatar(
              target: recipient.target,
              avatarPathsByJid: avatarPathsByJid,
              status: status,
            ),
            SizedBox(width: spacing.xs),
            Flexible(
              child: Text(
                _label(context),
                style: context.textTheme.small.copyWith(color: foreground),
              ),
            ),
            if (removeButton != null) ...[
              SizedBox(width: spacing.xs),
              removeButton,
            ],
          ],
        ),
      ),
    );
    return ShadFocusable(
      canRequestFocus: true,
      builder: (context, focused, child) => child ?? const SizedBox.shrink(),
      child: ShadGestureDetector(
        cursor: SystemMouseCursors.click,
        hoverStrategies: mobileHoverStrategies,
        onTap: onToggle,
        child: AxiTapBounce(child: content),
      ),
    );
  }

  String _label(BuildContext context) {
    if (recipient.target.chat != null) {
      return recipient.target.chat!.title;
    }
    return recipient.target.displayName ??
        recipient.target.address ??
        context.l10n.recipientsFallbackLabel;
  }

  Color _chipBackgroundColor(ShadColorScheme colors, bool colorfulAvatars) {
    return colorfulAvatars ? colors.secondary : colors.card;
  }

  Color _chipForegroundColor(ShadColorScheme colors, bool colorfulAvatars) {
    return colorfulAvatars
        ? colors.secondaryForeground
        : colors.mutedForeground;
  }
}

class _RecipientChipAvatar extends StatelessWidget {
  const _RecipientChipAvatar({
    required this.target,
    required this.avatarPathsByJid,
    this.status,
  });

  final FanOutTarget target;
  final Map<String, String> avatarPathsByJid;
  final FanOutRecipientState? status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final chat = target.chat;
    final avatarSize = sizing.iconButtonIconSize;
    final avatar = chat != null
        ? TransportAwareAvatar(
            chat: chat,
            size: avatarSize,
            showBadge: false,
          )
        : AxiAvatar(
            jid: target.address ?? target.displayName ?? '',
            size: avatarSize,
            avatarPath: avatarPathsByJid[
                (target.address ?? target.displayName ?? '').toLowerCase()],
          );
    final badgeIcon = _statusIcon(context, status, colors);
    if (badgeIcon == null) {
      return SizedBox.square(dimension: avatarSize, child: avatar);
    }
    final badgeBackground = colors.background;
    final badgeBorder = context.borderSide;
    final badgeSize = sizing.progressIndicatorSize;
    return SizedBox.square(
      dimension: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: avatar),
          Positioned(
            right: -spacing.xxs,
            bottom: -spacing.xxs,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: badgeBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: badgeBorder.color,
                  width: badgeBorder.width,
                ),
              ),
              child: Center(child: badgeIcon),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _statusIcon(
    BuildContext context,
    FanOutRecipientState? state,
    ShadColorScheme colors,
  ) =>
      switch (state) {
        FanOutRecipientState.failed => Icon(
            Icons.warning_amber_rounded,
            size: context.sizing.menuItemIconSize,
            color: colors.destructive,
          ),
        FanOutRecipientState.sent => Icon(
            Icons.check,
            size: context.sizing.menuItemIconSize,
            color: colors.primary,
          ),
        FanOutRecipientState.queued || FanOutRecipientState.sending => SizedBox(
            width: context.sizing.progressIndicatorSize,
            height: context.sizing.progressIndicatorSize,
            child: AxiProgressIndicator(color: colors.mutedForeground),
          ),
        null => null,
      };
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiButton.secondary(
      size: AxiButtonSize.sm,
      leading: Icon(icon, size: context.sizing.menuItemIconSize),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _AnimatedChipWrapper extends StatelessWidget {
  const _AnimatedChipWrapper({
    super.key,
    required this.child,
    this.isEntering = false,
    this.isRemoving = false,
  });

  final Widget child;
  final bool isEntering;
  final bool isRemoving;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final keyedChild = KeyedSubtree(key: key, child: child);
    final begin = isEntering ? 0.0 : 1.0;
    final end = isRemoving ? 0.0 : 1.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: begin, end: end),
      duration: chipsBarAnimationDuration,
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final clamped = value.clamp(0.0, 1.0);
        return Align(
          alignment: Alignment.centerLeft,
          widthFactor: clamped,
          heightFactor: clamped,
          child: Opacity(
            opacity: clamped,
            child: Transform.translate(
              offset: Offset(
                (1 - clamped) * (isRemoving ? spacing.m : -spacing.m),
                0,
              ),
              child: keyedChild,
            ),
          ),
        );
      },
    );
  }
}

class _RecipientAutocompleteField extends StatelessWidget {
  const _RecipientAutocompleteField({
    required this.controller,
    required this.focusNode,
    required this.tapRegionGroup,
    required this.fieldOuterPadding,
    required this.fieldInnerPadding,
    required this.backgroundColor,
    required this.avatarPathsByJid,
    required this.showSuggestionsWhenEmpty,
    required this.optionsBuilder,
    required this.highlightedIndexListenable,
    required this.onManualEntry,
    required this.onOptionsChanged,
    required this.onSubmitted,
    required this.onRecipientAdded,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Object tapRegionGroup;
  final double fieldOuterPadding;
  final double fieldInnerPadding;
  final Color backgroundColor;
  final Map<String, String> avatarPathsByJid;
  final bool showSuggestionsWhenEmpty;
  final Iterable<FanOutTarget> Function(String raw) optionsBuilder;
  final ValueListenable<int?> highlightedIndexListenable;
  final bool Function(String value) onManualEntry;
  final ValueChanged<List<FanOutTarget>> onOptionsChanged;
  final bool Function() onSubmitted;
  final ValueChanged<FanOutTarget> onRecipientAdded;

  @override
  Widget build(BuildContext context) {
    final double fieldHorizontalPadding =
        (fieldOuterPadding + fieldInnerPadding) * 2;
    final TextStyle textStyle = context.textTheme.p;
    return AutofillGroup(
      child: _RecipientAutocompleteFieldSizer(
        controller: controller,
        minWidth: context.sizing.iconButtonTapTarget,
        maxWidth: context.sizing.menuMaxWidth,
        horizontalPadding: fieldHorizontalPadding,
        textStyle: textStyle,
        child: _RecipientAutocompleteOverlay(
          controller: controller,
          focusNode: focusNode,
          tapRegionGroup: tapRegionGroup,
          fieldOuterPadding: fieldOuterPadding,
          fieldInnerPadding: fieldInnerPadding,
          backgroundColor: backgroundColor,
          avatarPathsByJid: avatarPathsByJid,
          showSuggestionsWhenEmpty: showSuggestionsWhenEmpty,
          optionsBuilder: optionsBuilder,
          highlightedIndexListenable: highlightedIndexListenable,
          onManualEntry: onManualEntry,
          onOptionsChanged: onOptionsChanged,
          onSubmitted: onSubmitted,
          onRecipientAdded: onRecipientAdded,
        ),
      ),
    );
  }
}

class _RecipientAutocompleteFieldSizer extends StatelessWidget {
  const _RecipientAutocompleteFieldSizer({
    required this.controller,
    required this.minWidth,
    required this.maxWidth,
    required this.horizontalPadding,
    required this.textStyle,
    required this.child,
  });

  final TextEditingController controller;
  final double minWidth;
  final double maxWidth;
  final double horizontalPadding;
  final TextStyle? textStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextStyle resolvedStyle =
        textStyle ?? DefaultTextStyle.of(context).style;
    final TextDirection textDirection = Directionality.of(context);
    final TextScaler textScaler = MediaQuery.textScalerOf(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final String text = value.text;
        final double measuredWidth = text.isEmpty
            ? minWidth
            : (TextPainter(
                  text: TextSpan(text: text, style: resolvedStyle),
                  textDirection: textDirection,
                  textScaler: textScaler,
                  maxLines: 1,
                )..layout())
                    .width +
                horizontalPadding;
        final double width = measuredWidth.clamp(minWidth, maxWidth).toDouble();
        return SizedBox(width: width, child: child);
      },
      child: child,
    );
  }
}

class _RecipientAutocompleteOverlay extends StatefulWidget {
  const _RecipientAutocompleteOverlay({
    required this.controller,
    required this.focusNode,
    required this.tapRegionGroup,
    required this.fieldOuterPadding,
    required this.fieldInnerPadding,
    required this.backgroundColor,
    required this.avatarPathsByJid,
    required this.showSuggestionsWhenEmpty,
    required this.optionsBuilder,
    required this.highlightedIndexListenable,
    required this.onManualEntry,
    required this.onOptionsChanged,
    required this.onSubmitted,
    required this.onRecipientAdded,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Object tapRegionGroup;
  final double fieldOuterPadding;
  final double fieldInnerPadding;
  final Color backgroundColor;
  final Map<String, String> avatarPathsByJid;
  final bool showSuggestionsWhenEmpty;
  final Iterable<FanOutTarget> Function(String raw) optionsBuilder;
  final ValueListenable<int?> highlightedIndexListenable;
  final bool Function(String value) onManualEntry;
  final ValueChanged<List<FanOutTarget>> onOptionsChanged;
  final bool Function() onSubmitted;
  final ValueChanged<FanOutTarget> onRecipientAdded;

  @override
  State<_RecipientAutocompleteOverlay> createState() =>
      _RecipientAutocompleteOverlayState();
}

final class _RecipientAutocompleteOverlayState
    extends State<_RecipientAutocompleteOverlay> {
  final GlobalKey _triggerKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _portalController = OverlayPortalController();
  late final _RecipientAutocompletePopEntry _popEntry =
      _RecipientAutocompletePopEntry(onPopRequested: () {
    if (!mounted) return;
    _dismissOverlay();
  });
  ModalRoute<void>? _popEntryRoute;

  List<FanOutTarget> _options = const <FanOutTarget>[];

  void _handleTapOutside() {
    if (!mounted) {
      return;
    }
    _dismissOverlay();
  }

  void _recomputeOptions() {
    final query = widget.controller.text.trim();
    final shouldBuildOptions =
        query.isNotEmpty || widget.showSuggestionsWhenEmpty;
    final next = shouldBuildOptions
        ? widget.optionsBuilder(query).toList(growable: false)
        : const <FanOutTarget>[];
    if (listEquals(_options, next)) return;
    setState(() => _options = next);
    widget.onOptionsChanged(next);
    _syncPortalVisibility();
  }

  void _handleFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _recomputeOptions();
    }
    _syncPortalVisibility();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensurePopEntryRegistered();
  }

  void _syncPortalVisibility() {
    final shouldShow = widget.focusNode.hasFocus &&
        (widget.controller.text.trim().isNotEmpty ||
            widget.showSuggestionsWhenEmpty) &&
        _options.isNotEmpty;
    if (shouldShow) {
      _popEntry.setCanPop(false);
      if (!_portalController.isShowing) {
        _portalController.show();
      }
    } else {
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      _popEntry.setCanPop(true);
      widget.onOptionsChanged(const <FanOutTarget>[]);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_recomputeOptions);
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _RecipientAutocompleteOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_recomputeOptions);
      widget.controller.addListener(_recomputeOptions);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_recomputeOptions);
    widget.focusNode.removeListener(_handleFocusChanged);
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    _unregisterPopEntry();
    _popEntry.dispose();
    super.dispose();
  }

  _AutocompleteOverlayLimits _overlayLimits(BuildContext overlayContext) {
    final spacing = overlayContext.spacing;
    final sizing = overlayContext.sizing;
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final triggerSize = triggerBox?.size ?? Size.zero;
    final overlayBox =
        Overlay.of(overlayContext).context.findRenderObject() as RenderBox?;
    final triggerOrigin = triggerBox != null && overlayBox != null
        ? triggerBox.localToGlobal(Offset.zero, ancestor: overlayBox)
        : (triggerBox?.localToGlobal(Offset.zero) ?? Offset.zero);

    final view = View.of(overlayContext);
    final viewPadding = EdgeInsets.fromViewPadding(
      view.padding,
      view.devicePixelRatio,
    );
    final viewInsets = EdgeInsets.fromViewPadding(
      view.viewInsets,
      view.devicePixelRatio,
    );
    final fallbackScreenSize = view.physicalSize / view.devicePixelRatio;
    final screenSize = overlayBox?.size ?? fallbackScreenSize;
    final topSafe = viewPadding.top;
    final bottomSafe = viewPadding.bottom;
    final keyboardInset = viewInsets.bottom;
    final visibleHeight = math.max(0.0, screenSize.height - keyboardInset);

    final desiredHeight = math.min(
      sizing.menuMaxHeight,
      _options.length * sizing.listButtonHeight,
    );
    final belowSpace = visibleHeight -
        (triggerOrigin.dy + triggerSize.height) -
        bottomSafe -
        spacing.m;
    final aboveSpace = triggerOrigin.dy - topSafe - spacing.m;
    final normalizedBelow = math.max(0.0, belowSpace);
    final normalizedAbove = math.max(0.0, aboveSpace);
    final belowHeight = math.min(desiredHeight, normalizedBelow);
    final aboveHeight = math.min(desiredHeight, normalizedAbove);
    final placeBelow = belowHeight >= aboveHeight;
    final maxHeight = placeBelow ? belowHeight : aboveHeight;

    final maxAllowedWidth = math.max(
      0.0,
      screenSize.width - spacing.m * 2,
    );
    final maxWidth = math.min(sizing.menuMaxWidth, maxAllowedWidth);
    final minWidth = math.min(sizing.menuMinWidth, maxWidth);

    final verticalOffset = placeBelow
        ? triggerSize.height + spacing.xs
        : -(maxHeight + spacing.xs);

    return _AutocompleteOverlayLimits(
      triggerOrigin: triggerOrigin,
      screenWidth: screenSize.width,
      horizontalMargin: spacing.m,
      verticalOffset: verticalOffset,
      maxHeight: maxHeight,
      minWidth: minWidth,
      maxWidth: maxWidth,
    );
  }

  double _computeOverlayWidth({
    required BuildContext overlayContext,
    required _AutocompleteOverlayLimits limits,
    required TextStyle? titleStyle,
    required TextStyle? subtitleStyle,
  }) {
    final spacing = overlayContext.spacing;
    final sizing = overlayContext.sizing;
    final fixedWidth = spacing.m * 2 +
        sizing.iconButtonSize +
        spacing.s +
        spacing.s +
        sizing.menuItemIconSize +
        spacing.s;

    final availableTextWidth = math.max(0.0, limits.maxWidth - fixedWidth);
    final direction = Directionality.of(overlayContext);
    final painter = TextPainter(
      textDirection: direction,
      maxLines: 1,
      ellipsis: '…',
    );

    double widestText = 0.0;
    for (final option in _options) {
      final chat = option.chat;
      final title = chat?.title ?? option.displayName ?? option.address ?? '';
      final subtitleSource = chat?.emailAddress ??
          chat?.jid ??
          option.address ??
          option.displayName ??
          '';
      final subtitle = subtitleSource.isEmpty || subtitleSource == title
          ? null
          : subtitleSource;

      painter
        ..text = TextSpan(text: title, style: titleStyle)
        ..layout(minWidth: 0, maxWidth: availableTextWidth);
      widestText = math.max(widestText, painter.width);
      if (widestText >= availableTextWidth) {
        break;
      }

      if (subtitle != null) {
        painter
          ..text = TextSpan(text: subtitle, style: subtitleStyle)
          ..layout(minWidth: 0, maxWidth: availableTextWidth);
        widestText = math.max(widestText, painter.width);
        if (widestText >= availableTextWidth) {
          break;
        }
      }
    }

    final idealWidth = fixedWidth + widestText;
    return idealWidth.clamp(limits.minWidth, limits.maxWidth).toDouble();
  }

  Offset _overlayOffsetForWidth({
    required _AutocompleteOverlayLimits limits,
    required double width,
  }) {
    double horizontalOffset = 0;
    final rightEdge = limits.triggerOrigin.dx + width;
    final maxRight = limits.screenWidth - limits.horizontalMargin;
    if (rightEdge > maxRight) {
      horizontalOffset = maxRight - rightEdge;
    }
    final adjustedLeft = limits.triggerOrigin.dx + horizontalOffset;
    if (adjustedLeft < limits.horizontalMargin) {
      horizontalOffset += limits.horizontalMargin - adjustedLeft;
    }
    return Offset(horizontalOffset, limits.verticalOffset);
  }

  void _dismissOverlay() {
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    _popEntry.setCanPop(true);
    widget.onOptionsChanged(const <FanOutTarget>[]);
  }

  void _ensurePopEntryRegistered() {
    final route = ModalRoute.of(context);
    if (_popEntryRoute == route) return;
    _popEntryRoute?.unregisterPopEntry(_popEntry);
    _popEntryRoute = route;
    _popEntryRoute?.registerPopEntry(_popEntry);
  }

  void _unregisterPopEntry() {
    _popEntryRoute?.unregisterPopEntry(_popEntry);
    _popEntryRoute = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final sizing = context.sizing;
    final textStyle = context.textTheme.p;

    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (overlayContext) {
          if (_options.isEmpty || !widget.focusNode.hasFocus) {
            return const SizedBox.shrink();
          }

          final limits = _overlayLimits(overlayContext);
          if (limits.maxHeight <= 0) {
            return const SizedBox.shrink();
          }
          final titleStyle = context.textTheme.p.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          );
          final subtitleStyle = context.textTheme.small.copyWith(
            color: colors.mutedForeground,
          );
          final dividerColor = context.borderSide.color;
          final overlayWidth = _computeOverlayWidth(
            overlayContext: overlayContext,
            limits: limits,
            titleStyle: titleStyle,
            subtitleStyle: subtitleStyle,
          );
          final overlayOffset = _overlayOffsetForWidth(
            limits: limits,
            width: overlayWidth,
          );

          return Stack(
            children: [
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: overlayOffset,
                child: InBoundsFadeScale(
                  child: TextFieldTapRegion(
                    groupId: widget.tapRegionGroup,
                    onTapOutside: (_) => _dismissOverlay(),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: limits.minWidth,
                          maxWidth: limits.maxWidth,
                          maxHeight: limits.maxHeight,
                        ),
                        child: SizedBox(
                          width: overlayWidth,
                          child: AxiModalSurface(
                            padding: EdgeInsets.zero,
                            child: Material(
                              color: Colors.transparent,
                              child: ValueListenableBuilder<int?>(
                                valueListenable:
                                    widget.highlightedIndexListenable,
                                builder: (context, highlightedIndex, _) {
                                  return _AutocompleteOptionsList(
                                    options: _options,
                                    avatarPathsByJid: widget.avatarPathsByJid,
                                    onSelected: (option) {
                                      widget.onRecipientAdded(option);
                                      widget.controller.clear();
                                      _recomputeOptions();
                                      widget.focusNode.requestFocus();
                                    },
                                    titleStyle: titleStyle,
                                    subtitleStyle: subtitleStyle,
                                    dividerColor: dividerColor,
                                    highlightedIndex: highlightedIndex,
                                    maxHeight: limits.maxHeight,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: TextFieldTapRegion(
          groupId: widget.tapRegionGroup,
          onTapOutside: (_) => _handleTapOutside(),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => widget.focusNode.requestFocus(),
            child: SizedBox(
              key: _triggerKey,
              height: sizing.listButtonHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.fieldOuterPadding,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(
                        sizing.containerRadius,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.fieldInnerPadding,
                        vertical: context.spacing.xs,
                      ),
                      child: AxiTextField(
                        controller: widget.controller,
                        groupId: widget.tapRegionGroup,
                        focusNode: widget.focusNode,
                        maxLines: 1,
                        keyboardType: TextInputType.emailAddress,
                        textCapitalization: TextCapitalization.none,
                        autocorrect: false,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        autofillHints: const [AutofillHints.email],
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        decoration: InputDecoration(
                          hintText: context.l10n.recipientsAddHint,
                          hintStyle: textStyle.copyWith(
                            color: colors.mutedForeground,
                          ),
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        strutStyle: StrutStyle.fromTextStyle(textStyle),
                        textInputAction: TextInputAction.done,
                        onEditingComplete: () =>
                            widget.focusNode.requestFocus(),
                        textAlignVertical: TextAlignVertical.center,
                        onSubmitted: (_) {
                          final handled = widget.onSubmitted();
                          if (!handled) {
                            final trimmed = widget.controller.text.trim();
                            if (trimmed.isNotEmpty &&
                                widget.onManualEntry(trimmed)) {
                              widget.controller.clear();
                              _dismissOverlay();
                            }
                          }
                          widget.focusNode.requestFocus();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientAutocompletePopEntry extends PopEntry<Object?> {
  _RecipientAutocompletePopEntry({required VoidCallback onPopRequested})
      : _onPopRequested = onPopRequested;

  final VoidCallback _onPopRequested;
  final ValueNotifier<bool> _canPopNotifier = ValueNotifier<bool>(true);

  void setCanPop(bool value) {
    if (_canPopNotifier.value == value) return;
    _canPopNotifier.value = value;
  }

  @override
  ValueListenable<bool> get canPopNotifier => _canPopNotifier;

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (_canPopNotifier.value) return;
    _onPopRequested();
  }

  void dispose() {
    _canPopNotifier.dispose();
  }
}

final class _AutocompleteOverlayLimits {
  const _AutocompleteOverlayLimits({
    required this.triggerOrigin,
    required this.screenWidth,
    required this.horizontalMargin,
    required this.verticalOffset,
    required this.maxHeight,
    required this.minWidth,
    required this.maxWidth,
  });

  final Offset triggerOrigin;
  final double screenWidth;
  final double horizontalMargin;
  final double verticalOffset;
  final double maxHeight;
  final double minWidth;
  final double maxWidth;
}

class _AutocompleteOptionsList extends StatefulWidget {
  const _AutocompleteOptionsList({
    required this.options,
    required this.avatarPathsByJid,
    required this.onSelected,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.dividerColor,
    required this.highlightedIndex,
    required this.maxHeight,
  });

  final List<FanOutTarget> options;
  final Map<String, String> avatarPathsByJid;
  final ValueChanged<FanOutTarget> onSelected;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color dividerColor;
  final int? highlightedIndex;
  final double maxHeight;

  @override
  State<_AutocompleteOptionsList> createState() =>
      _AutocompleteOptionsListState();
}

class _AutocompleteOptionsListState extends State<_AutocompleteOptionsList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final options = widget.options;
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    final tileHeight = sizing.listButtonHeight;
    final height = math.min(options.length * tileHeight, widget.maxHeight);
    final scrollable = options.length * tileHeight > height;
    return SizedBox(
      height: height,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: scrollable,
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          physics: scrollable
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemExtent: tileHeight,
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            final chat = option.chat;
            final title =
                chat?.title ?? option.displayName ?? option.address ?? '';
            final subtitleSource = chat?.emailAddress ??
                chat?.jid ??
                option.address ??
                option.displayName ??
                '';
            final subtitle = subtitleSource.isEmpty || subtitleSource == title
                ? null
                : subtitleSource;
            final border = index == options.length - 1
                ? BorderSide.none
                : BorderSide(
                    color: widget.dividerColor,
                    width: context.borderSide.width,
                  );
            final highlighted = widget.highlightedIndex != null &&
                widget.highlightedIndex == index;
            final optionContent = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: widget.titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: widget.subtitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            );
            return DecoratedBox(
              decoration: BoxDecoration(border: Border(bottom: border)),
              child: AxiListButton(
                selected: highlighted,
                onPressed: () => widget.onSelected(option),
                leading: _SuggestionAvatar(
                  option: option,
                  avatarPathsByJid: widget.avatarPathsByJid,
                ),
                trailing: Icon(
                  Icons.north_east,
                  size: sizing.menuItemIconSize,
                ),
                child: Padding(
                  padding: EdgeInsets.only(right: context.spacing.xs),
                  child: optionContent,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SuggestionAvatar extends StatelessWidget {
  const _SuggestionAvatar({
    required this.option,
    required this.avatarPathsByJid,
  });

  final FanOutTarget option;
  final Map<String, String> avatarPathsByJid;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    if (option.chat != null) {
      return TransportAwareAvatar(
        chat: option.chat!,
        size: sizing.iconButtonSize,
        showBadge: false,
      );
    }
    final address = option.address ?? option.chat?.emailAddress ?? '';
    final jid = address.isNotEmpty ? address : option.displayName ?? '';
    final avatarPath = avatarPathsByJid[jid.toLowerCase()];
    return AxiAvatar(
      jid: jid,
      size: sizing.iconButtonSize,
      avatarPath: avatarPath,
    );
  }
}
