import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
import 'package:axichat/src/accessibility/models/accessibility_action_models.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const ShortcutActivator _nextItemActivator =
    SingleActivator(LogicalKeyboardKey.arrowDown);
const ShortcutActivator _previousItemActivator =
    SingleActivator(LogicalKeyboardKey.arrowUp);
const ShortcutActivator _nextGroupActivator = SingleActivator(
  LogicalKeyboardKey.arrowDown,
  shift: true,
);
const ShortcutActivator _previousGroupActivator = SingleActivator(
  LogicalKeyboardKey.arrowUp,
  shift: true,
);
final LogicalKeySet _nextGroupKeySet = LogicalKeySet(
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.arrowDown,
);
final LogicalKeySet _previousGroupKeySet = LogicalKeySet(
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.arrowUp,
);
const ShortcutActivator _firstItemActivator =
    SingleActivator(LogicalKeyboardKey.home);
const ShortcutActivator _lastItemActivator =
    SingleActivator(LogicalKeyboardKey.end);
const ShortcutActivator _activateItemActivator =
    SingleActivator(LogicalKeyboardKey.enter);
const ShortcutActivator _escapeActivator =
    SingleActivator(LogicalKeyboardKey.escape);

const MenuSerializableShortcut _nextItemShortcut =
    SingleActivator(LogicalKeyboardKey.arrowDown);
const MenuSerializableShortcut _previousItemShortcut =
    SingleActivator(LogicalKeyboardKey.arrowUp);
const MenuSerializableShortcut _nextGroupShortcut = SingleActivator(
  LogicalKeyboardKey.arrowDown,
  shift: true,
);
const MenuSerializableShortcut _previousGroupShortcut = SingleActivator(
  LogicalKeyboardKey.arrowUp,
  shift: true,
);
const MenuSerializableShortcut _nextFocusShortcut =
    SingleActivator(LogicalKeyboardKey.tab);
