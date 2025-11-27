import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
import 'package:axichat/src/accessibility/models/accessibility_action_models.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const MenuSerializableShortcut _nextItemShortcut =
    SingleActivator(LogicalKeyboardKey.arrowDown);
const MenuSerializableShortcut _previousItemShortcut =
    SingleActivator(LogicalKeyboardKey.arrowUp);
const MenuSerializableShortcut _nextSectionShortcut = SingleActivator(
  LogicalKeyboardKey.arrowDown,
  shift: true,
);
const MenuSerializableShortcut _previousSectionShortcut = SingleActivator(
  LogicalKeyboardKey.arrowUp,
  shift: true,
);
const MenuSerializableShortcut _firstItemShortcut =
    SingleActivator(LogicalKeyboardKey.home);
const MenuSerializableShortcut _lastItemShortcut =
    SingleActivator(LogicalKeyboardKey.end);
const MenuSerializableShortcut _activateShortcut =
    SingleActivator(LogicalKeyboardKey.enter);

class AccessibilityActionMenu extends StatefulWidget {
  const AccessibilityActionMenu({super.key});

  @override
  State<AccessibilityActionMenu> createState() =>
      _AccessibilityActionMenuState();
}

class _AccessibilityActionMenuState extends State<AccessibilityActionMenu> {
  String? _localeName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeName = context.l10n.localeName;
    if (_localeName != localeName) {
      _localeName = localeName;
      final bloc = context.read<AccessibilityActionBloc?>();
      if (bloc != null) {
        bloc.add(AccessibilityLocaleUpdated(context.l10n));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccessibilityActionBloc, AccessibilityActionState>(
      builder: (context, state) {
        const duration = baseAnimationDuration;
        return IgnorePointer(
          ignoring: !state.visible,
          child: AnimatedOpacity(
            opacity: state.visible ? 1 : 0,
            duration: duration,
            curve: Curves.easeInOutCubic,
            child: state.visible
                ? _AccessibilityMenuScaffold(state: state)
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _AccessibilityMenuScaffold extends StatefulWidget {
  const _AccessibilityMenuScaffold({required this.state});

  final AccessibilityActionState state;

  @override
  State<_AccessibilityMenuScaffold> createState() =>
      _AccessibilityMenuScaffoldState();
}

class _AccessibilityMenuScaffoldState
    extends State<_AccessibilityMenuScaffold> {
  final FocusScopeNode _focusScopeNode =
      FocusScopeNode(debugLabel: 'accessibility_menu_scope');
  final GlobalKey<_AccessibilitySectionListState> _listKey = GlobalKey();
  bool _wasVisible = false;

  @override
  void initState() {
    super.initState();
    _wasVisible = widget.state.visible;
    if (_wasVisible) {
      _scheduleInitialFocus();
    }
  }

  @override
  void didUpdateWidget(covariant _AccessibilityMenuScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.visible && !_wasVisible) {
      _scheduleInitialFocus();
    } else if (!widget.state.visible && _wasVisible) {
      _focusScopeNode.unfocus();
    }
    _wasVisible = widget.state.visible;
  }

  @override
  void dispose() {
    _focusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
    final shortcuts = <ShortcutActivator, Intent>{
      escapeShortcut: const _AccessibilityDismissIntent(),
      _nextItemShortcut: const _NextItemIntent(),
      _previousItemShortcut: const _PreviousItemIntent(),
      _nextSectionShortcut: const _NextSectionIntent(),
      _previousSectionShortcut: const _PreviousSectionIntent(),
      _firstItemShortcut: const _FirstItemIntent(),
      _lastItemShortcut: const _LastItemIntent(),
    };
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => bloc.add(const AccessibilityMenuClosed()),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
        ),
        Center(
          child: Shortcuts(
            shortcuts: shortcuts,
            child: Actions(
              actions: {
                _AccessibilityDismissIntent:
                    CallbackAction<_AccessibilityDismissIntent>(
                  onInvoke: (_) {
                    if (widget.state.stack.length > 1) {
                      bloc.add(const AccessibilityMenuBack());
                    } else {
                      bloc.add(const AccessibilityMenuClosed());
                    }
                    return null;
                  },
                ),
                _NextItemIntent: CallbackAction<_NextItemIntent>(
                  onInvoke: (_) => _withList(
                    (list) => list.focusNextItem(),
                  ),
                ),
                _PreviousItemIntent: CallbackAction<_PreviousItemIntent>(
                  onInvoke: (_) => _withList(
                    (list) => list.focusPreviousItem(),
                  ),
                ),
                _NextSectionIntent: CallbackAction<_NextSectionIntent>(
                  onInvoke: (_) => _withList(
                    (list) => list.focusNextSection(),
                  ),
                ),
                _PreviousSectionIntent: CallbackAction<_PreviousSectionIntent>(
                  onInvoke: (_) => _withList(
                    (list) => list.focusPreviousSection(),
                  ),
                ),
                _FirstItemIntent: CallbackAction<_FirstItemIntent>(
                  onInvoke: (_) => _withList((list) => list.focusFirstItem()),
                ),
                _LastItemIntent: CallbackAction<_LastItemIntent>(
                  onInvoke: (_) => _withList((list) => list.focusLastItem()),
                ),
              },
              child: FocusScope(
                node: _focusScopeNode,
                autofocus: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 720,
                    maxHeight: 640,
                  ),
                  child: AxiModalSurface(
                    padding: const EdgeInsets.all(20),
                    child: _AccessibilityActionContent(
                      state: widget.state,
                      listKey: _listKey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _withList(void Function(_AccessibilitySectionListState list) action) {
    final list = _listKey.currentState;
    if (list == null || list.isEditingText) return;
    action(list);
  }

  void _scheduleInitialFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusScopeNode.requestFocus();
      _listKey.currentState?.focusFirstItem();
    });
  }
}

class _AccessibilityActionContent extends StatelessWidget {
  const _AccessibilityActionContent({
    required this.state,
    required this.listKey,
  });

  final AccessibilityActionState state;
  final GlobalKey<_AccessibilitySectionListState> listKey;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
    final breadcrumbLabels = _breadcrumbLabels(state, context);
    final headerTitle = breadcrumbLabels.isNotEmpty
        ? breadcrumbLabels.last
        : _headerLabelFor(state.currentEntry.kind, context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _AccessibilityMenuHeader(
          breadcrumb: headerTitle,
          breadcrumbs: breadcrumbLabels,
          onCrumbSelected: (index) =>
              bloc.add(AccessibilityMenuJumpedTo(index)),
          onBack: state.stack.length > 1
              ? () => bloc.add(const AccessibilityMenuBack())
              : null,
          onClose: () => bloc.add(const AccessibilityMenuClosed()),
        ),
        const SizedBox(height: 12),
        const _KeyboardShortcutLegend(),
        const SizedBox(height: 12),
        if (state.statusMessage != null)
          _AccessibilityBanner(
            message: state.statusMessage!,
            color: context.colorScheme.card,
            foreground: context.colorScheme.foreground,
            icon: Icons.check_circle,
          ),
        if (state.errorMessage != null)
          _AccessibilityBanner(
            message: state.errorMessage!,
            color: context.colorScheme.destructive.withValues(alpha: 0.1),
            foreground: context.colorScheme.destructive,
            icon: Icons.error_outline,
          ),
        if (state.statusMessage != null || state.errorMessage != null)
          const SizedBox(height: 12),
        if (state.currentEntry.kind == AccessibilityStepKind.composer)
          _ComposerSection(state: state),
        if (state.currentEntry.kind == AccessibilityStepKind.newContact)
          _NewContactSection(state: state),
        if (state.sections.isNotEmpty)
          Flexible(
            fit: FlexFit.loose,
            child: _AccessibilitySectionList(
              key: listKey,
              sections: state.sections,
            ),
          )
        else
          const Flexible(
            fit: FlexFit.loose,
            child: Center(child: Text('No actions available right now')),
          ),
      ],
    );
  }

  String _headerLabelFor(AccessibilityStepKind kind, BuildContext context) {
    final l10n = context.l10n;
    switch (kind) {
      case AccessibilityStepKind.root:
        return 'Accessibility actions';
      case AccessibilityStepKind.contactPicker:
        return 'Choose a contact';
      case AccessibilityStepKind.composer:
        return l10n.chatComposerMessageHint;
      case AccessibilityStepKind.unread:
        return 'Unread conversations';
      case AccessibilityStepKind.invites:
        return 'Pending invites';
      case AccessibilityStepKind.newContact:
        return 'Start a new address';
    }
  }

  List<String> _breadcrumbLabels(
    AccessibilityActionState state,
    BuildContext context,
  ) =>
      state.stack.map((entry) => _headerLabelFor(entry.kind, context)).toList();
}

class _AccessibilityMenuHeader extends StatelessWidget {
  const _AccessibilityMenuHeader({
    required this.breadcrumb,
    required this.breadcrumbs,
    required this.onClose,
    this.onBack,
    this.onCrumbSelected,
  });

  final String breadcrumb;
  final List<String> breadcrumbs;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final ValueChanged<int>? onCrumbSelected;

  @override
  Widget build(BuildContext context) {
    final findShortcut = findActionShortcut(Theme.of(context).platform);
    return Row(
      children: [
        if (onBack != null)
          ShadButton.ghost(
            onPressed: onBack,
            child: const Icon(Icons.arrow_back),
          ),
        if (onBack != null) const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                breadcrumb,
                style: context.textTheme.h3,
              ),
              const SizedBox(height: 4),
              if (breadcrumbs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _BreadcrumbChain(
                    labels: breadcrumbs,
                    onSelected: onCrumbSelected,
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ShortcutHint(
                    shortcut: findShortcut,
                    dense: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        ShadButton.ghost(
          onPressed: onClose,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close),
              SizedBox(width: 6),
              ShortcutHint(
                shortcut: escapeShortcut,
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BreadcrumbChain extends StatelessWidget {
  const _BreadcrumbChain({
    required this.labels,
    required this.onSelected,
  });

  final List<String> labels;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final connectorStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
      fontWeight: FontWeight.w700,
    );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          _BreadcrumbChip(
            label: labels[i],
            index: i,
            total: labels.length,
            onSelected: onSelected,
          ),
          if (i < labels.length - 1) Text('>', style: connectorStyle),
        ],
      ],
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  const _BreadcrumbChip({
    required this.label,
    required this.index,
    required this.total,
    required this.onSelected,
  });

  final String label;
  final int index;
  final int total;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final radius = context.radius;
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          final borderColor = hasFocus ? colors.primary : colors.border;
          final borderWidth = hasFocus ? 2.5 : 1.25;
          return Semantics(
            button: true,
            focusable: true,
            label:
                'Step ${index + 1} of $total: $label. Activate to jump to this step.',
            child: AnimatedContainer(
              duration: baseAnimationDuration,
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: radius,
                border: Border.all(
                  color: borderColor,
                  width: borderWidth,
                ),
              ),
              child: InkWell(
                borderRadius: radius,
                onTap: onSelected == null ? null : () => onSelected!(index),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    label,
                    style: context.textTheme.small.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AccessibilityBanner extends StatelessWidget {
  const _AccessibilityBanner({
    required this.message,
    required this.color,
    required this.foreground,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: context.textTheme.small.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyboardShortcutLegend extends StatelessWidget {
  const _KeyboardShortcutLegend();

  @override
  Widget build(BuildContext context) {
    final platformShortcut = findActionShortcut(Theme.of(context).platform);
    final entries = [
      _ShortcutLegendEntry(
        label: 'Open menu',
        shortcut: platformShortcut,
      ),
      const _ShortcutLegendEntry(
        label: 'Back a step or close',
        shortcut: escapeShortcut,
      ),
      const _ShortcutLegendEntry(
        label: 'Activate item',
        shortcut: _activateShortcut,
      ),
      const _ShortcutLegendEntry(
        label: 'Next item',
        shortcut: _nextItemShortcut,
      ),
      const _ShortcutLegendEntry(
        label: 'Previous item',
        shortcut: _previousItemShortcut,
      ),
      const _ShortcutLegendEntry(
        label: 'Next list',
        shortcut: _nextSectionShortcut,
      ),
      const _ShortcutLegendEntry(
        label: 'Previous list',
        shortcut: _previousSectionShortcut,
      ),
      const _ShortcutLegendEntry(
        label: 'First item',
        shortcut: _firstItemShortcut,
      ),
      const _ShortcutLegendEntry(
        label: 'Last item',
        shortcut: _lastItemShortcut,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keyboard shortcuts',
          style: context.textTheme.small.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: entries,
        ),
      ],
    );
  }
}

class _ShortcutLegendEntry extends StatelessWidget {
  const _ShortcutLegendEntry({
    required this.label,
    required this.shortcut,
  });

  final String label;
  final MenuSerializableShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textStyle = context.textTheme.small.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final description = '$label, ${shortcutLabel(context, shortcut)}';
    return Focus(
      child: Semantics(
        label: description,
        focusable: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
            color: colors.muted.withValues(alpha: 0.04),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(label, style: textStyle),
                ShortcutHint(shortcut: shortcut, dense: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerSection extends StatelessWidget {
  const _ComposerSection({required this.state});

  final AccessibilityActionState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.recipients
                  .map(
                    (recipient) => Semantics(
                      label: 'Recipient ${recipient.displayName}',
                      button: true,
                      hint: 'Press backspace or delete to remove',
                      child: InputChip(
                        label: Text(recipient.displayName),
                        onDeleted: () => bloc.add(
                          AccessibilityRecipientRemoved(recipient.jid),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          _AccessibilityTextField(
            label: context.l10n.chatComposerMessageHint,
            text: state.composerText,
            onChanged: (value) => bloc.add(AccessibilityComposerChanged(value)),
            hintText: 'Type a message',
            minLines: 3,
            maxLines: 5,
            enabled: !state.busy,
          ),
        ],
      ),
    );
  }
}

class _NewContactSection extends StatelessWidget {
  const _NewContactSection({required this.state});

  final AccessibilityActionState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _AccessibilityTextField(
        label: 'Contact address',
        text: state.newContactInput,
        onChanged: (value) => bloc.add(AccessibilityNewContactChanged(value)),
        hintText: 'someone@example.com',
        enabled: !state.busy,
      ),
    );
  }
}

class _AccessibilityTextField extends StatefulWidget {
  const _AccessibilityTextField({
    required this.label,
    required this.text,
    required this.onChanged,
    required this.hintText,
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String label;
  final String text;
  final ValueChanged<String> onChanged;
  final String hintText;
  final int minLines;
  final int maxLines;
  final bool enabled;

  @override
  State<_AccessibilityTextField> createState() =>
      _AccessibilityTextFieldState();
}

class _AccessibilityTextFieldState extends State<_AccessibilityTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.text);
  late final FocusNode _focusNode =
      FocusNode(debugLabel: 'accessibility-text-${widget.label}');

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _AccessibilityTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _controller.text != widget.text) {
      _controller.text = widget.text;
      _controller.selection =
          TextSelection.collapsed(offset: widget.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final hasFocus = _focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: context.textTheme.small,
        ),
        const SizedBox(height: 6),
        Semantics(
          textField: true,
          label: widget.label,
          hint: 'Enter text and press Escape to leave this field',
          child: Focus(
            focusNode: _focusNode,
            child: AnimatedContainer(
              duration: baseAnimationDuration,
              decoration: BoxDecoration(
                borderRadius: context.radius,
                border: Border.all(
                  color: hasFocus ? colors.primary : colors.border,
                  width: hasFocus ? 3 : 1,
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: ShadInput(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                placeholder: Text(widget.hintText),
                onChanged: widget.onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionRange {
  const _SectionRange({required this.start, required this.end});

  final int start;
  final int end;
}

class _AccessibilitySectionList extends StatefulWidget {
  const _AccessibilitySectionList({super.key, required this.sections});

  final List<AccessibilityMenuSection> sections;

  @override
  State<_AccessibilitySectionList> createState() =>
      _AccessibilitySectionListState();
}

class _AccessibilitySectionListState extends State<_AccessibilitySectionList> {
  final ScrollController _scrollController = ScrollController();
  List<FocusNode> _itemNodes = <FocusNode>[];
  List<_SectionRange> _sectionRanges = <_SectionRange>[];
  int? _lastFocusedIndex;
  bool _hasFocusedItem = false;

  bool get isEditingText {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    return focus.context?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  void initState() {
    super.initState();
    _refreshStructure();
  }

  @override
  void didUpdateWidget(covariant _AccessibilitySectionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshStructure();
  }

  @override
  void dispose() {
    _disposeNodes();
    _scrollController.dispose();
    super.dispose();
  }

  void focusFirstItem() => _focusIndex(0);
  void focusLastItem() => _focusIndex(_itemNodes.length - 1);

  void focusNextItem() {
    final current = _currentIndex();
    _focusIndex(current == null ? 0 : current + 1);
  }

  void focusPreviousItem() {
    final current = _currentIndex();
    _focusIndex(current == null ? 0 : current - 1);
  }

  void focusNextSection() {
    if (_sectionRanges.isEmpty) return;
    final current = _currentIndex() ?? 0;
    final currentSection = _sectionForIndex(current);
    if (currentSection == null) {
      _focusIndex(0);
      return;
    }
    final nextSection = (currentSection + 1).clamp(
      0,
      _sectionRanges.length - 1,
    );
    if (nextSection == currentSection) {
      _focusIndex(_sectionRanges.last.end);
      return;
    }
    final nextStart = _sectionRanges[nextSection].start;
    _focusIndex(nextStart);
  }

  void focusPreviousSection() {
    if (_sectionRanges.isEmpty) return;
    final current = _currentIndex() ?? 0;
    final currentSection = _sectionForIndex(current);
    if (currentSection == null) {
      _focusIndex(0);
      return;
    }
    final previousSection =
        (currentSection - 1).clamp(0, _sectionRanges.length - 1);
    final start = _sectionRanges[previousSection].start;
    _focusIndex(start);
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
    final children = <Widget>[];
    var nodeIndex = 0;
    final colors = context.colorScheme;
    for (var sectionIndex = 0;
        sectionIndex < widget.sections.length;
        sectionIndex++) {
      final section = widget.sections[sectionIndex];
      if (section.title != null) {
        children.add(
          Semantics(
            container: true,
            label:
                '${section.title ?? 'Actions'} section with ${section.items.length} items',
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                section.title!,
                style: context.textTheme.small.copyWith(
                  color: context.colorScheme.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }
      for (final item in section.items) {
        final focusNode =
            nodeIndex < _itemNodes.length ? _itemNodes[nodeIndex] : null;
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AccessibilityActionTile(
              item: item,
              focusNode: focusNode,
              autofocus: nodeIndex == 0,
              onFocused: () => _lastFocusedIndex = nodeIndex,
              onFocusChanged: (hasFocus) =>
                  _handleFocusChanged(nodeIndex, hasFocus),
              onTap: () => bloc.add(
                AccessibilityMenuActionTriggered(item.action),
              ),
              onDismiss: item.dismissId == null
                  ? null
                  : () => bloc.add(
                        AccessibilityMenuActionTriggered(
                          AccessibilityDismissHighlightAction(
                            highlightId: item.dismissId!,
                          ),
                        ),
                      ),
            ),
          ),
        );
        nodeIndex++;
      }
      final hasMoreSections = sectionIndex < widget.sections.length - 1;
      if (hasMoreSections) {
        children.add(const SizedBox(height: 12));
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;
        final borderColor = _hasFocusedItem ? colors.primary : colors.border;
        final borderWidth = _hasFocusedItem ? 3.0 : 1.0;
        return Semantics(
          container: true,
          label: 'Accessibility action list with ${_itemNodes.length} items',
          child: AnimatedContainer(
            duration: baseAnimationDuration,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView(
                controller: _scrollController,
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  void _refreshStructure() {
    final itemCount = widget.sections.fold<int>(
      0,
      (total, section) => total + section.items.length,
    );
    if (itemCount != _itemNodes.length) {
      _disposeNodes();
      _itemNodes = List.generate(
        itemCount,
        (index) => FocusNode(debugLabel: 'accessibility-item-$index'),
      );
    }
    _sectionRanges = _computeSectionRanges(widget.sections);
    if (_lastFocusedIndex != null &&
        (_lastFocusedIndex! < 0 || _lastFocusedIndex! >= _itemNodes.length)) {
      _lastFocusedIndex = null;
    }
    if (_itemNodes.isNotEmpty && _lastFocusedIndex == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          focusFirstItem();
        }
      });
    }
  }

  List<_SectionRange> _computeSectionRanges(
    List<AccessibilityMenuSection> sections,
  ) {
    final ranges = <_SectionRange>[];
    var cursor = 0;
    for (final section in sections) {
      if (section.items.isEmpty) continue;
      final start = cursor;
      cursor += section.items.length;
      ranges.add(_SectionRange(start: start, end: cursor - 1));
    }
    return ranges;
  }

  int? _sectionForIndex(int index) {
    for (var i = 0; i < _sectionRanges.length; i++) {
      final range = _sectionRanges[i];
      if (index >= range.start && index <= range.end) {
        return i;
      }
    }
    return null;
  }

  int? _currentIndex() {
    if (_itemNodes.isEmpty) return null;
    if (_lastFocusedIndex != null &&
        _lastFocusedIndex! >= 0 &&
        _lastFocusedIndex! < _itemNodes.length &&
        _itemNodes[_lastFocusedIndex!].hasFocus) {
      return _lastFocusedIndex;
    }
    final index = _itemNodes.indexWhere((node) => node.hasFocus);
    return index == -1 ? null : index;
  }

  void _focusIndex(int index) {
    if (_itemNodes.isEmpty) return;
    final clamped = index.clamp(0, _itemNodes.length - 1);
    final focusNode = _itemNodes[clamped];
    _lastFocusedIndex = clamped;
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
    final focusContext = focusNode.context;
    if (focusContext != null) {
      Scrollable.ensureVisible(
        focusContext,
        duration: baseAnimationDuration,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  }

  void _handleFocusChanged(int index, bool hasFocus) {
    if (!mounted) return;
    if (hasFocus) {
      _lastFocusedIndex = index;
      if (!_hasFocusedItem) {
        setState(() {
          _hasFocusedItem = true;
        });
      }
      return;
    }
    final anyFocused = _itemNodes.any((node) => node.hasFocus);
    if (_hasFocusedItem != anyFocused) {
      setState(() {
        _hasFocusedItem = anyFocused;
      });
    }
  }

  void _disposeNodes() {
    for (final node in _itemNodes) {
      node.dispose();
    }
    _itemNodes = <FocusNode>[];
  }
}

class _AccessibilityActionTile extends StatelessWidget {
  const _AccessibilityActionTile({
    required this.item,
    required this.onTap,
    this.onDismiss,
    this.focusNode,
    this.autofocus = false,
    this.onFocused,
    this.onFocusChanged,
  });

  final AccessibilityMenuItem item;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onFocused;
  final ValueChanged<bool>? onFocusChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tileColor =
        item.highlight ? scheme.primary.withValues(alpha: 0.08) : scheme.card;
    final foreground =
        item.destructive ? scheme.destructive : scheme.foreground;
    final semanticsLabel = [
      item.label,
      if (item.description != null && item.description!.isNotEmpty)
        item.description!,
    ].join(', ');
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      canRequestFocus: !item.disabled,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onFocused?.call();
        }
        onFocusChanged?.call(hasFocus);
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          final borderColor = hasFocus ? scheme.primary : scheme.border;
          final borderWidth = hasFocus ? 3.0 : 1.2;
          return Semantics(
            button: true,
            focusable: true,
            label: semanticsLabel,
            enabled: !item.disabled,
            onTap: item.disabled ? null : onTap,
            hint: item.disabled
                ? null
                : 'Press Enter to activate. Press Escape to go back or close.',
            child: AnimatedContainer(
              duration: baseAnimationDuration,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                  width: borderWidth,
                ),
                boxShadow: [
                  if (hasFocus)
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: item.disabled ? null : onTap,
                  borderRadius: BorderRadius.circular(14),
                  focusColor: scheme.primary.withValues(alpha: 0.1),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        if (item.icon != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              item.icon,
                              color: foreground,
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: (textTheme.bodyMedium ??
                                        const TextStyle())
                                    .copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (item.description != null)
                                Text(
                                  item.description!,
                                  style: context.textTheme.small.copyWith(
                                    color: scheme.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (item.badge != null)
                          Container(
                            decoration: BoxDecoration(
                              color: scheme.secondary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Text(
                              item.badge!,
                              style: context.textTheme.small.copyWith(
                                color: scheme.secondaryForeground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (onDismiss != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.notifications_off_outlined),
                            tooltip: 'Dismiss',
                            onPressed: onDismiss,
                          ),
                        ],
                      ],
                    ),
                  ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AccessibilityDismissIntent extends Intent {
  const _AccessibilityDismissIntent();
}

class _NextItemIntent extends Intent {
  const _NextItemIntent();
}

class _PreviousItemIntent extends Intent {
  const _PreviousItemIntent();
}

class _NextSectionIntent extends Intent {
  const _NextSectionIntent();
}

class _PreviousSectionIntent extends Intent {
  const _PreviousSectionIntent();
}

class _FirstItemIntent extends Intent {
  const _FirstItemIntent();
}

class _LastItemIntent extends Intent {
  const _LastItemIntent();
}
