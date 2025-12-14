import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/endpoint_config.dart';
import 'package:axichat/src/common/ui/axi_avatar.dart';
import 'package:axichat/src/common/ui/string_to_color.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _chipHeight = 36.0;
const Duration _chipMotionDuration = Duration(milliseconds: 320);
const Curve _chipMotionCurve = Curves.easeInOutCubic;
const Duration _barAnimationDuration = Duration(milliseconds: 360);
const int _maxAutocompleteSuggestions = 8;
const double _suggestionTileHeight = 56;
const double _suggestionMaxHeight = 320;
const double _expandedHeaderPadding = 4;
const double _chipAvatarSize = 20.0;
const double _chipStatusBadgeSize = 12.0;
const double _chipStatusBadgeBorderWidth = 1.5;
const EdgeInsetsGeometry _recipientChipPadding = EdgeInsetsDirectional.fromSTEB(
  4,
  0,
  8,
  0,
);
const EdgeInsets _recipientChipLabelPadding =
    EdgeInsets.symmetric(horizontal: 2);

class RecipientChipsBar extends StatefulWidget {
  const RecipientChipsBar({
    super.key,
    required this.recipients,
    required this.availableChats,
    required this.onRecipientAdded,
    required this.onRecipientToggled,
    required this.onRecipientRemoved,
    required this.latestStatuses,
    this.collapsedByDefault = false,
    this.suggestionAddresses = const <String>{},
    this.suggestionDomains = const <String>{},
    this.horizontalPadding = 16,
  });

  final List<ComposerRecipient> recipients;
  final List<Chat> availableChats;
  final ValueChanged<FanOutTarget> onRecipientAdded;
  final ValueChanged<String> onRecipientToggled;
  final ValueChanged<String> onRecipientRemoved;
  final Map<String, FanOutRecipientState> latestStatuses;
  final bool collapsedByDefault;
  final Set<String> suggestionAddresses;
  final Set<String> suggestionDomains;
  final double horizontalPadding;

  @override
  State<RecipientChipsBar> createState() => _RecipientChipsBarState();
}