const MenuSerializableShortcut _previousFocusShortcut = SingleActivator(
  LogicalKeyboardKey.tab,
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
                ? BlockSemantics(
                    blocking: true,
                    child: _AccessibilityMenuScaffold(state: state),
                  )
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
  final GlobalKey _legendGroupKey = GlobalKey(debugLabel: 'legend_group');
  final GlobalKey _composerGroupKey = GlobalKey(debugLabel: 'composer_group');
  final GlobalKey _newContactGroupKey =
      GlobalKey(debugLabel: 'new_contact_group');
  final FocusNode _shortcutLegendFocusNode =
      FocusNode(debugLabel: 'accessibility_shortcut_legend');
  final FocusNode _composerFocusNode =
      FocusNode(debugLabel: 'accessibility_composer_field');
  final FocusNode _newContactFocusNode =
      FocusNode(debugLabel: 'accessibility_new_contact_field');
  final Map<_AccessibilityGroup, VoidCallback> _groupFocusHandlers =
      <_AccessibilityGroup, VoidCallback>{};
  FocusNode? _restoreFocusNode;
  bool _wasVisible = false;
  bool _isEditingText = false;
  String? _lastAnnouncedStep;
  bool Function(KeyEvent event)? _menuShortcutHandler;

  @override
  void initState() {
    super.initState();
    _isEditingText = _isTextInputFocused();
    FocusManager.instance.addListener(_handleFocusChange);
    _menuShortcutHandler = _handleMenuShortcut;
    HardwareKeyboard.instance.addHandler(_menuShortcutHandler!);
    _wasVisible = widget.state.visible;
    if (_wasVisible) {
      _restoreFocusNode = FocusManager.instance.primaryFocus;
      _scheduleInitialFocus();
    }
  }

  @override
  void didUpdateWidget(covariant _AccessibilityMenuScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.visible && !_wasVisible) {
      _restoreFocusNode = FocusManager.instance.primaryFocus;
      _scheduleInitialFocus();
      _announceStepChange();
    } else if (!widget.state.visible && _wasVisible) {
      _focusScopeNode.unfocus();
      final previous = _restoreFocusNode;
      _restoreFocusNode = null;
      if (previous != null &&
          previous.context != null &&
          previous.canRequestFocus) {
        previous.requestFocus();
      }
      _lastAnnouncedStep = null;
    }
    _announceStepChange();
    _wasVisible = widget.state.visible;
  }

  @override
  void dispose() {
    final handler = _menuShortcutHandler;
    if (handler != null) {
      HardwareKeyboard.instance.removeHandler(handler);
    }
    FocusManager.instance.removeListener(_handleFocusChange);
    _shortcutLegendFocusNode.dispose();
    _composerFocusNode.dispose();
    _newContactFocusNode.dispose();
    _focusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
    final shortcuts = <ShortcutActivator, Intent>{
      _escapeActivator: const _AccessibilityDismissIntent(),
      _nextGroupActivator: const _NextGroupIntent(),
      _previousGroupActivator: const _PreviousGroupIntent(),
      _nextGroupKeySet: const _NextGroupIntent(),
      _previousGroupKeySet: const _PreviousGroupIntent(),
      if (!_isEditingText) ...{
        _nextItemActivator: const _NextItemIntent(),
        _previousItemActivator: const _PreviousItemIntent(),
        _firstItemActivator: const _FirstItemIntent(),
        _lastItemActivator: const _LastItemIntent(),
      },
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
                  onInvoke: (_) => _handleDirectionalMove(forward: true),
                ),
                _PreviousItemIntent: CallbackAction<_PreviousItemIntent>(
                  onInvoke: (_) => _handleDirectionalMove(forward: false),
                ),
                _NextGroupIntent: CallbackAction<_NextGroupIntent>(
                  onInvoke: (_) => _focusNextGroup(),
                ),
                _PreviousGroupIntent: CallbackAction<_PreviousGroupIntent>(
                  onInvoke: (_) => _focusPreviousGroup(),
                ),
                _FirstItemIntent: CallbackAction<_FirstItemIntent>(
                  onInvoke: (_) => _withList((list) => list.focusFirstItem()),
                ),
                _LastItemIntent: CallbackAction<_LastItemIntent>(
                  onInvoke: (_) => _withList((list) => list.focusLastItem()),
                ),
                _ActivateItemIntent: CallbackAction<_ActivateItemIntent>(
                  onInvoke: (_) => _withList((list) => list.activateFocused()),
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
                    child: Material(
                      type: MaterialType.transparency,
                      child: Semantics(
                        scopesRoute: true,
                        namesRoute: true,
                        label: 'Accessibility actions dialog',
                        hint:
                            'Press Tab to reach shortcut instructions, use arrow keys inside lists, Shift plus arrows to move between groups, or Escape to exit.',
                        explicitChildNodes: true,
                        child: FocusTraversalGroup(
                          policy: OrderedTraversalPolicy(),
                          child: _AccessibilityActionContent(
                            state: widget.state,
                            listKey: _listKey,
                            enableActivationShortcut: !_isEditingText,
                            registerGroup: _registerGroup,
                            unregisterGroup: _unregisterGroup,
                            legendFocusNode: _shortcutLegendFocusNode,
                            composerFocusNode: _composerFocusNode,
                            newContactFocusNode: _newContactFocusNode,
                            legendGroupKey: _legendGroupKey,
                            composerGroupKey: _composerGroupKey,
                            newContactGroupKey: _newContactGroupKey,
                          ),
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
  }

  void _withList(void Function(_AccessibilitySectionListState list) action) {
    final list = _listKey.currentState;
    if (list == null || list.isEditingText) return;
    action(list);
  }

  void _handleDirectionalMove({required bool forward}) {
    final current = _currentGroup();
    if (current == _AccessibilityGroup.composer) {
      _moveWithinGroup(_composerGroupKey, forward: forward);
      return;
    }
    if (current == _AccessibilityGroup.newContact) {
      _moveWithinGroup(_newContactGroupKey, forward: forward);
      return;
    }
    if (current == _AccessibilityGroup.shortcuts) {
      _moveWithinGroup(_legendGroupKey, forward: forward);
      return;
    }
    _withList(
      (list) => forward ? list.focusNextItem() : list.focusPreviousItem(),
    );
  }

  void _moveWithinGroup(GlobalKey key, {required bool forward}) {
    final context = key.currentContext;
    if (context == null) return;
    final focusScope = FocusScope.of(context);
    if (forward) {
      focusScope.nextFocus();
    } else {
      focusScope.previousFocus();
    }
  }

  void _registerGroup(
    _AccessibilityGroup group,
    VoidCallback focusCallback,
  ) {
    _groupFocusHandlers[group] = focusCallback;
  }

  void _unregisterGroup(_AccessibilityGroup group) {
    _groupFocusHandlers.remove(group);
  }

  List<_AccessibilityGroup> _groupOrder() {
    final order = <_AccessibilityGroup>[];
    switch (widget.state.currentEntry.kind) {
      case AccessibilityStepKind.composer:
        order.add(_AccessibilityGroup.composer);
        order.add(_AccessibilityGroup.shortcuts);
        break;
      case AccessibilityStepKind.newContact:
        order.add(_AccessibilityGroup.newContact);
        order.add(_AccessibilityGroup.shortcuts);
        break;
      default:
        order.add(_AccessibilityGroup.shortcuts);
    }
    if (widget.state.sections.isNotEmpty) {
      order.add(_AccessibilityGroup.sections);
    }
    return order;
  }

  void _focusNextGroup() {
    final order = _groupOrder();
    if (order.isEmpty) return;
    final current = _currentGroup();
    final currentIndex =
        current == null ? -1 : order.indexOf(current).clamp(0, order.length);
    final nextIndex = (currentIndex + 1).clamp(0, order.length - 1).toInt();
    _focusGroup(order[nextIndex]);
  }

  void _focusPreviousGroup() {
    final order = _groupOrder();
    if (order.isEmpty) return;
    final current = _currentGroup();
    final currentIndex =
        current == null ? order.length : order.indexOf(current);
    final previousIndex = (currentIndex - 1).clamp(0, order.length - 1).toInt();
    _focusGroup(order[previousIndex]);
  }

  void _focusGroup(_AccessibilityGroup group) {
    final handler = _groupFocusHandlers[group];
    if (handler == null) return;
    _focusScopeNode.requestFocus();
    handler();
  }

  _AccessibilityGroup? _currentGroup() {
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focusContext == null) return null;
    return _AccessibilityGroupMarker.maybeOf(focusContext);
  }

  void _scheduleInitialFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusScopeNode.requestFocus();
      final groups = _groupOrder();
      if (widget.state.currentEntry.kind == AccessibilityStepKind.composer &&
          groups.contains(_AccessibilityGroup.composer)) {
        _focusGroup(_AccessibilityGroup.composer);
        return;
      }
      if (widget.state.currentEntry.kind == AccessibilityStepKind.newContact &&
          groups.contains(_AccessibilityGroup.newContact)) {
        _focusGroup(_AccessibilityGroup.newContact);
        return;
      }
      if (groups.isNotEmpty) {
        _focusGroup(groups.first);
      }
    });
  }

  void _handleFocusChange() {
    final editing = _isTextInputFocused();
    if (editing == _isEditingText) return;
    if (!mounted) return;
    setState(() {
      _isEditingText = editing;
    });
  }

  bool _handleMenuShortcut(KeyEvent event) {
    if (!widget.state.visible || event is! KeyDownEvent) {
      return false;
    }
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final hasShift = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight) ||
        pressed.contains(LogicalKeyboardKey.shift);
    if (hasShift && event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focusNextGroup();
      return true;
    }
    if (hasShift && event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _focusPreviousGroup();
      return true;
    }
    return false;
  }

  void _announceStepChange() {
    if (!mounted || !widget.state.visible) return;
    final label = _stepLabel(widget.state.currentEntry);
    if (label == null || label == _lastAnnouncedStep) return;
    _lastAnnouncedStep = label;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.state.visible) return;
      final view = View.of(context);
      SemanticsService.sendAnnouncement(
        view,
        label,
        Directionality.of(context),
      );
    });
  }

  String? _stepLabel(AccessibilityStepEntry entry) {
    final l10n = context.l10n;
    switch (entry.kind) {
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
      case AccessibilityStepKind.chatMessages:
        final name = entry.recipients.isNotEmpty
            ? entry.recipients.first.displayName
            : '';
        return name.isNotEmpty ? 'Messages with $name' : 'Messages';
    }
  }
}

