import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/bloc/chat_bloc.dart';
import 'package:axichat/src/common/ui/string_to_color.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const double _chipHeight = 36.0;
const Duration _chipMotionDuration = Duration(milliseconds: 320);
const Curve _chipMotionCurve = Curves.easeInOutCubic;
const Duration _barAnimationDuration = Duration(milliseconds: 360);

class RecipientChipsBar extends StatefulWidget {
  const RecipientChipsBar({
    super.key,
    required this.recipients,
    required this.availableChats,
    required this.onRecipientAdded,
    required this.onRecipientToggled,
    required this.onRecipientRemoved,
    required this.latestStatuses,
  });

  final List<ComposerRecipient> recipients;
  final List<Chat> availableChats;
  final ValueChanged<FanOutTarget> onRecipientAdded;
  final ValueChanged<String> onRecipientToggled;
  final ValueChanged<String> onRecipientRemoved;
  final Map<String, FanOutRecipientState> latestStatuses;

  @override
  State<RecipientChipsBar> createState() => _RecipientChipsBarState();
}

class _RecipientChipsBarState extends State<RecipientChipsBar>
    with SingleTickerProviderStateMixin {
  static const _collapsedVisibleCount = 4;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _expanded = false;
  bool _barCollapsed = false;
  late List<ComposerRecipient> _renderedRecipients;
  final Set<String> _enteringKeys = <String>{};
  final Set<String> _removingKeys = <String>{};
  late final AnimationController _collapseController;
  late final Animation<double> _collapseAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _handleKeyEvent;
    _renderedRecipients = _visibleRecipientsForState();
    _collapseController = AnimationController(
      vsync: this,
      duration: _barAnimationDuration,
      value: _barCollapsed ? 0 : 1,
    );
    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant RecipientChipsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRenderedRecipients();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _collapseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final recipients = widget.recipients;
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
            status: widget.latestStatuses[recipient.target.chat?.jid ?? ''],
            onToggle: () => widget.onRecipientToggled(recipient.key),
            onRemove: recipient.pinned
                ? null
                : () => widget.onRecipientRemoved(recipient.key),
          ),
        ),
      if (!_barCollapsed && !_expanded && overflow > 0)
        _AnimatedChipWrapper(
          key: ValueKey('show-more-$overflow'),
          child: _ActionChip(
            label: '+$overflow more',
            icon: Icons.add,
            onPressed: () => _toggleListExpansion(true),
          ),
        ),
      if (!_barCollapsed && _expanded && overflow > 0)
        _AnimatedChipWrapper(
          key: const ValueKey('collapse'),
          child: _ActionChip(
            label: 'Collapse',
            icon: Icons.expand_less,
            onPressed: () => _toggleListExpansion(false),
          ),
        ),
    ];

    final barBackground = _containerBackground(colors);
    final bodyPadding = EdgeInsets.fromLTRB(16, 8, 16, _barCollapsed ? 8 : 12);
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleBarCollapsed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Send to...',
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
          ClipRect(
            child: SizeTransition(
              sizeFactor: _collapseAnimation,
              axisAlignment: -1,
              child: AnimatedSize(
                duration: _barAnimationDuration,
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...chips,
                      _AnimatedChipWrapper(
                        key: const ValueKey('autocomplete-field'),
                        child: _buildAutocompleteField(
                          context,
                          backgroundColor: barBackground,
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
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controller.text.isEmpty) {
      _removeLastRecipient();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildAutocompleteField(
    BuildContext context, {
    required Color backgroundColor,
  }) {
    final suggestions = widget.availableChats
        .where(
          (chat) => !widget.recipients
              .any((recipient) => recipient.target.chat?.jid == chat.jid),
        )
        .toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
      child: RawAutocomplete<FanOutTarget>(
        textEditingController: _controller,
        focusNode: _focusNode,
        optionsBuilder: (TextEditingValue value) {
          final query = value.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? suggestions.take(8).toList()
              : suggestions.where((chat) {
                  final title = chat.title.toLowerCase();
                  final address = chat.emailAddress?.toLowerCase() ?? '';
                  return title.contains(query) || address.contains(query);
                }).toList();
          return filtered.map(FanOutTarget.chat);
        },
        displayStringForOption: (option) =>
            option.chat?.title ?? option.address ?? '',
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          final colors = Theme.of(context).colorScheme;
          final hintColor = colors.onSurfaceVariant.withValues(alpha: 0.8);
          final textStyle = Theme.of(context).textTheme.bodyMedium;
          return SizedBox(
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
                        controller: controller,
                        focusNode: focusNode,
                        cursorColor: colors.primary,
                        maxLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Add...',
                          hintStyle: textStyle?.copyWith(color: hintColor),
                        ),
                        style: textStyle,
                        strutStyle: textStyle == null
                            ? null
                            : StrutStyle.fromTextStyle(textStyle),
                        textInputAction: TextInputAction.done,
                        onEditingComplete: () => focusNode.requestFocus(),
                        textAlignVertical: TextAlignVertical.center,
                        onSubmitted: (value) {
                          final trimmed = value.trim();
                          if (trimmed.isEmpty) {
                            focusNode.requestFocus();
                            return;
                          }
                          if (_handleManualEntry(trimmed)) {
                            controller.clear();
                          } else {
                            onFieldSubmitted();
                          }
                          focusNode.requestFocus();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180, minWidth: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option.chat?.title ?? option.address ?? ''),
                    subtitle: option.chat?.emailAddress == null
                        ? null
                        : Text(option.chat!.emailAddress!),
                    onTap: () {
                      onSelected(option);
                      _controller.clear();
                    },
                  );
                },
              ),
            ),
          ),
        ),
        onSelected: (option) {
          widget.onRecipientAdded(option);
          _controller.clear();
        },
      ),
    );
  }

  bool _handleManualEntry(String value) {
    if (!_looksLikeEmail(value)) {
      return false;
    }
    widget.onRecipientAdded(FanOutTarget.address(address: value));
    return true;
  }

  void _removeLastRecipient() {
    final removable =
        widget.recipients.where((recipient) => !recipient.pinned).toList();
    if (removable.isEmpty) return;
    widget.onRecipientRemoved(removable.last.key);
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
    if (next) {
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
}

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({
    required this.recipient,
    required this.onToggle,
    required this.onRemove,
    this.status,
  });

  final ComposerRecipient recipient;
  final VoidCallback onToggle;
  final VoidCallback? onRemove;
  final FanOutRecipientState? status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shadColors = context.colorScheme;
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
    final statusIcon = _statusIcon();
    final accentColor = baseColor.withValues(alpha: 1);
    final borderColor = included ? accentColor : Colors.transparent;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _chipHeight),
      child: InputChip(
        shape: const StadiumBorder(),
        showCheckmark: false,
        avatar: statusIcon == null
            ? null
            : SizedBox(
                width: 16,
                height: 16,
                child: statusIcon,
              ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showLock)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.lock,
                  size: 14,
                  color: foreground,
                ),
              ),
            if (_showWarning)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.warning_rounded,
                  size: 14,
                  color: shadColors.destructive,
                ),
              ),
            Flexible(child: Text(_label)),
          ],
        ),
        onPressed: onToggle,
        selected: included,
        backgroundColor: background,
        selectedColor: background,
        labelStyle: TextStyle(color: foreground),
        deleteIcon: onRemove == null
            ? null
            : Icon(
                Icons.close,
                size: 16,
                color: foreground,
              ),
        onDeleted: onRemove,
        side: BorderSide(color: borderColor, width: included ? 1.1 : 0),
        elevation: included ? 1.5 : 0,
        shadowColor: colors.shadow,
        selectedShadowColor: colors.shadow,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      ),
    );
  }

  String get _label {
    if (recipient.target.chat != null) {
      return recipient.target.chat!.title;
    }
    return recipient.target.address ?? 'Recipient';
  }

  bool get _showLock =>
      recipient.target.chat?.encryptionProtocol.isNotNone ?? false;

  bool get _showWarning => recipient.target.chat == null;

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

  Widget? _statusIcon() {
    switch (status) {
      case FanOutRecipientState.failed:
        return const Icon(Icons.warning_amber_rounded,
            size: 16, color: Colors.red);
      case FanOutRecipientState.sent:
        return const Icon(Icons.check, size: 16, color: Colors.green);
      case FanOutRecipientState.queued:
      case FanOutRecipientState.sending:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case null:
        return null;
    }
  }
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