class _RecipientChipsBarState extends State<RecipientChipsBar>
    with SingleTickerProviderStateMixin {
  static const _collapsedVisibleCount = 4;

  final Object _autocompleteTapRegionGroup = Object();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _expanded = false;
  late bool _barCollapsed;
  bool _headerFocused = false;
  late List<ComposerRecipient> _renderedRecipients;
  final Set<String> _enteringKeys = <String>{};
  final Set<String> _removingKeys = <String>{};
  List<FanOutTarget> _suggestions = const <FanOutTarget>[];
  final ValueNotifier<int?> _highlightedSuggestionIndex =
      ValueNotifier<int?>(null);
  String? _pendingRemovalKey;
  late final AnimationController _collapseController;
  late final Animation<double> _collapseAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode
      ..onKeyEvent = _handleKeyEvent
      ..addListener(_handleAutocompleteFocusChanged);
    _renderedRecipients = _visibleRecipientsForState();
    _barCollapsed = widget.collapsedByDefault;
    _collapseController = AnimationController(
      vsync: this,
      duration: _barAnimationDuration,
      value: _barCollapsed ? 0 : 1,
    );
    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOutCubic,
    );
    _controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant RecipientChipsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapsedByDefault != widget.collapsedByDefault) {
      _barCollapsed = widget.collapsedByDefault;
      _animateCollapse(_barCollapsed);
    }
    _syncRenderedRecipients();
    _prunePendingRemoval();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _highlightedSuggestionIndex.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _collapseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final recipients = widget.recipients;
    final rosterItems =
        (context.watch<RosterCubit?>()?.cache['items'] as List<RosterItem>?) ??
            const <RosterItem>[];
    final avatarPathsByJid = <String, String>{};
    for (final item in rosterItems) {
      final path = item.avatarPath?.trim();
      if (path == null || path.isEmpty) continue;
      avatarPathsByJid[item.jid.toLowerCase()] = path;
    }
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

    final barBackground = _containerBackground(colors);
    final availableAutocompleteChats = widget.availableChats
        .where(
          (chat) => !widget.recipients
              .any((recipient) => recipient.target.chat?.jid == chat.jid),
        )
        .toList();
    final knownDomains = _knownDomains();
    final knownAddresses = _knownAddresses();
    final headerPadding = EdgeInsets.symmetric(
      horizontal: widget.horizontalPadding,
      vertical: _expandedHeaderPadding,
    );
    final bodyPadding =
        EdgeInsets.symmetric(horizontal: widget.horizontalPadding);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: colors.onSurfaceVariant.withValues(alpha: 0.9),
      letterSpacing: 0.4,
    );
    final arrowIcon =
        _barCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up;
    return AnimatedContainer(
      duration: _barAnimationDuration,
      curve: Curves.easeInOutCubic,
      width: double.infinity,
      decoration: BoxDecoration(
        color: barBackground,
        border: Border(
          top: BorderSide(color: context.colorScheme.border, width: 1),
        ),
      ),
      padding: bodyPadding,
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
                    duration: _barAnimationDuration,
                    curve: Curves.easeInOutCubic,
                    padding: headerPadding,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: _headerFocused
                          ? Border.all(
                              color: colors.primary,
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.recipientsHeaderTitle,
                            style: headerStyle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RecipientsCountBadge(
                          count: recipients.length,
                          expanded: !_barCollapsed,
                          colors: colors,
                        ),
                        const SizedBox(width: 4),
                        AnimatedSwitcher(
                          duration: _barAnimationDuration,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Icon(
                            arrowIcon,
                            key: ValueKey<bool>(_barCollapsed),
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
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
                duration: _barAnimationDuration,
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                          tapRegionGroup: _autocompleteTapRegionGroup,
                          backgroundColor: barBackground,
                          avatarPathsByJid: avatarPathsByJid,
                          optionsBuilder: (raw) => _autocompleteOptions(
                            raw,
                            availableAutocompleteChats,
                            knownDomains,
                            knownAddresses,
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

  Color _containerBackground(ColorScheme colors) {
    final overlay = colors.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : colors.primary.withValues(alpha: 0.07);
    return Color.alphaBlend(overlay, colors.surfaceContainerHigh);
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
    if (!_looksLikeEmail(value)) {
      return false;
    }
    _handleRecipientAdded(FanOutTarget.address(address: value));
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
    Future.delayed(_chipMotionDuration, () {
      if (!mounted || !_enteringKeys.contains(key)) return;
      setState(() {
        _enteringKeys.remove(key);
      });
    });
  }

  void _flagRemoving(String key) {
    if (_removingKeys.contains(key)) return;
    _removingKeys.add(key);
    Future.delayed(_chipMotionDuration, () {
      if (!mounted || !_removingKeys.remove(key)) return;
      setState(() {
        _renderedRecipients.removeWhere((recipient) => recipient.key == key);
      });
    });
  }

  Set<String> _knownDomains() {
    final domains = <String>{EndpointConfig.defaultDomain}
      ..addAll(widget.suggestionDomains);
    void addFrom(String? address) {
      final domain = _extractDomain(address);
      if (domain != null) {
        domains.add(domain);
      }
    }

    for (final suggestion in widget.suggestionAddresses) {
      addFrom(suggestion);
    }

    for (final chat in widget.availableChats) {
      addFrom(chat.emailAddress);
      addFrom(chat.jid);
      addFrom(chat.remoteJid);
    }
    for (final recipient in widget.recipients) {
      final target = recipient.target;
      addFrom(target.chat?.emailAddress ?? target.address);
      addFrom(target.chat?.jid);
      addFrom(target.chat?.remoteJid);
    }
    return domains;
  }

  Set<String> _knownAddresses() {
    final addresses = <String>{}..addAll(widget.suggestionAddresses);
    void add(String? raw) {
      final value = raw?.trim();
      if (value == null || value.isEmpty) return;
      addresses.add(value);
    }

    for (final chat in widget.availableChats) {
      add(chat.emailAddress);
      add(chat.jid);
      add(chat.remoteJid);
    }
    for (final recipient in widget.recipients) {
      final target = recipient.target;
      add(target.address);
      add(target.chat?.jid);
      add(target.chat?.emailAddress);
      add(target.chat?.remoteJid);
    }
    return addresses;
  }

  FanOutRecipientState? _statusFor(ComposerRecipient recipient) {
    final targetChat = recipient.target.chat;
    if (targetChat != null) {
      final byJid = widget.latestStatuses[targetChat.jid];
      if (byJid != null) {
        return byJid;
      }
      final emailKey = targetChat.emailAddress?.trim().toLowerCase();
      if (emailKey != null && emailKey.isNotEmpty) {
        final byEmail = widget.latestStatuses[emailKey];
        if (byEmail != null) {
          return byEmail;
        }
      }
    }
    final addressKey = recipient.target.address?.trim().toLowerCase();
    if (addressKey != null && addressKey.isNotEmpty) {
      return widget.latestStatuses[addressKey];
    }
    return null;
  }

  String? _extractDomain(String? raw) {
    final address = raw?.trim();
    if (address == null || address.isEmpty || !address.contains('@')) {
      return null;
    }
    final parts = address.split('@');
    if (parts.length != 2) return null;
    final domain = parts.last.trim().toLowerCase();
    if (domain.isEmpty) return null;
    return domain;
  }

  Iterable<FanOutTarget> _autocompleteOptions(
    String raw,
    List<Chat> candidates,
    Set<String> knownDomains,
    Set<String> knownAddresses,
  ) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const Iterable<FanOutTarget>.empty();
    }
    final query = trimmed.toLowerCase();
    final results = <FanOutTarget>[];
    final seen = <String>{};

    bool addTarget(FanOutTarget target) {
      final key = (target.chat?.jid ?? target.address ?? '').toLowerCase();
      if (key.isEmpty || seen.contains(key)) return false;
      results.add(target);
      seen.add(key);
      return results.length >= _maxAutocompleteSuggestions;
    }

    if (query.isEmpty) {
      for (final chat in candidates) {
        if (addTarget(FanOutTarget.chat(chat))) {
          break;
        }
      }
      if (results.length < _maxAutocompleteSuggestions) {
        for (final address in knownAddresses) {
          if (addTarget(FanOutTarget.address(address: address))) {
            break;
          }
        }
      }
      return results;
    }

    for (final chat in candidates) {
      if (_chatMatchesQuery(chat, query) &&
          addTarget(FanOutTarget.chat(chat))) {
        if (results.length >= _maxAutocompleteSuggestions) {
          return results;
        }
      }
    }

    for (final address in knownAddresses) {
      if (address.toLowerCase().startsWith(query) &&
          addTarget(FanOutTarget.address(address: address))) {
        if (results.length >= _maxAutocompleteSuggestions) {
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
                hasExactAddress: knownAddresses.any(
                  (address) =>
                      address.toLowerCase() == '$normalizedLocal@$domain',
                ),
              ),
            )
            .where(
              (entry) =>
                  typedDomain.isEmpty || entry.domain.startsWith(typedDomain),
            )
            .toList()
          ..sort(
            (a, b) {
              if (a.hasExactAddress != b.hasExactAddress) {
                return a.hasExactAddress ? -1 : 1;
              }
              return a.domain.compareTo(b.domain);
            },
          );
        for (final entry in domainEntries) {
          final suggestion = '$localPart@${entry.domain}';
          if (addTarget(FanOutTarget.address(address: suggestion))) {
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
    final colors = Theme.of(context).colorScheme;
    final included = recipient.included;
    final colorfulAvatars = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.colorfulAvatars,
    );
    final baseColor = _chipColor(context, colorfulAvatars);
    final overlayOpacity = included ? 0.78 : 0.32;
    final background = Color.alphaBlend(
      baseColor.withValues(alpha: overlayOpacity),
      colors.surface,
    );
    final foreground =
        included ? _foregroundColor(background, colors) : colors.onSurface;
    final accentColor = baseColor.withValues(alpha: 1);
    final removalColor = colors.error;
    final effectiveBackground = pendingRemoval
        ? Color.alphaBlend(removalColor.withValues(alpha: 0.12), background)
        : background;
    final effectiveForeground = pendingRemoval ? removalColor : foreground;
    final borderColor = pendingRemoval
        ? removalColor
        : (included ? accentColor : Colors.transparent);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _chipHeight),
      child: InputChip(
        shape: const StadiumBorder(),
        showCheckmark: false,
        avatar: _RecipientChipAvatar(
          target: recipient.target,
          avatarPathsByJid: avatarPathsByJid,
          status: status,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(_label(context))),
          ],
        ),
        onPressed: onToggle,
        selected: included,
        backgroundColor: effectiveBackground,
        selectedColor: effectiveBackground,
        labelStyle: TextStyle(color: effectiveForeground),
        deleteIcon: onRemove == null
            ? null
            : Icon(
                Icons.close,
                size: 16,
                color: effectiveForeground,
              ),
        onDeleted: onRemove,
        side: BorderSide(
          color: borderColor,
          width: pendingRemoval || included ? 1.1 : 0,
        ),
        elevation: included ? 1.5 : 0,
        shadowColor: colors.shadow,
        selectedShadowColor: colors.shadow,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: _recipientChipPadding,
        labelPadding: _recipientChipLabelPadding,
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

  Color _chipColor(BuildContext context, bool colorfulAvatars) {
    if (!colorfulAvatars) {
      return Theme.of(context).colorScheme.secondary;
    }
    final seed =
        recipient.target.chat?.jid ?? recipient.target.address ?? recipient.key;
    return stringToColor(seed);
  }

  Color _foregroundColor(Color background, ColorScheme scheme) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    if (brightness == Brightness.dark) return Colors.white;
    if (brightness == Brightness.light) return scheme.onSurface;
    return scheme.onSurface;
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
    final colors = Theme.of(context).colorScheme;
    final chat = target.chat;
    final avatar = chat != null
        ? TransportAwareAvatar(
            chat: chat,
            size: _chipAvatarSize,
            showBadge: false,
          )
        : AxiAvatar(
            jid: target.address ?? target.displayName ?? '',
            size: _chipAvatarSize,
            shape: AxiAvatarShape.circle,
            avatarPath: avatarPathsByJid[
                (target.address ?? target.displayName ?? '').toLowerCase()],
          );
    final badgeIcon = _statusIcon(status, colors);
    if (badgeIcon == null) {
      return SizedBox.square(dimension: _chipAvatarSize, child: avatar);
    }
    final badgeBackground = colors.surface;
    final badgeBorder = colors.surface;
    return SizedBox.square(
      dimension: _chipAvatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: avatar),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: _chipStatusBadgeSize,
              height: _chipStatusBadgeSize,
              decoration: BoxDecoration(
                color: badgeBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: badgeBorder,
                  width: _chipStatusBadgeBorderWidth,
                ),
              ),
              child: Center(child: badgeIcon),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _statusIcon(FanOutRecipientState? state, ColorScheme colors) =>
      switch (state) {
        FanOutRecipientState.failed => Icon(
            Icons.warning_amber_rounded,
            size: _chipStatusBadgeSize - 2,
            color: colors.error,
          ),
        FanOutRecipientState.sent => Icon(
            Icons.check,
            size: _chipStatusBadgeSize - 2,
            color: colors.primary,
          ),
        FanOutRecipientState.queued || FanOutRecipientState.sending => SizedBox(
            width: _chipStatusBadgeSize - 2,
            height: _chipStatusBadgeSize - 2,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.onSurfaceVariant,
            ),
          ),
        null => null,
      };
}

class _RecipientsCountBadge extends StatelessWidget {
  const _RecipientsCountBadge({
    required this.count,
    required this.expanded,
    required this.colors,
  });

  final int count;
  final bool expanded;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final background =
        expanded ? colors.primary : colors.primary.withValues(alpha: 0.09);
    final foreground = expanded ? colors.onPrimary : colors.primary;
    return AnimatedContainer(
      duration: _barAnimationDuration,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
          letterSpacing: 0.4,
        ),
      ),
    );
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
    final colors = Theme.of(context).colorScheme;
    final foreground = colors.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _chipHeight),
      child: ActionChip(
        shape: const StadiumBorder(),
        avatar: Icon(icon, size: 14, color: foreground),
        label: Text(
          label,
          style: TextStyle(color: foreground),
        ),
        onPressed: onPressed,
        backgroundColor: Color.alphaBlend(
          colors.primary.withValues(alpha: 0.05),
          colors.surface,
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        side: BorderSide.none,
      ),
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
      duration: _chipMotionDuration,
      curve: _chipMotionCurve,
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
    required this.backgroundColor,
    required this.avatarPathsByJid,
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
  final Color backgroundColor;
  final Map<String, String> avatarPathsByJid;
  final Iterable<FanOutTarget> Function(String raw) optionsBuilder;
  final ValueListenable<int?> highlightedIndexListenable;
  final bool Function(String value) onManualEntry;
  final ValueChanged<List<FanOutTarget>> onOptionsChanged;
  final bool Function() onSubmitted;
  final ValueChanged<FanOutTarget> onRecipientAdded;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
      child: RawAutocomplete<FanOutTarget>(
        textEditingController: controller,
        focusNode: focusNode,
        optionsBuilder: (value) {
          final query = value.text.trim();
          if (query.isEmpty) {
            onOptionsChanged(const <FanOutTarget>[]);
            return const Iterable<FanOutTarget>.empty();
          }
          final options = optionsBuilder(query).toList(growable: false);
          onOptionsChanged(options);
          return options;
        },
        displayStringForOption: (option) =>
            option.chat?.title ?? option.displayName ?? option.address ?? '',
        fieldViewBuilder: (context, fieldController, fieldFocusNode, _) {
          final colors = Theme.of(context).colorScheme;
          final hintColor = colors.onSurfaceVariant.withValues(alpha: 0.8);
          final textStyle = Theme.of(context).textTheme.bodyMedium;
          return TapRegion(
            groupId: tapRegionGroup,
            onTapOutside: (_) => fieldFocusNode.unfocus(),
            child: SizedBox(
              height: _chipHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(_chipHeight / 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: const InputDecorationTheme(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        child: TextField(
                          controller: fieldController,
                          focusNode: fieldFocusNode,
                          cursorColor: colors.primary,
                          maxLines: 1,
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          autocorrect: false,
                          smartDashesType: SmartDashesType.disabled,
                          smartQuotesType: SmartQuotesType.disabled,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            hintText: context.l10n.recipientsAddHint,
                            hintStyle: textStyle?.copyWith(color: hintColor),
                          ),
                          style: textStyle,
                          strutStyle: textStyle == null
                              ? null
                              : StrutStyle.fromTextStyle(textStyle),
                          textInputAction: TextInputAction.done,
                          onEditingComplete: () =>
                              fieldFocusNode.requestFocus(),
                          textAlignVertical: TextAlignVertical.center,
                          onSubmitted: (_) {
                            final handled = onSubmitted();
                            if (!handled) {
                              final trimmed = fieldController.text.trim();
                              if (trimmed.isNotEmpty &&
                                  onManualEntry(trimmed)) {
                                fieldController.clear();
                                onOptionsChanged(const <FanOutTarget>[]);
                              }
                            }
                            fieldFocusNode.requestFocus();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          if (options.isEmpty) {
            return const SizedBox.shrink();
          }
          final colors = context.colorScheme;
          final theme = Theme.of(context).textTheme;
          final overlayRadius = BorderRadius.circular(20);
          final titleStyle = theme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          );
          final subtitleStyle = theme.bodySmall?.copyWith(
            color: colors.mutedForeground,
          );
          final dividerColor = colors.border.withValues(alpha: 0.55);
          final hoverColor = colors.muted.withValues(alpha: 0.08);
          final highlightColor = colors.primary.withValues(alpha: 0.12);
          final trailingIconColor = colors.muted.withValues(alpha: 0.9);
          final optionList = options.toList(growable: false);
          return TapRegion(
            groupId: tapRegionGroup,
            onTapOutside: (_) => focusNode.unfocus(),
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 260,
                  maxWidth: 420,
                  maxHeight: _suggestionMaxHeight,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: overlayRadius,
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.9),
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
                        valueListenable: highlightedIndexListenable,
                        builder: (context, highlightedIndex, _) {
                          return _AutocompleteOptionsList(
                            options: optionList,
                            avatarPathsByJid: avatarPathsByJid,
                            onSelected: (option) {
                              onSelected(option);
                              controller.clear();
                              onOptionsChanged(const <FanOutTarget>[]);
                              focusNode.requestFocus();
                              onRecipientAdded(option);
                            },
                            titleStyle: titleStyle,
                            subtitleStyle: subtitleStyle,
                            dividerColor: dividerColor,
                            trailingIconColor: trailingIconColor,
                            hoverColor: hoverColor,
                            highlightColor: highlightColor,
                            highlightedIndex: highlightedIndex,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        onSelected: (selection) {
          onRecipientAdded(selection);
          controller.clear();
          onOptionsChanged(const <FanOutTarget>[]);
          focusNode.requestFocus();
        },
      ),
    );
  }
}

class _AutocompleteOptionsList extends StatelessWidget {
  const _AutocompleteOptionsList({
    required this.options,
    required this.avatarPathsByJid,
    required this.onSelected,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.dividerColor,
    required this.trailingIconColor,
    required this.hoverColor,
    required this.highlightColor,
    required this.highlightedIndex,
  });

  final List<FanOutTarget> options;
  final Map<String, String> avatarPathsByJid;
  final ValueChanged<FanOutTarget> onSelected;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Color dividerColor;
  final Color trailingIconColor;
  final Color hoverColor;
  final Color highlightColor;
  final int? highlightedIndex;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    final height = math.min(
      options.length * _suggestionTileHeight,
      _suggestionMaxHeight,
    );
    final scrollable = options.length * _suggestionTileHeight > height;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: SizedBox(
        height: height,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          physics: scrollable
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemExtent: _suggestionTileHeight,
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
                : BorderSide(color: dividerColor, width: 0.7);
            final highlighted =
                highlightedIndex != null && highlightedIndex == index;
            return InkWell(
              onTap: () => onSelected(option),
              hoverColor: hoverColor,
              child: Container(
                decoration: BoxDecoration(
                  color: highlighted ? highlightColor : null,
                  border: Border(bottom: border),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    _SuggestionAvatar(
                      option: option,
                      avatarPathsByJid: avatarPathsByJid,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: titleStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              style: subtitleStyle,
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
                      color: trailingIconColor,
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

class _SuggestionAvatar extends StatelessWidget {
  const _SuggestionAvatar({
    required this.option,
    required this.avatarPathsByJid,
  });

  final FanOutTarget option;
  final Map<String, String> avatarPathsByJid;

  @override
  Widget build(BuildContext context) {
    if (option.chat != null) {
      return TransportAwareAvatar(
        chat: option.chat!,
        size: 32,
        showBadge: false,
      );
    }
    final address = option.address ?? option.chat?.emailAddress ?? '';
    final jid = address.isNotEmpty ? address : option.displayName ?? '';
    final avatarPath = avatarPathsByJid[jid.toLowerCase()];
    return AxiAvatar(
      jid: jid,
      size: 32,
      shape: AxiAvatarShape.circle,
      avatarPath: avatarPath,
    );
  }
}