bool _isTextInputFocused() {
  final focus = FocusManager.instance.primaryFocus;
  final focusContext = focus?.context;
  if (focusContext == null) return false;
  return focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
}

enum _AccessibilityGroup {
  shortcuts,
  composer,
  newContact,
  sections,
}

class _AccessibilityGroupMarker extends InheritedWidget {
  const _AccessibilityGroupMarker({
    required this.group,
    required super.child,
  });

  final _AccessibilityGroup group;

  static _AccessibilityGroup? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AccessibilityGroupMarker>()
      ?.group;

  @override
  bool updateShouldNotify(covariant _AccessibilityGroupMarker oldWidget) =>
      oldWidget.group != group;
}

class _AccessibilityActionContent extends StatelessWidget {
  const _AccessibilityActionContent({
    required this.state,
    required this.listKey,
    required this.enableActivationShortcut,
    required this.registerGroup,
    required this.unregisterGroup,
    required this.legendFocusNode,
    required this.composerFocusNode,
    required this.newContactFocusNode,
    required this.legendGroupKey,
    required this.composerGroupKey,
    required this.newContactGroupKey,
  });

  final AccessibilityActionState state;
  final GlobalKey<_AccessibilitySectionListState> listKey;
  final bool enableActivationShortcut;
  final void Function(
    _AccessibilityGroup group,
    VoidCallback focus,
  ) registerGroup;
  final void Function(_AccessibilityGroup group) unregisterGroup;
  final FocusNode legendFocusNode;
  final FocusNode composerFocusNode;
  final FocusNode newContactFocusNode;
  final GlobalKey legendGroupKey;
  final GlobalKey composerGroupKey;
  final GlobalKey newContactGroupKey;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
    final breadcrumbLabels = _breadcrumbLabels(state, context);
    final headerTitle = breadcrumbLabels.isNotEmpty
        ? breadcrumbLabels.last
        : _entryLabel(state.currentEntry, context);
    final hasComposer =
        state.currentEntry.kind == AccessibilityStepKind.composer;
    final hasNewContact =
        state.currentEntry.kind == AccessibilityStepKind.newContact;
    final hasSections = state.sections.isNotEmpty;
    const headerOrder = NumericFocusOrder(0);
    const composerOrder = NumericFocusOrder(1);
    const newContactOrder = NumericFocusOrder(1);
    final legendOrder = NumericFocusOrder(hasComposer || hasNewContact ? 2 : 1);
    final statusOrder =
        NumericFocusOrder(hasComposer || hasNewContact ? 1.5 : 1.2);
    final sectionsOrder =
        NumericFocusOrder(hasComposer || hasNewContact ? 3 : 2);

