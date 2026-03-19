// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/avatar/view/app_icon_avatar.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/compose_recipient.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/axi_editable_text.dart' as axi;
import 'package:axichat/src/common/ui/axi_surface_scope.dart';
import 'package:axichat/src/common/ui/buttons/axi_button_haptics.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
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
    this.databaseSuggestionAddresses = const <String>[],
    this.selfJid,
    required this.onRecipientAdded,
    required this.onRecipientToggled,
    required this.onRecipientRemoved,
    required this.latestStatuses,
    required this.selfIdentity,
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
  final List<String> databaseSuggestionAddresses;
  final String? selfJid;
  final ValueChanged<Contact> onRecipientAdded;
  final ValueChanged<String> onRecipientToggled;
  final ValueChanged<String> onRecipientRemoved;
  final Map<String, FanOutRecipientState> latestStatuses;
  final SelfAvatar selfIdentity;
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
  List<String> _databaseSuggestionAddresses = const [];
  bool _expanded = false;
  late bool _barCollapsed;
  bool _headerFocused = false;
  late List<ComposerRecipient> _renderedRecipients;
  final Set<String> _enteringKeys = <String>{};
  final Set<String> _removingKeys = <String>{};
  final Set<String> _revealedAddressKeys = <String>{};
  List<Contact> _suggestions = const <Contact>[];
  final ValueNotifier<int?> _highlightedSuggestionIndex = ValueNotifier<int?>(
    null,
  );
  String? _pendingRemovalKey;
  late final AnimationController _collapseController;
  late final Animation<double> _collapseAnimation;
  String? _ownNormalizedJid;
  List<RosterItem> _lastRosterItems = const <RosterItem>[];
  List<Chat> _lastAvailableChats = const <Chat>[];
  List<ComposerRecipient> _lastRecipients = const <ComposerRecipient>[];
  Map<String, String> _avatarPathsByJid = const <String, String>{};
  List<Chat> _availableAutocompleteChats = const <Chat>[];
  Set<String> _knownDomains = const <String>{};
  Set<String> _knownAddresses = const <String>{};
  Set<String> _knownAddressesLower = const <String>{};

  @override
  void initState() {
    super.initState();
    _tapRegionGroup = widget.tapRegionGroup ?? axi.EditableText;
    _focusNode.onKeyEvent = _handleKeyEvent;
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
    _focusNode.addListener(_handleFocusChanged);
    _lastRosterItems = List<RosterItem>.from(widget.rosterItems);
    _lastAvailableChats = List<Chat>.from(widget.availableChats);
    _lastRecipients = List<ComposerRecipient>.from(widget.recipients);
    _avatarPathsByJid = _computeAvatarPaths();
    _databaseSuggestionAddresses = widget.databaseSuggestionAddresses;
    final pools = _computeSuggestionPools();
    _availableAutocompleteChats = pools.availableChats;
    _knownDomains = pools.domains;
    _knownAddresses = pools.addresses;
    _knownAddressesLower = pools.addressesLower;
    _updateOwnJid(widget.selfJid);
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
      _tapRegionGroup = widget.tapRegionGroup ?? axi.EditableText;
    }
    if (oldWidget.collapsedByDefault != widget.collapsedByDefault) {
      _barCollapsed = widget.collapsedByDefault;
      _animateCollapse(_barCollapsed);
    }
    if (!listEquals(
      oldWidget.databaseSuggestionAddresses,
      widget.databaseSuggestionAddresses,
    )) {
      _databaseSuggestionAddresses = widget.databaseSuggestionAddresses;
    }
    if (oldWidget.selfJid != widget.selfJid) {
      _updateOwnJid(widget.selfJid);
    }
    _syncRenderedRecipients();
    _prunePendingRemoval();
    _pruneRevealedAddresses();
    _refreshAvatarPaths();
    _refreshSuggestionPools();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    _highlightedSuggestionIndex.dispose();
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
            selfIdentity: widget.selfIdentity,
            showAddress: _revealedAddressKeys.contains(recipient.key),
            status: _statusFor(recipient),
            pendingRemoval: _pendingRemovalKey == recipient.key,
            onToggle: () => _toggleRecipientLabel(recipient.key),
            onRemove: recipient.pinned
                ? null
                : () => _removeRecipient(recipient.key),
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

    final barBackground = chipsBarBackground(context, colors);
    final availableAutocompleteChats = _availableAutocompleteChats;
    final knownDomains = _knownDomains;
    final knownAddresses = _knownAddresses;
    const double autocompleteFieldOuterPadding = 8.0;
    const double autocompleteFieldInnerPadding = 12.0;
    final spacing = context.spacing;
    final headerPadding = EdgeInsets.symmetric(
      horizontal: spacing.m,
      vertical: spacing.s,
    );
    final contentPadding = EdgeInsets.symmetric(
      horizontal: spacing.m,
      vertical: spacing.s,
    );
    final headerStyle = chipsBarHeaderTextStyle(context);
    final normalizedVisibilityLabel = widget.visibilityLabel?.trim() ?? '';
    final showVisibilityBadge = normalizedVisibilityLabel.isNotEmpty;
    final arrowIcon = _barCollapsed
        ? Icons.keyboard_arrow_down
        : Icons.keyboard_arrow_up;
    final shareTokenSignatureEnabled = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.shareTokenSignatureEnabled,
    );
    return ChipsBarSurface(
      backgroundColor: barBackground,
      padding: EdgeInsets.zero,
      borderSide: BorderSide(color: context.colorScheme.border, width: 1),
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
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleBarCollapsed,
                  child: AnimatedContainer(
                    duration: chipsBarAnimationDuration,
                    curve: Curves.easeInOutCubic,
                    padding: headerPadding,
                    decoration: BoxDecoration(
                      border: _headerFocused
                          ? Border.all(color: colors.primary, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: chipsBarAnimationDuration,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Icon(
                            arrowIcon,
                            key: ValueKey<bool>(_barCollapsed),
                            size: 18,
                            color: colors.mutedForeground,
                          ),
                        ),
                        SizedBox(width: spacing.xxs),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                fit: FlexFit.loose,
                                child: Text(
                                  l10n.recipientsHeaderTitle.toUpperCase(),
                                  style: headerStyle,
                                ),
                              ),
                              if (recipients.isNotEmpty) ...[
                                SizedBox(width: spacing.m),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: _RecipientsAvatarStrip(
                                    recipients: recipients,
                                    avatarPathsByJid: avatarPathsByJid,
                                    backgroundColor: barBackground,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (showVisibilityBadge) ...[
                          Container(
                            padding: chipsBarBadgePadding,
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(
                                chipsBarHeaderBadgeRadius,
                              ),
                              border: Border.all(
                                color: context.colorScheme.border,
                              ),
                            ),
                            child: Text(
                              normalizedVisibilityLabel,
                              style: headerStyle.copyWith(
                                fontSize: chipsBarHeaderBadgeFontSize,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: spacing.s),
                        ],
                        SizedBox(width: spacing.s),
                        ChipsBarCountBadge(
                          count: recipients.length,
                          expanded: !_barCollapsed,
                          colors: colors,
                        ),
                      ],
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
                  padding: contentPadding,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...chips,
                      _AnimatedChipWrapper(
                        key: const ValueKey('autocomplete-field'),
                        child: _RecipientAutocompleteField(
                          controller: _controller,
                          focusNode: _focusNode,
                          tapRegionGroup: _tapRegionGroup,
                          fieldOuterPadding: autocompleteFieldOuterPadding,
                          fieldInnerPadding: autocompleteFieldInnerPadding,
                          backgroundColor: barBackground,
                          avatarPathsByJid: avatarPathsByJid,
                          selfIdentity: widget.selfIdentity,
                          showSuggestionsWhenEmpty:
                              widget.showSuggestionsWhenEmpty,
                          optionsBuilder: (raw) => _autocompleteOptions(
                            raw,
                            availableAutocompleteChats,
                            knownDomains,
                            knownAddresses,
                            shareTokenSignatureEnabled:
                                shareTokenSignatureEnabled,
                            excludedKeys: _recipientNormalizedKeys(),
                          ),
                          highlightedIndexListenable:
                              _highlightedSuggestionIndex,
                          onManualEntry: _handleManualEntry,
                          onOptionsChanged: _updateSuggestions,
                          onSubmitted: _handleAutocompleteSubmit,
                          onRecipientAdded: _handleRecipientAdded,
                        ),
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

  Map<String, String> _computeAvatarPaths() {
    final next = <String, String>{};
    void addAvatar(String? key, String? source) {
      final normalizedKey = key?.trim().toLowerCase();
      final normalizedPath = source?.trim();
      if (normalizedKey == null ||
          normalizedKey.isEmpty ||
          normalizedPath == null ||
          normalizedPath.isEmpty) {
        return;
      }
      next[normalizedKey] = normalizedPath;
    }

    for (final item in widget.rosterItems) {
      addAvatar(item.jid, item.avatarPath ?? item.contactAvatarPath);
    }
    for (final chat in widget.availableChats) {
      final path = chat.effectiveAvatarPath;
      for (final key in chat.identityAddresses) {
        addAvatar(key, path);
      }
    }
    for (final recipient in widget.recipients) {
      final path = recipient.target.effectiveAvatarPath;
      for (final key in recipient.target.identityAddresses) {
        addAvatar(key, path);
      }
    }
    return next;
  }

  void _refreshAvatarPaths() {
    final rosterItems = widget.rosterItems;
    final availableChats = widget.availableChats;
    final recipients = widget.recipients;
    if (listEquals(rosterItems, _lastRosterItems) &&
        listEquals(availableChats, _lastAvailableChats) &&
        listEquals(recipients, _lastRecipients)) {
      return;
    }
    _lastRosterItems = List<RosterItem>.from(rosterItems);
    _lastAvailableChats = List<Chat>.from(availableChats);
    _lastRecipients = List<ComposerRecipient>.from(recipients);
    final next = _computeAvatarPaths();
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
  })
  _computeSuggestionPools() {
    final allowAddressTargets = widget.allowAddressTargets;
    final hiddenAddresses = widget.availableChats
        .where((chat) => chat.hidden)
        .expand((chat) => chat.identityAddresses)
        .map(_normalizeAddress)
        .whereType<String>()
        .toSet();
    final availableChats = widget.availableChats
        .where((chat) => !chat.hidden)
        .where((chat) => !chat.isAxichatWelcomeThread)
        .toList(growable: false);
    final recipients = widget.recipients;
    final nextAvailable = availableChats
        .where(
          (chat) => !recipients.any(
            (recipient) => recipient.target.matchesChatJid(chat.jid),
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
        if (_isWelcomeThreadAddress(address)) return;
        final normalized = _normalizeAddress(address);
        if (normalized != null && hiddenAddresses.contains(normalized)) return;
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
        for (final address in chat.identityAddresses) {
          addDomainFrom(address);
        }
      }
      for (final recipient in recipients) {
        for (final address in recipient.target.identityAddresses) {
          addDomainFrom(address);
        }
      }

      final addresses = <String>{}
        ..addAll(widget.suggestionAddresses)
        ..addAll(
          _databaseSuggestionAddresses.where((address) {
            final normalized = _normalizeAddress(address);
            return normalized == null || !hiddenAddresses.contains(normalized);
          }),
        );
      void addAddress(String? raw) {
        final value = raw?.trim();
        if (value == null || value.isEmpty) return;
        if (_isRoomNick(value)) return;
        if (_isOwnAddress(value)) return;
        if (_isWelcomeThreadAddress(value)) return;
        final normalized = _normalizeAddress(value);
        if (normalized != null && hiddenAddresses.contains(normalized)) return;
        addresses.add(value);
      }

      for (final chat in availableChats) {
        for (final address in chat.identityAddresses) {
          addAddress(address);
        }
      }
      for (final recipient in recipients) {
        for (final address in recipient.target.identityAddresses) {
          addAddress(address);
        }
      }
      nextDomains = domains;
      nextAddresses = addresses;
    }
    final lowerAddresses = nextAddresses
        .map((address) => address.toLowerCase())
        .toSet();
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
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      return _moveAutocompleteHighlight(1);
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      return _moveAutocompleteHighlight(-1);
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _handleAutocompleteSubmit();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controller.text.isEmpty) {
      _handleBackspacePress();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _handleManualEntry(String value) {
    if (!widget.allowAddressTargets) {
      return false;
    }
    if (!isValidAddress(value)) {
      return false;
    }
    if (_isRoomNick(value)) {
      return false;
    }
    if (_isOwnAddress(value)) {
      return false;
    }
    if (_isWelcomeThreadAddress(value)) {
      return false;
    }
    _handleRecipientAdded(
      Contact.address(
        address: value,
        shareSignatureEnabled: context
            .read<SettingsCubit>()
            .state
            .shareTokenSignatureEnabled,
      ),
    );
    return true;
  }

  void _updateSuggestions(List<Contact> suggestions) {
    _suggestions = suggestions;
    _highlightedSuggestionIndex.value = null;
  }

  void _handleTextChanged() {
    if (_pendingRemovalKey != null && _controller.text.isNotEmpty) {
      _clearPendingRemoval();
    }
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      return;
    }
    if (_controller.text.trim().isEmpty) {
      return;
    }
    _handleAutocompleteSubmit();
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
      _updateSuggestions(const <Contact>[]);
      return true;
    }
    if (text.isEmpty) {
      return false;
    }
    if (_handleManualEntry(text)) {
      _controller.clear();
      _updateSuggestions(const <Contact>[]);
      return true;
    }
    return false;
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

  void _pruneRevealedAddresses() {
    final validKeys = widget.recipients
        .map((recipient) => recipient.key)
        .toSet();
    _revealedAddressKeys.removeWhere((key) => !validKeys.contains(key));
  }

  void _removeRecipient(String key) {
    if (_pendingRemovalKey == key) {
      _clearPendingRemoval();
    }
    widget.onRecipientRemoved(key);
  }

  void _toggleRecipientLabel(String key) {
    _clearPendingRemoval();
    setState(() {
      if (!_revealedAddressKeys.add(key)) {
        _revealedAddressKeys.remove(key);
      }
    });
  }

  List<ComposerRecipient> _removableRecipients() =>
      widget.recipients.where((recipient) => !recipient.pinned).toList();

  void _handleRecipientAdded(Contact target) {
    _clearPendingRemoval();
    widget.onRecipientAdded(target);
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
    if (next) {
      _focusNode.unfocus();
    }
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
    for (final key in recipient.target.statusLookupKeys) {
      final status = widget.latestStatuses[key];
      if (status != null) {
        return status;
      }
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

  bool _isWelcomeThreadAddress(String? raw) {
    final bare = bareAddress(raw) ?? raw?.trim();
    return isAxichatWelcomeThreadJid(bare);
  }

  Iterable<Contact> _autocompleteOptions(
    String raw,
    List<Chat> candidates,
    Set<String> knownDomains,
    Set<String> knownAddresses, {
    required bool shareTokenSignatureEnabled,
    required Set<String> excludedKeys,
  }) {
    const maxSuggestions = 8;
    final knownAddressesLower = _knownAddressesLower;
    Contact chatTarget(Chat chat) => Contact.chat(
      chat: chat,
      shareSignatureEnabled:
          chat.shareSignatureEnabled ?? shareTokenSignatureEnabled,
    );
    Contact addressTarget(String address) => Contact.address(
      address: address,
      shareSignatureEnabled: shareTokenSignatureEnabled,
    );
    final trimmed = raw.trim();
    final query = trimmed.toLowerCase();
    final results = <Contact>[];
    final seen = <String>{};

    bool addTarget(Contact target) {
      final rawKey = target.recipientId ?? target.resolvedAddress;
      final normalizedKey = _normalizeAddress(rawKey);
      if (normalizedKey == null ||
          normalizedKey.isEmpty ||
          seen.contains(normalizedKey) ||
          excludedKeys.contains(normalizedKey)) {
        return false;
      }
      results.add(target);
      seen.add(normalizedKey);
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

    final parts = addressAutocompleteParts(trimmed);
    if (parts != null) {
      final localPart = parts.localPart;
      final typedDomain = parts.domainPart.toLowerCase();
      final normalizedLocal = localPart.toLowerCase();
      final domainEntries =
          knownDomains
              .map(
                (domain) => _DomainCompletion(
                  domain: domain,
                  hasExactAddress: knownAddressesLower.contains(
                    '$normalizedLocal@$domain',
                  ),
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

    return results;
  }

  Set<String> _recipientNormalizedKeys() {
    final keys = <String>{};
    for (final recipient in widget.recipients) {
      keys.addAll(recipient.target.normalizedIdentityKeys);
    }
    return keys;
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
    required this.selfIdentity,
    required this.showAddress,
    required this.onToggle,
    required this.onRemove,
    this.pendingRemoval = false,
    this.status,
  });

  final ComposerRecipient recipient;
  final Map<String, String> avatarPathsByJid;
  final SelfAvatar selfIdentity;
  final bool showAddress;
  final VoidCallback onToggle;
  final VoidCallback? onRemove;
  final bool pendingRemoval;
  final FanOutRecipientState? status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final included = recipient.included;
    final colorfulAvatars = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.colorfulAvatars,
    );
    final baseColor = _chipColor(colors, colorfulAvatars);
    final overlayOpacity = included ? 0.78 : 0.32;
    final background = Color.alphaBlend(
      baseColor.withValues(alpha: overlayOpacity),
      colors.card,
    );
    final foreground = included
        ? _foregroundColor(background, colors)
        : colors.foreground;
    final accentColor = baseColor.withValues(alpha: 1);
    final removalColor = colors.destructive;
    final effectiveBackground = pendingRemoval
        ? Color.alphaBlend(removalColor.withValues(alpha: 0.12), background)
        : background;
    final effectiveForeground = pendingRemoval ? removalColor : foreground;
    final borderColor = pendingRemoval
        ? removalColor
        : (included ? accentColor : Colors.transparent);

    return _SquircleChipButton(
      backgroundColor: effectiveBackground,
      foregroundColor: effectiveForeground,
      borderColor: borderColor,
      borderWidth: pendingRemoval || included ? 1.1 : 0,
      elevation: included ? 1.5 : 0,
      shadowColor: colors.foreground.withValues(alpha: 0.18),
      onPressed: onToggle,
      selected: false,
      semanticLabel: _label(context),
      padding: EdgeInsets.symmetric(horizontal: spacing.s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RecipientChipAvatar(
            target: recipient.target,
            avatarPathsByJid: avatarPathsByJid,
            selfIdentity: selfIdentity,
            status: status,
          ),
          SizedBox(width: spacing.xxs),
          Flexible(
            child: Text(
              _label(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRemove != null) SizedBox(width: spacing.xxs),
          if (onRemove != null)
            _RecipientChipDeleteButton(
              color: effectiveForeground,
              onPressed: onRemove!,
            ),
        ],
      ),
    );
  }

  String _label(BuildContext context) {
    if (showAddress) {
      return recipient.target.jid;
    }
    final displayName = recipient.target.displayName.trim();
    return displayName.isNotEmpty
        ? displayName
        : context.l10n.recipientsFallbackLabel;
  }

  Color _chipColor(ShadColorScheme colors, bool colorfulAvatars) {
    if (!colorfulAvatars) {
      return colors.secondary;
    }
    return stringToColor(recipient.target.colorSeed);
  }

  Color _foregroundColor(Color background, ShadColorScheme scheme) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    if (brightness == Brightness.dark) return Colors.white;
    if (brightness == Brightness.light) return scheme.foreground;
    return scheme.foreground;
  }
}

class _RecipientChipAvatar extends StatelessWidget {
  const _RecipientChipAvatar({
    required this.target,
    required this.avatarPathsByJid,
    required this.selfIdentity,
    this.status,
  });

  final Contact target;
  final Map<String, String> avatarPathsByJid;
  final SelfAvatar selfIdentity;
  final FanOutRecipientState? status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final chat = target.chat;
    const double avatarSize = 20.0;
    final avatar = chat != null
        ? (() {
            final avatarData = chat.avatarPresentation(
              selfAvatar: selfIdentity,
              avatarOverride: Avatar.tryParseOrNull(
                path: _avatarPathForChat(chat),
                hash: null,
              ),
            );
            if (avatarData.isAppIcon) {
              return const AxichatAppIconAvatar(size: avatarSize);
            }
            return HydratedAxiAvatar(
              avatar: avatarData,
              size: avatarSize,
              shape: AxiAvatarShape.squircle,
            );
          })()
        : HydratedAxiAvatar(
            avatar: AvatarPresentation.avatar(
              label: target.recipientId ?? '',
              colorSeed: target.recipientId ?? '',
              avatar: Avatar.tryParseOrNull(
                path: _avatarPathForContact(target),
                hash: null,
              ),
              loading: false,
            ),
            size: avatarSize,
            shape: AxiAvatarShape.squircle,
          );
    final badgeIcon = _statusIcon(status, colors);
    if (badgeIcon == null) {
      return SizedBox.square(dimension: avatarSize, child: avatar);
    }
    const double badgeSize = 12.0;
    const double badgeBorderWidth = 1.5;
    final badgeBackground = colors.card;
    final badgeBorder = colors.card;
    return SizedBox.square(
      dimension: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: avatar),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: badgeBackground,
                shape: BoxShape.circle,
                border: Border.all(color: badgeBorder, width: badgeBorderWidth),
              ),
              child: Center(child: badgeIcon),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _statusIcon(FanOutRecipientState? state, ShadColorScheme colors) {
    const double statusBadgeSize = 12.0;
    return switch (state) {
      FanOutRecipientState.failed => Icon(
        Icons.warning_amber_rounded,
        size: statusBadgeSize - 2,
        color: colors.destructive,
      ),
      FanOutRecipientState.sent => null,
      FanOutRecipientState.queued || FanOutRecipientState.sending => SizedBox(
        width: statusBadgeSize - 2,
        height: statusBadgeSize - 2,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.mutedForeground,
        ),
      ),
      null => null,
    };
  }

  String? _avatarPathForKey(String? key) {
    final normalized = key?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    return avatarPathsByJid[normalized];
  }

  String? _avatarPathForChat(Chat chat) {
    for (final key in chat.identityAddresses) {
      final entry = _avatarPathForKey(key);
      if (entry != null) {
        return entry;
      }
    }
    return null;
  }

  String? _avatarPathForContact(Contact contact) {
    for (final key in contact.identityAddresses) {
      final entry = _avatarPathForKey(key);
      if (entry != null) {
        return entry;
      }
    }
    return null;
  }
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
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final foreground = colors.mutedForeground;
    return _SquircleChipButton(
      backgroundColor: Color.alphaBlend(
        colors.primary.withValues(alpha: 0.05),
        colors.card,
      ),
      foregroundColor: foreground,
      onPressed: onPressed,
      semanticLabel: label,
      padding: EdgeInsets.symmetric(horizontal: spacing.s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          SizedBox(width: spacing.xxs),
          Text(label),
        ],
      ),
    );
  }
}

class _RecipientChipDeleteButton extends StatelessWidget {
  const _RecipientChipDeleteButton({
    required this.color,
    required this.onPressed,
  });

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final spacing = context.spacing;
    final iconButtonExtent = sizing.iconButtonTapTarget / 2;
    return AxiIconButton.ghost(
      iconData: Icons.close,
      iconSize: sizing.iconButtonIconSize - spacing.xxs,
      buttonSize: iconButtonExtent,
      tapTargetSize: iconButtonExtent,
      cornerRadius: context.radii.squircleSm,
      color: color,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
      semanticLabel: MaterialLocalizations.of(context).deleteButtonTooltip,
      onPressed: onPressed,
    );
  }
}

class _SquircleChipButton extends StatefulWidget {
  const _SquircleChipButton({
    required this.child,
    required this.backgroundColor,
    required this.foregroundColor,
    this.onPressed,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0,
    this.elevation = 0,
    this.shadowColor,
    this.selected = false,
    this.semanticLabel,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final Color borderColor;
  final double borderWidth;
  final double elevation;
  final Color? shadowColor;
  final bool selected;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  State<_SquircleChipButton> createState() => _SquircleChipButtonState();
}

class _SquircleChipButtonState extends State<_SquircleChipButton> {
  final AxiTapBounceController _bounceController = AxiTapBounceController();
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  void _setFocused(bool value) {
    if (_focused == value) {
      return;
    }
    setState(() => _focused = value);
  }

  @override
  Widget build(BuildContext context) {
    final Duration animationDuration = context.select<SettingsCubit, Duration>(
      (cubit) => cubit.animationDuration,
    );
    final bool enabled = widget.onPressed != null;
    final VoidCallback? onTap = enabled
        ? withSelectionHaptic(widget.onPressed)
        : null;
    final bool emphasized = _hovered || _focused;
    final Color hoverBackground = Color.alphaBlend(
      context.colorScheme.primary.withValues(
        alpha: context.motion.tapHoverAlpha,
      ),
      widget.backgroundColor,
    );
    final Color pressedBackground = Color.alphaBlend(
      context.colorScheme.primary.withValues(
        alpha: context.motion.tapSplashAlpha,
      ),
      hoverBackground,
    );
    final Color resolvedBackground = _pressed
        ? pressedBackground
        : (emphasized ? hoverBackground : widget.backgroundColor);
    final RoundedSuperellipseBorder shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
      side: widget.borderWidth > 0
          ? BorderSide(color: widget.borderColor, width: widget.borderWidth)
          : BorderSide.none,
    );

    Widget child = Material(
      color: resolvedBackground,
      shape: shape,
      elevation: widget.elevation,
      shadowColor: widget.shadowColor,
      clipBehavior: Clip.antiAlias,
      child: ShadFocusable(
        canRequestFocus: enabled,
        onFocusChange: enabled ? _setFocused : null,
        builder: (context, focused, child) => child ?? const SizedBox.shrink(),
        child: ShadGestureDetector(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          behavior: HitTestBehavior.opaque,
          hoverStrategies: ShadTheme.of(context).hoverStrategies,
          onHoverChange: enabled ? _setHovered : null,
          onTap: onTap,
          onTapDown: enabled
              ? (details) {
                  _setPressed(true);
                  _bounceController.handleTapDown(details);
                }
              : null,
          onTapUp: enabled
              ? (details) {
                  _setPressed(false);
                  _bounceController.handleTapUp(details);
                }
              : null,
          onTapCancel: enabled
              ? () {
                  _setPressed(false);
                  _bounceController.handleTapCancel();
                }
              : null,
          onLongPressStart: enabled
              ? (_) {
                  _setPressed(true);
                  _bounceController.setPressed(true);
                }
              : null,
          onLongPressEnd: enabled
              ? (_) {
                  _setPressed(false);
                  _bounceController.setPressed(false);
                }
              : null,
          child: IconTheme.merge(
            data: IconThemeData(color: widget.foregroundColor),
            child: DefaultTextStyle(
              style: context.textTheme.small.copyWith(
                color: widget.foregroundColor,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: chipsBarHeight),
                child: Padding(padding: widget.padding, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );

    if (enabled) {
      child = AxiTapBounce(
        controller: _bounceController,
        enabled: animationDuration != Duration.zero,
        scale: context.motion.buttonCompactBounceScale,
        pressDuration: Duration(
          milliseconds:
              (animationDuration.inMilliseconds *
                      context.motion.buttonPressDurationFactor)
                  .round(),
        ),
        releaseDuration: Duration(
          milliseconds:
              (animationDuration.inMilliseconds *
                      context.motion.buttonReleaseDurationFactor)
                  .round(),
        ),
        child: child,
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      onTap: onTap,
      child: child,
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
              offset: Offset((1 - clamped) * (isRemoving ? 12 : -12), 0),
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
    required this.selfIdentity,
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
  final SelfAvatar selfIdentity;
  final bool showSuggestionsWhenEmpty;
  final Iterable<Contact> Function(String raw) optionsBuilder;
  final ValueListenable<int?> highlightedIndexListenable;
  final bool Function(String value) onManualEntry;
  final ValueChanged<List<Contact>> onOptionsChanged;
  final bool Function() onSubmitted;
  final ValueChanged<Contact> onRecipientAdded;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
        child: _RecipientAutocompleteOverlay(
          controller: controller,
          focusNode: focusNode,
          tapRegionGroup: tapRegionGroup,
          fieldOuterPadding: fieldOuterPadding,
          fieldInnerPadding: fieldInnerPadding,
          backgroundColor: backgroundColor,
          avatarPathsByJid: avatarPathsByJid,
          selfIdentity: selfIdentity,
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

class _RecipientAutocompleteOverlay extends StatefulWidget {
  const _RecipientAutocompleteOverlay({
    required this.controller,
    required this.focusNode,
    required this.tapRegionGroup,
    required this.fieldOuterPadding,
    required this.fieldInnerPadding,
    required this.backgroundColor,
    required this.avatarPathsByJid,
    required this.selfIdentity,
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
  final SelfAvatar selfIdentity;
  final bool showSuggestionsWhenEmpty;
  final Iterable<Contact> Function(String raw) optionsBuilder;
  final ValueListenable<int?> highlightedIndexListenable;
  final bool Function(String value) onManualEntry;
  final ValueChanged<List<Contact>> onOptionsChanged;
  final bool Function() onSubmitted;
  final ValueChanged<Contact> onRecipientAdded;

  @override
  State<_RecipientAutocompleteOverlay> createState() =>
      _RecipientAutocompleteOverlayState();
}

final class _RecipientAutocompleteOverlayState
    extends State<_RecipientAutocompleteOverlay>
    with AxiSurfaceRegistration<_RecipientAutocompleteOverlay> {
  static const double _overlayGap = 6;
  static const double _overlayMargin = 8;
  static const double _overlayHorizontalMargin = 16;
  static const double _overlayPreferredMaxWidth = 420;
  static const double _overlayPreferredMinWidth = 180;
  static const double _suggestionMaxHeight = 360;
  static const double _suggestionTileHeight = 64;

  final GlobalKey _triggerKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _portalController = OverlayPortalController();

  List<Contact> _options = const <Contact>[];

  @override
  bool get isAxiSurfaceOpen => _portalController.isShowing;

  @override
  VoidCallback? get onAxiSurfaceDismiss => () {
    _dismissOverlay();
    widget.focusNode.unfocus();
  };

  void _showOverlayPortal() {
    if (_portalController.isShowing) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _portalController.isShowing) {
        return;
      }
      _portalController.show();
      syncAxiSurfaceRegistration();
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _hideOverlayPortal() {
    if (!_portalController.isShowing) {
      return;
    }
    _portalController.hide();
    syncAxiSurfaceRegistration();
    if (mounted) {
      setState(() {});
    }
  }

  void _recomputeOptions() {
    final query = widget.controller.text.trim();
    final next = query.isEmpty && !widget.showSuggestionsWhenEmpty
        ? const <Contact>[]
        : widget.optionsBuilder(query).toList(growable: false);
    if (listEquals(_options, next)) return;
    setState(() => _options = next);
    widget.onOptionsChanged(next);
    _syncPortalVisibility();
  }

  void _syncPortalVisibility() {
    final shouldShow =
        widget.focusNode.hasFocus &&
        (widget.controller.text.trim().isNotEmpty ||
            widget.showSuggestionsWhenEmpty) &&
        _options.isNotEmpty;
    if (shouldShow) {
      _showOverlayPortal();
    } else {
      _hideOverlayPortal();
      widget.onOptionsChanged(const <Contact>[]);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_recomputeOptions);
    widget.focusNode.addListener(_syncPortalVisibility);
    _recomputeOptions();
  }

  @override
  void didUpdateWidget(covariant _RecipientAutocompleteOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_recomputeOptions);
      widget.controller.addListener(_recomputeOptions);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_syncPortalVisibility);
      widget.focusNode.addListener(_syncPortalVisibility);
    }
    _recomputeOptions();
    syncAxiSurfaceRegistration(notify: false);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_recomputeOptions);
    widget.focusNode.removeListener(_syncPortalVisibility);
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    super.dispose();
  }

  _AutocompleteOverlayLimits _overlayLimits(BuildContext overlayContext) {
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
      _suggestionMaxHeight,
      _options.length * _suggestionTileHeight,
    );
    final belowSpace =
        visibleHeight -
        (triggerOrigin.dy + triggerSize.height) -
        bottomSafe -
        _overlayMargin;
    final aboveSpace = triggerOrigin.dy - topSafe - _overlayMargin;

    final normalizedBelow = math.max(0.0, belowSpace);
    final normalizedAbove = math.max(0.0, aboveSpace);

    final belowHeight = math.min(desiredHeight, normalizedBelow);
    final aboveHeight = math.min(desiredHeight, normalizedAbove);
    final placeBelow = belowHeight >= aboveHeight;
    final maxHeight = placeBelow ? belowHeight : aboveHeight;

    final maxAllowedWidth = math.max(
      0.0,
      screenSize.width - _overlayHorizontalMargin * 2,
    );
    final maxWidth = math.min(_overlayPreferredMaxWidth, maxAllowedWidth);
    final minWidth = math.min(_overlayPreferredMinWidth, maxWidth);

    final verticalOffset = placeBelow
        ? triggerSize.height + _overlayGap
        : -(maxHeight + _overlayGap);

    return _AutocompleteOverlayLimits(
      triggerOrigin: triggerOrigin,
      screenWidth: screenSize.width,
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
    const double tileHorizontalPadding = 14.0 * 2;
    const double avatarSize = 32.0;
    const double gapAfterAvatar = 12.0;
    const double gapBeforeTrailingIcon = 12.0;
    const double trailingIconSize = 16.0;
    const double extraTextBreathingRoom = 8.0;
    const double fixedWidth =
        tileHorizontalPadding +
        avatarSize +
        gapAfterAvatar +
        gapBeforeTrailingIcon +
        trailingIconSize +
        extraTextBreathingRoom;

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
      final title = chat?.title ?? option.displayName;
      final subtitleSource =
          chat?.emailAddress ??
          chat?.jid ??
          option.address ??
          option.displayName;
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
    final maxRight = limits.screenWidth - _overlayHorizontalMargin;
    if (rightEdge > maxRight) {
      horizontalOffset = maxRight - rightEdge;
    }
    final adjustedLeft = limits.triggerOrigin.dx + horizontalOffset;
    if (adjustedLeft < _overlayHorizontalMargin) {
      horizontalOffset += _overlayHorizontalMargin - adjustedLeft;
    }
    return Offset(horizontalOffset, limits.verticalOffset);
  }

  void _dismissOverlay() {
    _hideOverlayPortal();
    widget.onOptionsChanged(const <Contact>[]);
  }

  void _handleOutsideTap() {
    if (widget.controller.text.trim().isNotEmpty) {
      widget.onSubmitted();
    }
    widget.focusNode.unfocus();
    _dismissOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final hintColor = colors.mutedForeground.withValues(alpha: 0.8);
    final textStyle = context.textTheme.p;
    final Widget child = CompositedTransformTarget(
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

          final overlayColors = overlayContext.colorScheme;
          final overlayTextTheme = overlayContext.textTheme;
          final overlayRadius = BorderRadius.circular(20);
          final titleStyle = overlayTextTheme.p.copyWith(
            fontWeight: FontWeight.w600,
            color: overlayColors.foreground,
          );
          final subtitleStyle = overlayTextTheme.small.copyWith(
            color: overlayColors.mutedForeground,
          );
          final dividerColor = overlayColors.border.withValues(alpha: 0.55);
          final hoverColor = overlayColors.muted.withValues(alpha: 0.08);
          final highlightColor = overlayColors.primary.withValues(alpha: 0.12);
          final trailingIconColor = overlayColors.muted.withValues(alpha: 0.9);
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
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _handleOutsideTap,
                ),
              ),
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: overlayOffset,
                child: TapRegion(
                  groupId: widget.tapRegionGroup,
                  onTapOutside: (_) => _handleOutsideTap(),
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
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: overlayColors.card,
                            borderRadius: overlayRadius,
                            border: Border.all(
                              color: overlayColors.border.withValues(
                                alpha: 0.9,
                              ),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 28,
                                offset: const Offset(0, 18),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: overlayRadius,
                            child: Material(
                              color: Colors.transparent,
                              child: ValueListenableBuilder<int?>(
                                valueListenable:
                                    widget.highlightedIndexListenable,
                                builder: (context, highlightedIndex, _) {
                                  return _AutocompleteOptionsList(
                                    options: _options,
                                    avatarPathsByJid: widget.avatarPathsByJid,
                                    selfIdentity: widget.selfIdentity,
                                    onSelected: (option) {
                                      widget.onRecipientAdded(option);
                                      widget.controller.clear();
                                      _recomputeOptions();
                                      widget.focusNode.requestFocus();
                                    },
                                    titleStyle: titleStyle,
                                    subtitleStyle: subtitleStyle,
                                    dividerColor: dividerColor,
                                    trailingIconColor: trailingIconColor,
                                    hoverColor: hoverColor,
                                    highlightColor: highlightColor,
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
        child: TapRegion(
          groupId: widget.tapRegionGroup,
          onTapOutside: (_) => _handleOutsideTap(),
          child: SizedBox(
            key: _triggerKey,
            height: chipsBarHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.fieldOuterPadding,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: widget.backgroundColor,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(
                        context.radii.squircle,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.fieldInnerPadding,
                    ),
                    child: AxiTextField(
                      groupId: widget.tapRegionGroup,
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      maxLines: 1,
                      keyboardType: TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\\s')),
                      ],
                      decoration: InputDecoration(
                        hintText: context.l10n.recipientsAddHint,
                        hintStyle: textStyle.copyWith(color: hintColor),
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: textStyle,
                      cursorHeight: textStyle.fontSize,
                      textInputAction: TextInputAction.go,
                      onEditingComplete: () => widget.focusNode.requestFocus(),
                      textAlignVertical: TextAlignVertical.center,
                      onSubmitted: (_) {
                        final handled = widget.onSubmitted();
                        if (!handled) {
                          final trimmed = widget.controller.text.trim();
                          if (trimmed.isNotEmpty &&
                              widget.onManualEntry(trimmed)) {
                            widget.controller.clear();
                            _recomputeOptions();
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
    );
    if (AxiSurfaceScope.maybeControllerOf(context) != null) {
      return child;
    }
    final canPop = !_portalController.isShowing;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || canPop) {
          return;
        }
        _dismissOverlay();
        widget.focusNode.unfocus();
      },
      child: child,
    );
  }
}

final class _AutocompleteOverlayLimits {
  const _AutocompleteOverlayLimits({
    required this.triggerOrigin,
    required this.screenWidth,
    required this.verticalOffset,
    required this.maxHeight,
    required this.minWidth,
    required this.maxWidth,
  });

  final Offset triggerOrigin;
  final double screenWidth;
  final double verticalOffset;
  final double maxHeight;
  final double minWidth;
  final double maxWidth;
}

class _AutocompleteOptionsList extends StatefulWidget {
  const _AutocompleteOptionsList({
    required this.options,
    required this.avatarPathsByJid,
    required this.selfIdentity,
    required this.onSelected,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.dividerColor,
    required this.trailingIconColor,
    required this.hoverColor,
    required this.highlightColor,
    required this.highlightedIndex,
    required this.maxHeight,
  });

  final List<Contact> options;
  final Map<String, String> avatarPathsByJid;
  final SelfAvatar selfIdentity;
  final ValueChanged<Contact> onSelected;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color dividerColor;
  final Color trailingIconColor;
  final Color hoverColor;
  final Color highlightColor;
  final int? highlightedIndex;
  final double maxHeight;

  @override
  State<_AutocompleteOptionsList> createState() =>
      _AutocompleteOptionsListState();
}

class _AutocompleteOptionsListState extends State<_AutocompleteOptionsList> {
  static const double _suggestionTileHeight = 64;
  final ScrollController _scrollController = ScrollController();
  int? _hoveredIndex;

  void _updateHoveredIndex({required int index, required bool hovering}) {
    if (hovering) {
      if (_hoveredIndex == index) {
        return;
      }
      setState(() {
        _hoveredIndex = index;
      });
      return;
    }
    if (_hoveredIndex != index) {
      return;
    }
    setState(() {
      _hoveredIndex = null;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    final height = math.min(
      options.length * _suggestionTileHeight,
      widget.maxHeight,
    );
    final scrollable = options.length * _suggestionTileHeight > height;
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
          itemExtent: _suggestionTileHeight,
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            final chat = option.chat;
            final title = chat?.title ?? option.displayName;
            final subtitleSource =
                chat?.emailAddress ??
                chat?.jid ??
                option.address ??
                option.displayName;
            final subtitle = subtitleSource.isEmpty || subtitleSource == title
                ? null
                : subtitleSource;
            final border = index == options.length - 1
                ? BorderSide.none
                : BorderSide(color: widget.dividerColor, width: 0.7);
            final highlighted =
                widget.highlightedIndex != null &&
                widget.highlightedIndex == index;
            final hovered = _hoveredIndex == index;
            final Color? rowColor = highlighted
                ? widget.highlightColor
                : hovered
                ? widget.hoverColor
                : null;
            return InkWell(
              onTap: () => widget.onSelected(option),
              onHover: (hovering) =>
                  _updateHoveredIndex(index: index, hovering: hovering),
              mouseCursor: SystemMouseCursors.click,
              hoverColor: widget.hoverColor,
              child: Container(
                decoration: BoxDecoration(
                  color: rowColor,
                  border: Border(bottom: border),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _SuggestionAvatar(
                      option: option,
                      avatarPathsByJid: widget.avatarPathsByJid,
                      selfIdentity: widget.selfIdentity,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.north_east,
                      size: 16,
                      color: widget.trailingIconColor,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RecipientsAvatarStrip extends StatelessWidget {
  const _RecipientsAvatarStrip({
    required this.recipients,
    required this.avatarPathsByJid,
    required this.backgroundColor,
  });

  final List<ComposerRecipient> recipients;
  final Map<String, String> avatarPathsByJid;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (recipients.isEmpty) {
      return const SizedBox.shrink();
    }
    final participants = <String>[];
    for (final recipient in recipients) {
      final jid = recipient.target.recipientId ?? recipient.key;
      if (jid.isEmpty) continue;
      participants.add(jid);
    }
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }
    return _CaterpillarAvatarStrip(
      participants: participants,
      avatarPathsByJid: avatarPathsByJid,
      backgroundColor: backgroundColor,
    );
  }
}

class _CaterpillarAvatarStrip extends StatelessWidget {
  const _CaterpillarAvatarStrip({
    required this.participants,
    required this.avatarPathsByJid,
    required this.backgroundColor,
  });

  final List<String> participants;
  final Map<String, String> avatarPathsByJid;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final recipientAvatarSize = spacing.m;
        final recipientAvatarOverlap = spacing.xs;
        final recipientOverflowGap = spacing.xs;
        final maxWidth =
            constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutRecipientStrip(
          context: context,
          participants: participants,
          maxContentWidth: maxWidth,
        );
        final visible = layout.items;
        final overflowed = layout.overflowed;
        final children = <Widget>[];
        for (var i = 0; i < visible.length; i++) {
          final offset = i * (recipientAvatarSize - recipientAvatarOverlap);
          children.add(
            Positioned(
              left: offset,
              child: _RecipientHeaderAvatar(
                jid: visible[i],
                avatarPath: avatarPathsByJid[visible[i].toLowerCase()],
                backgroundColor: backgroundColor,
              ),
            ),
          );
        }
        if (overflowed) {
          final offset = visible.isEmpty
              ? 0.0
              : visible.length *
                        (recipientAvatarSize - recipientAvatarOverlap) +
                    recipientOverflowGap;
          children.add(
            Positioned(
              left: offset,
              child: _RecipientOverflowAvatar(backgroundColor: backgroundColor),
            ),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + recipientOverflowGap + recipientAvatarSize
            : math.max(baseWidth, recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: recipientAvatarSize,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }
}

_CutoutLayoutResult<String> _layoutRecipientStrip({
  required BuildContext context,
  required List<String> participants,
  required double maxContentWidth,
}) {
  if (participants.isEmpty || maxContentWidth <= 0) {
    return const _CutoutLayoutResult(
      items: <String>[],
      overflowed: false,
      totalWidth: 0,
    );
  }
  final spacing = context.spacing;
  final recipientAvatarSize = spacing.m;
  final recipientAvatarOverlap = spacing.xs;
  final visible = <String>[];
  final additions = <double>[];
  double used = 0;

  for (final participant in participants) {
    final addition = visible.isEmpty
        ? recipientAvatarSize
        : recipientAvatarSize - recipientAvatarOverlap;
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
        ? recipientAvatarSize
        : recipientAvatarSize - recipientAvatarOverlap;
    while (visible.isNotEmpty && totalWidth + ellipsisWidth > maxContentWidth) {
      totalWidth -= additions.removeLast();
      visible.removeLast();
      ellipsisWidth = visible.isEmpty
          ? recipientAvatarSize
          : recipientAvatarSize - recipientAvatarOverlap;
    }
    if (visible.isEmpty) {
      totalWidth = math.min(ellipsisWidth, maxContentWidth);
    } else {
      totalWidth = math.min(maxContentWidth, totalWidth + ellipsisWidth);
    }
  }

  return _CutoutLayoutResult(
    items: visible,
    overflowed: truncated,
    totalWidth: totalWidth,
  );
}

class _CutoutLayoutResult<T> {
  const _CutoutLayoutResult({
    required this.items,
    required this.overflowed,
    required this.totalWidth,
  });

  final List<T> items;
  final bool overflowed;
  final double totalWidth;
}

class _RecipientOverflowAvatar extends StatelessWidget {
  const _RecipientOverflowAvatar({required this.backgroundColor});

  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final recipientAvatarSize = spacing.m;
    return SizedBox(
      width: recipientAvatarSize,
      height: recipientAvatarSize,
      child: Center(
        child: Text(
          context.l10n.commonEllipsis,
          style: context.textTheme.small
              .copyWith(
                fontWeight: FontWeight.w700,
                color: context.colorScheme.mutedForeground,
                height: 1,
              )
              .apply(leadingDistribution: TextLeadingDistribution.even),
        ),
      ),
    );
  }
}

class _RecipientHeaderAvatar extends StatelessWidget {
  const _RecipientHeaderAvatar({
    required this.jid,
    required this.backgroundColor,
    this.avatarPath,
  });

  final String jid;
  final Color backgroundColor;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final borderWidth = context.borderSide.width;
    final spacing = context.spacing;
    final recipientAvatarSize = spacing.m;
    final shape = SquircleBorder(cornerRadius: context.radii.squircle);
    return Container(
      width: recipientAvatarSize,
      height: recipientAvatarSize,
      padding: EdgeInsets.all(borderWidth),
      decoration: ShapeDecoration(color: backgroundColor, shape: shape),
      child: HydratedAxiAvatar(
        avatar: AvatarPresentation.avatar(
          label: jid,
          colorSeed: jid,
          avatar: Avatar.tryParseOrNull(path: avatarPath, hash: null),
          loading: false,
        ),
        size: recipientAvatarSize - (borderWidth * 2),
      ),
    );
  }
}

class _SuggestionAvatar extends StatelessWidget {
  const _SuggestionAvatar({
    required this.option,
    required this.avatarPathsByJid,
    required this.selfIdentity,
  });

  final Contact option;
  final Map<String, String> avatarPathsByJid;
  final SelfAvatar selfIdentity;

  @override
  Widget build(BuildContext context) {
    if (option.chat != null) {
      final chat = option.chat!;
      final avatarData = chat.avatarPresentation(selfAvatar: selfIdentity);
      if (avatarData.isAppIcon) {
        return const AxichatAppIconAvatar(size: 32);
      }
      return HydratedAxiAvatar(
        avatar: avatarData,
        size: 32,
        shape: AxiAvatarShape.squircle,
      );
    }
    final jid = option.recipientId ?? '';
    String? avatarPath;
    for (final key in option.identityAddresses) {
      final normalized = key.trim().toLowerCase();
      if (normalized.isEmpty) {
        continue;
      }
      final entry = avatarPathsByJid[normalized];
      if (entry != null) {
        avatarPath = entry;
        break;
      }
    }
    return HydratedAxiAvatar(
      avatar: AvatarPresentation.avatar(
        label: jid,
        colorSeed: jid,
        avatar: Avatar.tryParseOrNull(path: avatarPath, hash: null),
        loading: false,
      ),
      size: 32,
      shape: AxiAvatarShape.squircle,
    );
  }
}