    registerGroup(
      _AccessibilityGroup.shortcuts,
      () => legendFocusNode.requestFocus(),
    );
    if (hasComposer) {
      registerGroup(
        _AccessibilityGroup.composer,
        () => composerFocusNode.requestFocus(),
      );
    } else {
      unregisterGroup(_AccessibilityGroup.composer);
    }
    if (hasNewContact) {
      registerGroup(
        _AccessibilityGroup.newContact,
        () => newContactFocusNode.requestFocus(),
      );
    } else {
      unregisterGroup(_AccessibilityGroup.newContact);
    }
    if (hasSections) {
      registerGroup(
        _AccessibilityGroup.sections,
        () => listKey.currentState?.focusFirstItem(),
      );
    } else {
      unregisterGroup(_AccessibilityGroup.sections);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusTraversalOrder(
          order: headerOrder,
          child: _AccessibilityMenuHeader(
            breadcrumb: headerTitle,
            breadcrumbs: breadcrumbLabels,
            onCrumbSelected: (index) =>
                bloc.add(AccessibilityMenuJumpedTo(index)),
            onBack: state.stack.length > 1
                ? () => bloc.add(const AccessibilityMenuBack())
                : null,
            onClose: () => bloc.add(const AccessibilityMenuClosed()),
          ),
        ),
        const SizedBox(height: 12),
        FocusTraversalOrder(
          order: legendOrder,
          child: _AccessibilityGroupMarker(
            group: _AccessibilityGroup.shortcuts,
            child: _KeyboardShortcutLegend(
              firstEntryFocusNode: legendFocusNode,
              groupKey: legendGroupKey,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (state.statusMessage != null)
          FocusTraversalOrder(
            order: statusOrder,
            child: _AccessibilityBanner(
              message: state.statusMessage!,
              color: context.colorScheme.card,
              foreground: context.colorScheme.foreground,
              icon: Icons.check_circle,
            ),
          ),
        if (state.errorMessage != null)
          FocusTraversalOrder(
            order: statusOrder,
            child: _AccessibilityBanner(
              message: state.errorMessage!,
              color: context.colorScheme.destructive.withValues(alpha: 0.1),
              foreground: context.colorScheme.destructive,
              icon: Icons.error_outline,
            ),
          ),
        if (state.statusMessage != null || state.errorMessage != null)
          const SizedBox(height: 12),
        if (hasComposer)
          FocusTraversalOrder(
            order: composerOrder,
            child: _AccessibilityGroupMarker(
              group: _AccessibilityGroup.composer,
              child: _ComposerSection(
                state: state,
                focusNode: composerFocusNode,
                groupKey: composerGroupKey,
              ),
            ),
          ),
        if (hasNewContact)
          FocusTraversalOrder(
            order: newContactOrder,
            child: _AccessibilityGroupMarker(
              group: _AccessibilityGroup.newContact,
              child: _NewContactSection(
                state: state,
                focusNode: newContactFocusNode,
                groupKey: newContactGroupKey,
              ),
            ),
          ),
        if (hasSections)
          FocusTraversalOrder(
            order: sectionsOrder,
            child: _AccessibilityGroupMarker(
              group: _AccessibilityGroup.sections,
              child: Flexible(
                fit: FlexFit.loose,
                child: Shortcuts(
                  shortcuts: enableActivationShortcut
                      ? {_activateItemActivator: const _ActivateItemIntent()}
                      : const {},
                  child: _AccessibilitySectionList(
                    key: listKey,
                    sections: state.sections,
                    headerLabel: headerTitle,
                    autofocus: !hasComposer && !hasNewContact,
                  ),
                ),
              ),
            ),
          )
        else
          FocusTraversalOrder(
            order: sectionsOrder,
            child: const Flexible(
              fit: FlexFit.loose,
              child: Center(child: Text('No actions available right now')),
            ),
          ),
      ],
    );
  }

  String _entryLabel(
    AccessibilityStepEntry entry,
    BuildContext context,
  ) {
    final l10n = context.l10n;
    switch (entry.kind) {
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
      case AccessibilityStepKind.chatMessages:
        final name = entry.recipients.isNotEmpty
            ? entry.recipients.first.displayName
            : 'Messages';
        return 'Messages with $name';
    }
  }

  List<String> _breadcrumbLabels(
    AccessibilityActionState state,
    BuildContext context,
  ) =>
      state.stack.map((entry) => _entryLabel(entry, context)).toList();
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
              Semantics(
                header: true,
                child: Text(
                  breadcrumb,
                  style: context.textTheme.h3,
                ),
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
              child: Material(
                type: MaterialType.transparency,
                borderRadius: radius,
                child: InkWell(
                  borderRadius: radius,
                  onTap: onSelected == null ? null : () => onSelected!(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      label,
                      style: context.textTheme.small.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
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
      ),
    );
  }
}

class _KeyboardShortcutLegend extends StatelessWidget {
  const _KeyboardShortcutLegend({
    required this.firstEntryFocusNode,
    required this.groupKey,
  });

  final FocusNode firstEntryFocusNode;
  final GlobalKey groupKey;

  @override
  Widget build(BuildContext context) {
    final platformShortcut = findActionShortcut(Theme.of(context).platform);
    final entries = [
      _ShortcutLegendEntry(
        label: 'Open menu',
        shortcut: platformShortcut,
        focusNode: firstEntryFocusNode,
      ),
      const _ShortcutLegendEntry(
        label: 'Back a step or close',
        shortcut: escapeShortcut,
      ),
      const _ShortcutLegendEntry(
        label: 'Next focus target',
        shortcut: _nextFocusShortcut,
      ),
      const _ShortcutLegendEntry(
        label: 'Previous focus target',
        shortcut: _previousFocusShortcut,
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
        label: 'Next group',
        shortcut: _nextGroupShortcut,
      ),
      const _ShortcutLegendEntry(
        label: 'Previous group',
        shortcut: _previousGroupShortcut,
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
      key: groupKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FocusScope(
          child: Builder(
            builder: (context) {
              final hasFocus = FocusScope.of(context).hasFocus;
              final colors = context.colorScheme;
              final borderColor = hasFocus ? colors.primary : colors.border;
              final borderWidth = hasFocus ? 2.5 : 1.0;
              return AnimatedContainer(
                duration: baseAnimationDuration,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: borderWidth),
                  color: colors.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Keyboard shortcuts',
                        style: context.textTheme.small.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: entries,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShortcutLegendEntry extends StatelessWidget {
  const _ShortcutLegendEntry({
    required this.label,
    required this.shortcut,
    this.focusNode,
  });

  final String label;
  final MenuSerializableShortcut shortcut;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textStyle = context.textTheme.small.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final description = '$label, ${shortcutLabel(context, shortcut)}';
    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          final borderColor = hasFocus ? colors.primary : colors.border;
          final borderWidth = hasFocus ? 2.5 : 1.0;
          return Semantics(
            label: 'Keyboard shortcut: $description',
            focusable: true,
            readOnly: true,
            child: AnimatedContainer(
              duration: baseAnimationDuration,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: borderWidth),
                color: colors.muted.withValues(alpha: 0.04),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(label, style: textStyle),
                    ShortcutHint(shortcut: shortcut, dense: true),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComposerSection extends StatelessWidget {
  const _ComposerSection({
    required this.state,
    required this.focusNode,
    required this.groupKey,
  });

  final AccessibilityActionState state;
  final FocusNode focusNode;
  final GlobalKey groupKey;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
    return FocusTraversalGroup(
      key: groupKey,
      policy: WidgetOrderTraversalPolicy(),
      child: Padding(
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
              onChanged: (value) =>
                  bloc.add(AccessibilityComposerChanged(value)),
              hintText: 'Type a message',
              minLines: 3,
              maxLines: 5,
              enabled: !state.busy,
              focusNode: focusNode,
              autofocus: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewContactSection extends StatelessWidget {
  const _NewContactSection({
    required this.state,
    required this.focusNode,
    required this.groupKey,
  });

  final AccessibilityActionState state;
  final FocusNode focusNode;
  final GlobalKey groupKey;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
    return FocusTraversalGroup(
      key: groupKey,
      policy: WidgetOrderTraversalPolicy(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _AccessibilityTextField(
          label: 'Contact address',
          text: state.newContactInput,
          onChanged: (value) => bloc.add(AccessibilityNewContactChanged(value)),
          hintText: 'someone@example.com',
          enabled: !state.busy,
          focusNode: focusNode,
          autofocus: true,
        ),
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
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final String text;
  final ValueChanged<String> onChanged;
  final String hintText;
  final int minLines;
  final int maxLines;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<_AccessibilityTextField> createState() =>
      _AccessibilityTextFieldState();
}

class _AccessibilityTextFieldState extends State<_AccessibilityTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.text);
  late FocusNode _focusNode = widget.focusNode ??
      FocusNode(debugLabel: 'accessibility-text-${widget.label}');
  late bool _ownsFocusNode = widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _AccessibilityTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode && widget.focusNode != null) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode!;
      _ownsFocusNode = false;
      _focusNode.addListener(_onFocusChanged);
    }
    if (oldWidget.text != widget.text && _controller.text != widget.text) {
      _controller.text = widget.text;
      _controller.selection =
          TextSelection.collapsed(offset: widget.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final hasFocus = _focusNode.hasFocus;
    if (widget.autofocus && !_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        }
      });
    }
    final navigationShortcuts = <ShortcutActivator, Intent>{
      _nextGroupActivator: const _NextGroupIntent(),
      _previousGroupActivator: const _PreviousGroupIntent(),
    };
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
          hint:
              'Enter text. Use Tab to move forward or Escape to go back or close the menu.',
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
            child: Shortcuts(
              shortcuts: navigationShortcuts,
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
  const _AccessibilitySectionList({
    super.key,
    required this.sections,
    required this.headerLabel,
    this.autofocus = true,
  });

  final List<AccessibilityMenuSection> sections;
  final String headerLabel;
  final bool autofocus;

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
      final sectionLabel = section.title ?? 'Actions';
      final isDuplicateTitle =
          section.title != null && section.title == widget.headerLabel;
      children.add(
        Semantics(
          container: true,
          label: '$sectionLabel section with ${section.items.length} items',
          child: section.title != null && !isDuplicateTitle
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      section.title!,
                      style: context.textTheme.small.copyWith(
                        color: context.colorScheme.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      );
      for (final item in section.items) {
        final focusNode =
            nodeIndex < _itemNodes.length ? _itemNodes[nodeIndex] : null;
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AccessibilityActionTile(
              item: item,
              index: nodeIndex,
              totalCount: _itemNodes.length,
              sectionLabel: sectionLabel,
              focusNode: focusNode,
              autofocus: widget.autofocus && nodeIndex == 0,
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
          hint:
              'Use arrow keys to move, Shift plus arrows to switch groups, Home or End to jump, Enter to activate, Escape to exit.',
          explicitChildNodes: true,
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
                semanticChildCount: children.length,
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
    _hasFocusedItem = _itemNodes.any((node) => node.hasFocus);
    if (widget.autofocus &&
        _itemNodes.isNotEmpty &&
        _lastFocusedIndex == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          focusFirstItem();
        }
      });
    }
  }

  void activateFocused() {
    final current = _currentIndex();
    if (current == null || current < 0 || current >= _itemNodes.length) return;
    final item = _itemForIndex(current);
    if (item == null ||
        item.disabled ||
        item.kind == AccessibilityMenuItemKind.readOnly) {
      return;
    }
    if (!mounted) return;
    context.read<AccessibilityActionBloc>().add(
          AccessibilityMenuActionTriggered(item.action),
        );
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

  AccessibilityMenuItem? _itemForIndex(int index) {
    var cursor = 0;
    for (final section in widget.sections) {
      for (final item in section.items) {
        if (cursor == index) {
          return item;
        }
        cursor++;
      }
    }
    return null;
  }

  void _focusIndex(int index) {
    if (_itemNodes.isEmpty) return;
    final previousIndex = _lastFocusedIndex;
    final clamped = index.clamp(0, _itemNodes.length - 1);
    final focusNode = _itemNodes[clamped];
    _lastFocusedIndex = clamped;
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
    _scrollToIndex(clamped, previousIndex);
  }

  void _handleFocusChanged(int index, bool hasFocus) {
    if (!mounted) return;
    if (hasFocus) {
      final previousIndex = _lastFocusedIndex;
      _lastFocusedIndex = index;
      _scrollToIndex(index, previousIndex);
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

  void _scrollToIndex(int index, int? previousIndex) {
    if (index < 0 || index >= _itemNodes.length) return;
    final focusContext = _itemNodes[index].context;
    if (focusContext != null) {
      final alignmentPolicy = previousIndex != null && index < previousIndex
          ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
          : ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
      Scrollable.ensureVisible(
        focusContext,
        duration: baseAnimationDuration,
        curve: Curves.easeInOutCubic,
        alignment: previousIndex != null && index < previousIndex ? 0.0 : 1.0,
        alignmentPolicy: alignmentPolicy,
      );
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
    required this.index,
    required this.totalCount,
    required this.sectionLabel,
    required this.onTap,
    this.onDismiss,
    this.focusNode,
    this.autofocus = false,
    this.onFocused,
    this.onFocusChanged,
  });

  final AccessibilityMenuItem item;
  final int index;
  final int totalCount;
  final String sectionLabel;
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
    final isReadOnly = item.kind == AccessibilityMenuItemKind.readOnly;
    final tileColor =
        item.highlight ? scheme.primary.withValues(alpha: 0.08) : scheme.card;
    final foreground =
        item.destructive ? scheme.destructive : scheme.foreground;
    final positionLabel = 'Item ${index + 1} of $totalCount in $sectionLabel';
    final semanticsLabel = [
      item.label,
      if (item.description != null && item.description!.isNotEmpty)
        item.description!,
    ].join(', ');
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      canRequestFocus: true,
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
          final isEnabled = isReadOnly ? true : !item.disabled;
          return Semantics(
            button: !isReadOnly,
            focusable: true,
            label: semanticsLabel,
            enabled: isEnabled,
            value: positionLabel,
            onTap: isReadOnly || item.disabled ? null : onTap,
            hint: isReadOnly
                ? 'Use arrow keys to move through the list'
                : item.disabled
                    ? null
                    : 'Press Enter to activate',
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
                  onTap: isReadOnly || item.disabled ? null : onTap,
                  borderRadius: BorderRadius.circular(14),
                  focusColor: scheme.primary.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                                style:
                                    (textTheme.bodyMedium ?? const TextStyle())
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
                          AxiTooltip(
                            builder: (_) => const Text('Dismiss'),
                            child: Semantics(
                              button: true,
                              label: 'Dismiss highlight',
                              child: IconButton(
                                icon: const Icon(
                                  Icons.notifications_off_outlined,
                                ),
                                onPressed: onDismiss,
                              ),
                            ),
                          ),
                        ],
                      ],
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

class _AccessibilityDismissIntent extends Intent {
  const _AccessibilityDismissIntent();
}

class _NextItemIntent extends Intent {
  const _NextItemIntent();
}

class _PreviousItemIntent extends Intent {
  const _PreviousItemIntent();
}

class _NextGroupIntent extends Intent {
  const _NextGroupIntent();
}

class _PreviousGroupIntent extends Intent {
  const _PreviousGroupIntent();
}

class _FirstItemIntent extends Intent {
  const _FirstItemIntent();
}

class _LastItemIntent extends Intent {
  const _LastItemIntent();
}

class _ActivateItemIntent extends Intent {
  const _ActivateItemIntent();
}
