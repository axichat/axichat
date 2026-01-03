// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
import 'package:axichat/src/accessibility/models/accessibility_action_models.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/chat/view/chat_attachment_preview.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
const bool _accessibilityAutoDownloadAllowed = false;
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

const double _modalMaxWidth = 720;
const double _modalMinHeight = 420;
const double _modalVerticalMargin = 80;
const double _conversationListMinHeight = 200;
const double _conversationListMaxHeight = 360;
const double _conversationListHeightShare = 0.35;
const double _rootListMinHeight = 240;
const double _rootListMaxHeight = 520;
const double _rootListHeightShare = 0.6;

String _stepLabelFor(
  BuildContext context,
  AccessibilityStepEntry entry,
) {
  final l10n = context.l10n;
  switch (entry.kind) {
    case AccessibilityStepKind.root:
      return l10n.accessibilityActionsLabel;
    case AccessibilityStepKind.contactPicker:
      return l10n.accessibilityChooseContact;
    case AccessibilityStepKind.composer:
      return l10n.chatComposerMessageHint;
    case AccessibilityStepKind.unread:
      return l10n.accessibilityUnreadConversations;
    case AccessibilityStepKind.invites:
      return l10n.accessibilityPendingInvites;
    case AccessibilityStepKind.newContact:
      return l10n.accessibilityStartNewAddress;
    case AccessibilityStepKind.chatMessages:
      final name =
          entry.recipients.isNotEmpty ? entry.recipients.first.displayName : '';
      return name.isNotEmpty
          ? l10n.accessibilityMessagesWithContact(name)
          : l10n.accessibilityMessagesTitle;
    case AccessibilityStepKind.conversation:
      final conversationName =
          entry.recipients.isNotEmpty ? entry.recipients.first.displayName : '';
      return conversationName.isNotEmpty
          ? l10n.accessibilityConversationWith(conversationName)
          : l10n.accessibilityConversationLabel;
  }
}

class AccessibilityActionMenu extends StatefulWidget {
  const AccessibilityActionMenu({super.key});

  @override
  State<AccessibilityActionMenu> createState() =>
      _AccessibilityActionMenuState();
}

class _AccessibilityActionMenuState extends State<AccessibilityActionMenu> {
  String? _localeName;
  bool Function(KeyEvent event)? _globalShortcutHandler;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeName = context.l10n.localeName;
    if (_localeName != localeName) {
      _localeName = localeName;
      context.read<AccessibilityActionBloc?>()?.add(
            AccessibilityLocaleUpdated(context.l10n),
          );
    }
  }

  @override
  void initState() {
    super.initState();
    _globalShortcutHandler = _handleGlobalShortcut;
    HardwareKeyboard.instance.addHandler(_globalShortcutHandler!);
  }

  @override
  void dispose() {
    final handler = _globalShortcutHandler;
    if (handler != null) {
      HardwareKeyboard.instance.removeHandler(handler);
    }
    super.dispose();
  }

  bool _handleGlobalShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyK) return false;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final hasMeta = pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.meta);
    final hasControl = pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.control);
    if (!hasMeta && !hasControl) return false;
    final locate = context.read;
    final blocClosed = locate<AccessibilityActionBloc?>()?.isClosed ?? true;
    if (blocClosed) return false;
    locate<AccessibilityActionBloc?>()!.add(const AccessibilityMenuOpened());
    return true;
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

class _AccessibilityMenuScaffoldState extends State<_AccessibilityMenuScaffold>
    with WidgetsBindingObserver {
  final FocusScopeNode _focusScopeNode =
      FocusScopeNode(debugLabel: 'accessibility_menu_scope');
  final GlobalKey<_AccessibilitySectionListState> _sectionsListKey =
      GlobalKey();
  final GlobalKey<_AccessibilitySectionListState> _actionsListKey = GlobalKey();
  final GlobalKey<_MessageCarouselState> _messageCarouselKey = GlobalKey();
  final GlobalKey _legendGroupKey = GlobalKey(debugLabel: 'legend_group');
  final GlobalKey _composerGroupKey = GlobalKey(debugLabel: 'composer_group');
  final GlobalKey _newContactGroupKey =
      GlobalKey(debugLabel: 'new_contact_group');
  final GlobalKey _actionsGroupKey = GlobalKey(debugLabel: 'actions_group');
  final FocusNode _shortcutLegendFocusNode =
      FocusNode(debugLabel: 'accessibility_shortcut_legend');
  final FocusNode _messageFocusNode =
      FocusNode(debugLabel: 'accessibility_message_view');
  final FocusNode _composerFocusNode =
      FocusNode(debugLabel: 'accessibility_composer_field');
  final FocusNode _newContactFocusNode =
      FocusNode(debugLabel: 'accessibility_new_contact_field');
  final FocusNode _actionsFocusNode =
      FocusNode(debugLabel: 'accessibility_actions_group');
  final ScrollController _scrollController = ScrollController();
  final Map<Object, VoidCallback> _groupFocusHandlers =
      <Object, VoidCallback>{};
  final List<Object> _groupOrderList = <Object>[];
  FocusNode? _restoreFocusNode;
  Object? _lastFocusedGroup;
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
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _AccessibilityMenuScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.visible && !_wasVisible) {
      _restoreFocusNode = FocusManager.instance.primaryFocus;
      _lastFocusedGroup = null;
      _scheduleInitialFocus();
      _announceStepChange();
    } else if (!widget.state.visible && _wasVisible) {
      _focusScopeNode.unfocus();
      final previous = _restoreFocusNode;
      _restoreFocusNode = null;
      _lastFocusedGroup = null;
      if (previous != null &&
          previous.context != null &&
          previous.canRequestFocus) {
        previous.requestFocus();
      }
      _lastAnnouncedStep = null;
    }
    if (widget.state.currentEntry != oldWidget.state.currentEntry &&
        widget.state.visible) {
      _scheduleInitialFocus();
    }
    final addedMessageSection = !_hasMessageSection(oldWidget.state) &&
        _hasMessageSection(widget.state);
    if (widget.state.visible && addedMessageSection) {
      _scheduleInitialFocus();
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
    WidgetsBinding.instance.removeObserver(this);
    _shortcutLegendFocusNode.dispose();
    _messageFocusNode.dispose();
    _composerFocusNode.dispose();
    _newContactFocusNode.dispose();
    _actionsFocusNode.dispose();
    _focusScopeNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed && widget.state.visible) {
      _scheduleInitialFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    _resetGroupRegistration();
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
            onTap: () => context
                .read<AccessibilityActionBloc>()
                .add(const AccessibilityMenuClosed()),
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
                    final shouldWarn = _shouldWarnOnExit(widget.state);
                    if (shouldWarn && !widget.state.discardWarningActive) {
                      context.read<AccessibilityActionBloc>().add(
                            const AccessibilityDiscardWarningRequested(),
                          );
                      return null;
                    }
                    if (widget.state.stack.length > 1) {
                      context
                          .read<AccessibilityActionBloc>()
                          .add(const AccessibilityMenuBack());
                    } else {
                      context
                          .read<AccessibilityActionBloc>()
                          .add(const AccessibilityMenuClosed());
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
                  onInvoke: (_) {
                    if (_currentGroup() == _messageCarouselKey) {
                      _messageCarousel?.firstMessage();
                      return null;
                    }
                    _withList((list) => list.focusFirstItem());
                    return null;
                  },
                ),
                _LastItemIntent: CallbackAction<_LastItemIntent>(
                  onInvoke: (_) {
                    if (_currentGroup() == _messageCarouselKey) {
                      _messageCarousel?.lastMessage();
                      return null;
                    }
                    _withList((list) => list.focusLastItem());
                    return null;
                  },
                ),
                _ActivateItemIntent: CallbackAction<_ActivateItemIntent>(
                  onInvoke: (_) {
                    if (_currentGroup() == _messageCarouselKey) {
                      return null;
                    }
                    _withList((list) => list.activateFocused());
                    return null;
                  },
                ),
              },
              child: FocusScope(
                node: _focusScopeNode,
                autofocus: true,
                child: Builder(builder: (context) {
                  final viewSize = MediaQuery.sizeOf(context);
                  final modalMinHeight = viewSize.height < _modalMinHeight
                      ? viewSize.height
                      : _modalMinHeight;
                  final rawTargetHeight =
                      viewSize.height - _modalVerticalMargin;
                  final modalHeight = rawTargetHeight
                      .clamp(modalMinHeight, viewSize.height)
                      .toDouble();
                  return ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _modalMaxWidth,
                    ),
                    child: SizedBox(
                      height: modalHeight,
                      child: AxiModalSurface(
                        padding: const EdgeInsets.all(20),
                        child: Material(
                          type: MaterialType.transparency,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final viewportHeight = constraints.maxHeight;
                              return Semantics(
                                scopesRoute: true,
                                namesRoute: true,
                                label: context.l10n.accessibilityDialogLabel,
                                hint: context.l10n.accessibilityDialogHint,
                                explicitChildNodes: true,
                                child: Scrollbar(
                                  controller: _scrollController,
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    physics: const ClampingScrollPhysics(),
                                    padding: const EdgeInsets.only(bottom: 16),
                                    clipBehavior: Clip.hardEdge,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: viewportHeight,
                                      ),
                                      child: FocusTraversalGroup(
                                        policy: OrderedTraversalPolicy(),
                                        child: _AccessibilityActionContent(
                                          state: widget.state,
                                          sectionsListKey: _sectionsListKey,
                                          actionsListKey: _actionsListKey,
                                          enableActivationShortcut:
                                              !_isEditingText,
                                          registerGroup: _registerGroup,
                                          unregisterGroup: _unregisterGroup,
                                          legendFocusNode:
                                              _shortcutLegendFocusNode,
                                          messageFocusNode: _messageFocusNode,
                                          composerFocusNode: _composerFocusNode,
                                          newContactFocusNode:
                                              _newContactFocusNode,
                                          legendGroupKey: _legendGroupKey,
                                          messageCarouselKey:
                                              _messageCarouselKey,
                                          composerGroupKey: _composerGroupKey,
                                          actionsGroupKey: _actionsGroupKey,
                                          actionsFocusNode: _actionsFocusNode,
                                          newContactGroupKey:
                                              _newContactGroupKey,
                                          viewportHeight: viewportHeight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _resetGroupRegistration() {
    _groupFocusHandlers.clear();
    _groupOrderList.clear();
  }

  void _withList(void Function(_AccessibilitySectionListState list) action) {
    final group = _currentGroup();
    final list = _listForGroup(group);
    if (list == null || list.isEditingText) return;
    action(list);
  }

  _MessageCarouselState? get _messageCarousel =>
      _messageCarouselKey.currentState;

  _AccessibilitySectionListState? _listForGroup(Object? group) {
    if (group == _actionsListKey) {
      return _actionsListKey.currentState;
    }
    if (group == _sectionsListKey) {
      return _sectionsListKey.currentState;
    }
    return null;
  }

  void _handleDirectionalMove({required bool forward}) {
    final current = _currentGroup();
    if (current == _messageCarouselKey) {
      final carousel = _messageCarousel;
      if (carousel != null) {
        forward ? carousel.nextMessage() : carousel.previousMessage();
      }
      return;
    }
    if (current == _composerGroupKey) {
      _moveWithinGroup(_composerGroupKey, forward: forward);
      return;
    }
    if (current == _newContactGroupKey) {
      _moveWithinGroup(_newContactGroupKey, forward: forward);
      return;
    }
    if (current == _actionsGroupKey) {
      _moveWithinGroup(_actionsGroupKey, forward: forward);
      return;
    }
    if (current == _legendGroupKey) {
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
    Object group,
    VoidCallback focusCallback,
  ) {
    if (!_groupOrderList.contains(group)) {
      _groupOrderList.add(group);
    }
    _groupFocusHandlers[group] = focusCallback;
  }

  void _unregisterGroup(Object group) {
    _groupFocusHandlers.remove(group);
    _groupOrderList.remove(group);
  }

  List<Object> _groupOrder() => List<Object>.unmodifiable(_groupOrderList);

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

  void _focusGroup(Object group) {
    final handler = _groupFocusHandlers[group];
    if (handler == null) return;
    _lastFocusedGroup = group;
    _focusScopeNode.requestFocus();
    handler();
    _scrollGroupIntoView(group);
  }

  void _scrollGroupIntoView(Object group) {
    final context = _groupContext(group);
    if (context == null) return;
    _ensureVisible(context);
  }

  BuildContext? _groupContext(Object group) {
    if (group is GlobalKey) {
      return group.currentContext;
    }
    return null;
  }

  Object? _currentGroup() {
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focusContext == null) return null;
    return _AccessibilityGroupMarker.maybeOf(focusContext);
  }

  bool _hasMessageSection(AccessibilityActionState state) =>
      state.sections.any((section) => section.id == 'chat-messages');

  bool _shouldWarnOnExit(AccessibilityActionState state) {
    final entry = state.currentEntry;
    if (entry.kind == AccessibilityStepKind.composer ||
        entry.kind == AccessibilityStepKind.chatMessages ||
        entry.kind == AccessibilityStepKind.conversation) {
      return state.composerText.trim().isNotEmpty;
    }
    if (entry.kind == AccessibilityStepKind.newContact) {
      return state.newContactInput.trim().isNotEmpty;
    }
    return false;
  }

  void _scheduleInitialFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusScopeNode.requestFocus();
      final groups = _groupOrder();
      Object? target =
          _lastFocusedGroup != null && groups.contains(_lastFocusedGroup)
              ? _lastFocusedGroup
              : null;
      target ??= groups.firstWhere((group) => group != _legendGroupKey,
          orElse: () => _legendGroupKey);
      if (target == _legendGroupKey && groups.isNotEmpty) {
        target = groups.first;
      }
      _focusGroup(target);
    });
  }

  void _handleFocusChange() {
    final editing = _isTextInputFocused();
    if (!mounted) return;
    if (editing != _isEditingText) {
      setState(() {
        _isEditingText = editing;
      });
    }
    final primary = FocusManager.instance.primaryFocus;
    final primaryContext = primary?.context;
    if (widget.state.visible && primaryContext != null) {
      _ensureVisible(primaryContext);
    }
    if (widget.state.visible &&
        (primary == null || primary.context == null) &&
        _groupOrder().isNotEmpty) {
      _scheduleInitialFocus();
    }
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

  void _ensureVisible(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.state.visible) return;
      Scrollable.ensureVisible(
        context,
        duration: baseAnimationDuration,
        curve: Curves.easeInOutCubic,
        alignment: 0.1,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  String? _stepLabel(AccessibilityStepEntry entry) =>
      _stepLabelFor(context, entry);
}

bool _isTextInputFocused() {
  final focus = FocusManager.instance.primaryFocus;
  final focusContext = focus?.context;
  if (focusContext == null) return false;
  return focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
}

class _AccessibilityGroupMarker extends InheritedWidget {
  const _AccessibilityGroupMarker({
    required this.group,
    required super.child,
  });

  final Object group;

  static Object? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AccessibilityGroupMarker>()
      ?.group;

  @override
  bool updateShouldNotify(covariant _AccessibilityGroupMarker oldWidget) =>
      oldWidget.group != group;
}

class _AccessibilityActionContent extends StatelessWidget {
  const _AccessibilityActionContent({
    required this.state,
    required this.sectionsListKey,
    required this.actionsListKey,
    required this.enableActivationShortcut,
    required this.registerGroup,
    required this.unregisterGroup,
    required this.legendFocusNode,
    required this.messageFocusNode,
    required this.composerFocusNode,
    required this.newContactFocusNode,
    required this.legendGroupKey,
    required this.messageCarouselKey,
    required this.composerGroupKey,
    required this.actionsGroupKey,
    required this.actionsFocusNode,
    required this.newContactGroupKey,
    required this.viewportHeight,
  });

  final AccessibilityActionState state;
  final GlobalKey<_AccessibilitySectionListState> sectionsListKey;
  final GlobalKey<_AccessibilitySectionListState> actionsListKey;
  final bool enableActivationShortcut;
  final void Function(
    Object group,
    VoidCallback focus,
  ) registerGroup;
  final void Function(Object group) unregisterGroup;
  final FocusNode legendFocusNode;
  final FocusNode messageFocusNode;
  final FocusNode composerFocusNode;
  final FocusNode newContactFocusNode;
  final FocusNode actionsFocusNode;
  final GlobalKey legendGroupKey;
  final GlobalKey<_MessageCarouselState> messageCarouselKey;
  final GlobalKey composerGroupKey;
  final GlobalKey actionsGroupKey;
  final GlobalKey newContactGroupKey;
  final double viewportHeight;

  @override
  Widget build(BuildContext context) {
    final breadcrumbLabels = _breadcrumbLabels(state, context);
    final headerTitle = breadcrumbLabels.isNotEmpty
        ? breadcrumbLabels.last
        : _entryLabel(state.currentEntry, context);
    final isConversation =
        state.currentEntry.kind == AccessibilityStepKind.composer ||
            state.currentEntry.kind == AccessibilityStepKind.chatMessages ||
            state.currentEntry.kind == AccessibilityStepKind.conversation;
    final hasComposer = isConversation;
    final hasNewContact =
        state.currentEntry.kind == AccessibilityStepKind.newContact;
    final messageSections = state.sections
        .where((section) => section.id == 'chat-messages')
        .toList();
    final messageSection =
        messageSections.isNotEmpty ? messageSections.first : null;
    final actionSections = hasNewContact
        ? <AccessibilityMenuSection>[]
        : state.sections
            .where((section) => section.id != 'chat-messages')
            .toList();
    final hasMessages = messageSections.isNotEmpty;
    final hasSections = actionSections.isNotEmpty;
    final conversationListHeight = _conversationListHeight(viewportHeight);
    final rootListHeight = _rootListHeight(viewportHeight);
    const headerOrder = NumericFocusOrder(0);
    const statusOrder = NumericFocusOrder(1);
    const legendOrder = NumericFocusOrder(2);
    const messagesOrder = NumericFocusOrder(3);
    const composerOrder = NumericFocusOrder(4);
    const newContactOrder = NumericFocusOrder(3);
    const actionsOrder = NumericFocusOrder(5);
    const actionsListOrder = NumericFocusOrder(6);
    const sectionsOrder = NumericFocusOrder(4);

    registerGroup(
      legendGroupKey,
      () => legendFocusNode.requestFocus(),
    );
    if (hasMessages) {
      registerGroup(
        messageCarouselKey,
        () => messageCarouselKey.currentState?.focusInitial(),
      );
    }
    if (hasComposer) {
      registerGroup(
        composerGroupKey,
        () => composerFocusNode.requestFocus(),
      );
    }
    final shouldShowActionsGroup = isConversation;
    if (shouldShowActionsGroup) {
      registerGroup(
        actionsGroupKey,
        () => actionsFocusNode.requestFocus(),
      );
    }
    if (isConversation && hasSections) {
      registerGroup(
        actionsListKey,
        () => actionsListKey.currentState?.focusInitial(fallbackIndex: 0),
      );
    }
    if (hasNewContact) {
      registerGroup(
        newContactGroupKey,
        () => newContactFocusNode.requestFocus(),
      );
    }
    if (!isConversation && hasSections) {
      registerGroup(
        sectionsListKey,
        () => sectionsListKey.currentState?.focusInitial(),
      );
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
            onCrumbSelected: (index) => context
                .read<AccessibilityActionBloc>()
                .add(AccessibilityMenuJumpedTo(index)),
            onBack: state.stack.length > 1
                ? () => context
                    .read<AccessibilityActionBloc>()
                    .add(const AccessibilityMenuBack())
                : null,
            onClose: () => context
                .read<AccessibilityActionBloc>()
                .add(const AccessibilityMenuClosed()),
          ),
        ),
        const SizedBox(height: 12),
        FocusTraversalOrder(
          order: legendOrder,
          child: _AccessibilityGroupMarker(
            group: legendGroupKey,
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
        if (hasMessages)
          FocusTraversalOrder(
            order: messagesOrder,
            child: _AccessibilityGroupMarker(
              group: messageCarouselKey,
              child: _MessageCarousel(
                key: messageCarouselKey,
                section: messageSection!,
                focusNode: messageFocusNode,
                initialIndex: state.messageInitialIndex ?? 0,
              ),
            ),
          ),
        if (hasMessages) const SizedBox(height: 10),
        if (hasComposer)
          FocusTraversalOrder(
            order: composerOrder,
            child: _AccessibilityGroupMarker(
              group: composerGroupKey,
              child: _ComposerSection(
                state: state,
                focusNode: composerFocusNode,
                groupKey: composerGroupKey,
              ),
            ),
          ),
        if (isConversation)
          FocusTraversalOrder(
            order: actionsOrder,
            child: _AccessibilityGroupMarker(
              group: actionsGroupKey,
              child: _ActionButtonsGroup(
                focusNode: actionsFocusNode,
                groupKey: actionsGroupKey,
                saveEnabled: state.composerText.trim().isNotEmpty &&
                    state.recipients.isNotEmpty &&
                    !state.busy,
                sendEnabled: state.composerText.trim().isNotEmpty &&
                    state.recipients.isNotEmpty &&
                    !state.busy,
                onSave: () => context.read<AccessibilityActionBloc>().add(
                      const AccessibilityMenuActionTriggered(
                        AccessibilityCommandAction(
                          command: AccessibilityCommand.saveDraft,
                        ),
                      ),
                    ),
                onSend: () => context.read<AccessibilityActionBloc>().add(
                      const AccessibilityMenuActionTriggered(
                        AccessibilityCommandAction(
                          command: AccessibilityCommand.sendMessage,
                        ),
                      ),
                    ),
              ),
            ),
          ),
        if (hasNewContact)
          FocusTraversalOrder(
            order: newContactOrder,
            child: _AccessibilityGroupMarker(
              group: newContactGroupKey,
              child: _NewContactSection(
                state: state,
                focusNode: newContactFocusNode,
                groupKey: newContactGroupKey,
              ),
            ),
          ),
        if (isConversation && hasSections) const SizedBox(height: 10),
        if (isConversation && hasSections)
          SizedBox(
            height: conversationListHeight,
            child: FocusTraversalOrder(
              order: actionsListOrder,
              child: _AccessibilityGroupMarker(
                group: actionsListKey,
                child: Shortcuts(
                  shortcuts: enableActivationShortcut
                      ? {_activateItemActivator: const _ActivateItemIntent()}
                      : const {},
                  child: _AccessibilitySectionList(
                    key: actionsListKey,
                    sections: actionSections,
                    headerLabel: headerTitle,
                    autofocus: false,
                    initialIndex: 0,
                  ),
                ),
              ),
            ),
          ),
        if (!isConversation && hasSections)
          SizedBox(
            height: rootListHeight,
            child: FocusTraversalOrder(
              order: sectionsOrder,
              child: _AccessibilityGroupMarker(
                group: sectionsListKey,
                child: Shortcuts(
                  shortcuts: enableActivationShortcut
                      ? {_activateItemActivator: const _ActivateItemIntent()}
                      : const {},
                  child: _AccessibilitySectionList(
                    key: sectionsListKey,
                    sections: actionSections,
                    headerLabel: headerTitle,
                    autofocus: !hasComposer && !hasNewContact && !hasMessages,
                  ),
                ),
              ),
            ),
          )
        else if (!isConversation && !hasSections && !hasNewContact)
          SizedBox(
            height: rootListHeight,
            child: FocusTraversalOrder(
              order: sectionsOrder,
              child: Center(
                child: Text(context.l10n.accessibilityNoActionsAvailable),
              ),
            ),
          ),
      ],
    );
  }

  double _conversationListHeight(double viewportHeight) {
    final heightFromViewport = viewportHeight * _conversationListHeightShare;
    final boundedHeight = heightFromViewport.clamp(
      _conversationListMinHeight,
      _conversationListMaxHeight,
    );
    return boundedHeight.toDouble();
  }

  double _rootListHeight(double viewportHeight) {
    final heightFromViewport = viewportHeight * _rootListHeightShare;
    final boundedHeight = heightFromViewport.clamp(
      _rootListMinHeight,
      _rootListMaxHeight,
    );
    return boundedHeight.toDouble();
  }

  String _entryLabel(
    AccessibilityStepEntry entry,
    BuildContext context,
  ) {
    return _stepLabelFor(context, entry);
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
            label: context.l10n
                .accessibilityBreadcrumbLabel(index + 1, total, label),
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
    final l10n = context.l10n;
    final platformShortcut = findActionShortcut(Theme.of(context).platform);
    final entries = [
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutOpenMenu,
        shortcut: platformShortcut,
        focusNode: firstEntryFocusNode,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutBack,
        shortcut: escapeShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutNextFocus,
        shortcut: _nextFocusShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutPreviousFocus,
        shortcut: _previousFocusShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutActivateItem,
        shortcut: _activateShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutNextItem,
        shortcut: _nextItemShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutPreviousItem,
        shortcut: _previousItemShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutNextGroup,
        shortcut: _nextGroupShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutPreviousGroup,
        shortcut: _previousGroupShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutFirstItem,
        shortcut: _firstItemShortcut,
      ),
      _ShortcutLegendEntry(
        label: l10n.accessibilityShortcutLastItem,
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
              return SizedBox(
                width: double.infinity,
                child: AnimatedContainer(
                  duration: baseAnimationDuration,
                  padding: const EdgeInsets.all(5),
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
                          l10n.accessibilityKeyboardShortcutsTitle,
                          style: context.textTheme.small.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 2,
                        runSpacing: 1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: entries,
                      ),
                    ],
                  ),
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
            label: context.l10n
                .accessibilityKeyboardShortcutAnnouncement(description),
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 2,
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
    return FocusTraversalGroup(
      key: groupKey,
      policy: OrderedTraversalPolicy(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FocusTraversalOrder(
              order: const NumericFocusOrder(0),
              child: _AccessibilityTextField(
                label: context.l10n.chatComposerMessageHint,
                text: state.composerText,
                onChanged: (value) => context
                    .read<AccessibilityActionBloc>()
                    .add(AccessibilityComposerChanged(value)),
                hintText: context.l10n.accessibilityComposerPlaceholder,
                minLines: 3,
                maxLines: 5,
                enabled: !state.busy,
                focusNode: focusNode,
                autofocus: false,
              ),
            ),
            const SizedBox(height: 8),
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: Material(
                type: MaterialType.transparency,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.recipients
                      .map(
                        (recipient) => Semantics(
                          label: context.l10n.accessibilityRecipientLabel(
                              recipient.displayName),
                          button: true,
                          hint: context.l10n.accessibilityRecipientRemoveHint,
                          child: InputChip(
                            label: Text(recipient.displayName),
                            onDeleted: () =>
                                context.read<AccessibilityActionBloc>().add(
                                      AccessibilityRecipientRemoved(
                                        recipient.jid,
                                      ),
                                    ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtonsGroup extends StatelessWidget {
  const _ActionButtonsGroup({
    required this.focusNode,
    required this.groupKey,
    required this.saveEnabled,
    required this.sendEnabled,
    required this.onSave,
    required this.onSend,
  });

  final FocusNode focusNode;
  final GlobalKey groupKey;
  final bool saveEnabled;
  final bool sendEnabled;
  final VoidCallback onSave;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return FocusTraversalGroup(
      key: groupKey,
      policy: OrderedTraversalPolicy(),
      child: Focus(
        focusNode: focusNode,
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            final borderColor = hasFocus ? colors.primary : colors.border;
            final borderWidth = hasFocus ? 3.0 : 1.2;
            final isNarrow = MediaQuery.sizeOf(context).width < 460;
            final saveButton = ShadButton.outline(
              onPressed: saveEnabled ? onSave : null,
              child: Text(context.l10n.draftSave),
            );
            final sendButton = ShadButton(
              onPressed: sendEnabled ? onSend : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.commonSend),
                  const SizedBox(width: 8),
                  const ShortcutHint(
                    shortcut: _activateShortcut,
                    dense: true,
                  ),
                ],
              ),
            );
            final buttons = isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      saveButton,
                      const SizedBox(height: 8),
                      sendButton,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: saveButton),
                      const SizedBox(width: 12),
                      Expanded(child: sendButton),
                    ],
                  );
            return Semantics(
              container: true,
              label: context.l10n.accessibilityMessageActionsLabel,
              hint: context.l10n.accessibilityMessageActionsHint,
              child: AnimatedContainer(
                duration: baseAnimationDuration,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: buttons,
              ),
            );
          },
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
    final colors = context.colorScheme;
    final radius = BorderRadius.circular(14);
    final canSubmit = state.newContactInput.trim().isValidJid;
    final locate = context.read;
    return FocusTraversalGroup(
      key: groupKey,
      policy: WidgetOrderTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AccessibilityTextField(
              label: context.l10n.accessibilityNewContactLabel,
              text: state.newContactInput,
              onChanged: (value) => locate<AccessibilityActionBloc>().add(
                AccessibilityNewContactChanged(value),
              ),
              hintText: context.l10n.accessibilityNewContactHint,
              enabled: !state.busy,
              focusNode: focusNode,
              autofocus: true,
            ),
          ),
          Focus(
            child: Builder(
              builder: (context) {
                final hasFocus = Focus.of(context).hasFocus;
                final borderColor = hasFocus ? colors.primary : colors.border;
                final borderWidth = hasFocus ? 3.0 : 1.2;
                return Semantics(
                  container: true,
                  button: true,
                  enabled: canSubmit,
                  label: context.l10n.accessibilityStartChat,
                  hint: context.l10n.accessibilityStartChatHint,
                  child: AnimatedContainer(
                    duration: baseAnimationDuration,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: radius,
                      border: Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ShadButton(
                        onPressed: canSubmit
                            ? () => locate<AccessibilityActionBloc>().add(
                                  const AccessibilityMenuActionTriggered(
                                    AccessibilityCommandAction(
                                      command: AccessibilityCommand
                                          .confirmNewContact,
                                    ),
                                  ),
                                )
                            : null,
                        child: Text(context.l10n.accessibilityStartChat),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
  bool _didAutofocus = false;

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
      _didAutofocus = false;
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
    if (widget.autofocus && !_focusNode.hasFocus && !_didAutofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_focusNode.canRequestFocus) {
          _focusNode.requestFocus();
          _didAutofocus = true;
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
          hint: context.l10n.accessibilityTextFieldHint,
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
              child: AxiTextInput(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                placeholder: Text(widget.hintText),
                onChanged: widget.onChanged,
                decoration: const ShadDecoration(
                  border: ShadBorder.none,
                  focusedBorder: ShadBorder.none,
                  errorBorder: ShadBorder.none,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageCarousel extends StatefulWidget {
  const _MessageCarousel({
    super.key,
    required this.section,
    required this.focusNode,
    required this.initialIndex,
  });

  final AccessibilityMenuSection section;
  final FocusNode focusNode;
  final int initialIndex;

  @override
  State<_MessageCarousel> createState() => _MessageCarouselState();
}

class _MessageCarouselState extends State<_MessageCarousel> {
  late int _currentIndex = _clampIndex(widget.initialIndex);
  bool _appliedInitial = false;

  List<AccessibilityMenuItem> get _items => widget.section.items;

  @override
  void didUpdateWidget(covariant _MessageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemCountChanged = _items.length != oldWidget.section.items.length;
    final initialChanged = widget.initialIndex != oldWidget.initialIndex;
    final targetIndex = _clampIndex(widget.initialIndex);
    final clampedCurrent = _clampIndex(_currentIndex);
    if (itemCountChanged || initialChanged) {
      if (_currentIndex != targetIndex) {
        setState(() {
          _currentIndex = targetIndex;
        });
      } else if (clampedCurrent != _currentIndex) {
        setState(() {
          _currentIndex = clampedCurrent;
        });
      }
      _appliedInitial = false;
      return;
    }
    if (clampedCurrent != _currentIndex) {
      setState(() {
        _currentIndex = clampedCurrent;
      });
    }
  }

  void focusInitial() {
    if (!_appliedInitial) {
      _setIndex(_clampIndex(widget.initialIndex));
      _appliedInitial = true;
      return;
    }
    _requestFocus();
  }

  void focusCurrent() => _requestFocus();
  void nextMessage() => _setIndex(_currentIndex + 1);
  void previousMessage() => _setIndex(_currentIndex - 1);
  void firstMessage() => _setIndex(0);
  void lastMessage() => _setIndex(_items.isEmpty ? 0 : _items.length - 1);

  int _clampIndex(int value) {
    if (_items.isEmpty) return 0;
    return value.clamp(0, _items.length - 1);
  }

  void _setIndex(int value) {
    final clamped = _clampIndex(value);
    if (clamped != _currentIndex) {
      setState(() {
        _currentIndex = clamped;
      });
    }
    _requestFocus();
  }

  void _requestFocus() {
    if (widget.focusNode.canRequestFocus) {
      widget.focusNode.requestFocus();
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final logicalKey = event.logicalKey;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final hasShift = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight) ||
        pressed.contains(LogicalKeyboardKey.shift);
    if (hasShift &&
        (logicalKey == LogicalKeyboardKey.arrowDown ||
            logicalKey == LogicalKeyboardKey.arrowUp)) {
      return KeyEventResult.ignored;
    }
    if (logicalKey == LogicalKeyboardKey.arrowDown) {
      nextMessage();
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.arrowUp) {
      previousMessage();
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.home) {
      firstMessage();
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.end) {
      lastMessage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final scheme = context.colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasFocus = widget.focusNode.hasFocus;
    final hasItems = items.isNotEmpty;
    final clampedIndex =
        _currentIndex.clamp(0, hasItems ? items.length - 1 : 0);
    final currentItem = hasItems ? items[clampedIndex] : null;
    final currentMessage = currentItem?.message;
    final attachment = currentItem?.attachment;
    final showMetadata = currentItem?.showMetadata ?? false;
    final senderLabel = currentItem?.senderLabel ?? '';
    final timestampLabel = currentItem?.timestampLabel ?? '';
    final attachmentLabel = currentItem?.attachmentLabel;
    final rawBody = (currentMessage?.body ?? '').trim();
    final positionLabel = hasItems
        ? context.l10n.accessibilityMessagePosition(
            clampedIndex + 1,
            items.length,
          )
        : context.l10n.accessibilityNoMessages;
    final metadataValue = showMetadata && senderLabel.isNotEmpty
        ? (timestampLabel.isNotEmpty
            ? context.l10n
                .accessibilityMessageMetadata(senderLabel, timestampLabel)
            : context.l10n.accessibilityMessageFrom(senderLabel))
        : null;
    final borderColor = hasFocus ? scheme.primary : scheme.border;
    final borderWidth = hasFocus ? 3.0 : 1.0;
    final borderRadius = BorderRadius.circular(16);
    final shadows = hasFocus
        ? [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ]
        : const <BoxShadow>[];
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _handleKey,
      child: Semantics(
        container: true,
        focusable: true,
        label: positionLabel,
        value: metadataValue,
        hint: context.l10n.accessibilityMessageNavigationHint,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: AnimatedContainer(
            duration: baseAnimationDuration,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasFocus
                  ? scheme.primary.withValues(alpha: 0.06)
                  : scheme.card,
              borderRadius: borderRadius,
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: shadows,
            ),
            child: AnimatedSize(
              duration: baseAnimationDuration,
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    positionLabel,
                    style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                      color: scheme.mutedForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (showMetadata && senderLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        metadataValue ??
                            context.l10n.accessibilityMessageFrom(senderLabel),
                        style:
                            (textTheme.bodySmall ?? const TextStyle()).copyWith(
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ),
                  if (rawBody.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        rawBody,
                        style: (textTheme.bodyMedium ?? const TextStyle())
                            .copyWith(
                          color: scheme.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (attachment != null)
                    Semantics(
                      label: attachmentLabel ??
                          context.l10n.accessibilityAttachmentGeneric,
                      child: ChatAttachmentPreview(
                        stanzaId: currentMessage?.stanzaID ?? '',
                        metadataStream:
                            Stream<FileMetadataData?>.value(attachment),
                        allowed: true,
                        autoDownloadSettings: context
                            .read<SettingsCubit>()
                            .state
                            .attachmentAutoDownloadSettings,
                        autoDownloadAllowed: _accessibilityAutoDownloadAllowed,
                      ),
                    )
                  else if (attachmentLabel != null && rawBody.isEmpty)
                    Text(
                      attachmentLabel,
                      style:
                          (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                        color: scheme.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (rawBody.isEmpty &&
                      attachment == null &&
                      (attachmentLabel == null || attachmentLabel.isEmpty))
                    Text(
                      context.l10n.accessibilityMessageNoContent,
                      style:
                          (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessibilitySectionList extends StatefulWidget {
  const _AccessibilitySectionList({
    super.key,
    required this.sections,
    required this.headerLabel,
    this.autofocus = true,
    this.initialIndex,
  });

  final List<AccessibilityMenuSection> sections;
  final String headerLabel;
  final bool autofocus;
  final int? initialIndex;

  @override
  State<_AccessibilitySectionList> createState() =>
      _AccessibilitySectionListState();
}

class _AccessibilitySectionListState extends State<_AccessibilitySectionList> {
  final ScrollController _scrollController = ScrollController();
  List<FocusNode> _itemNodes = <FocusNode>[];
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
  void focusInitial({int? fallbackIndex}) {
    final current = _currentIndex();
    if (current != null) {
      _focusIndex(current);
      return;
    }
    _focusIndex(fallbackIndex ?? widget.initialIndex ?? 0);
  }

  void focusNextItem() {
    final current = _currentIndex();
    _focusIndex(current == null ? 0 : current + 1);
  }

  void focusPreviousItem() {
    final current = _currentIndex();
    _focusIndex(current == null ? 0 : current - 1);
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var nodeIndex = 0;
    final colors = context.colorScheme;
    for (var sectionIndex = 0;
        sectionIndex < widget.sections.length;
        sectionIndex++) {
      final section = widget.sections[sectionIndex];
      final sectionLabel =
          section.title ?? context.l10n.accessibilityActionsTitle;
      final isDuplicateTitle =
          section.title != null && section.title == widget.headerLabel;
      children.add(
        Semantics(
          container: true,
          label: context.l10n.accessibilitySectionSummary(
            sectionLabel,
            section.items.length,
          ),
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
              onTap: () => context
                  .read<AccessibilityActionBloc>()
                  .add(AccessibilityMenuActionTriggered(item.action)),
              onDismiss: item.dismissId == null
                  ? null
                  : () => context.read<AccessibilityActionBloc>().add(
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
        final borderColor = _hasFocusedItem ? colors.primary : colors.border;
        final borderWidth = _hasFocusedItem ? 3.0 : 1.0;
        return Semantics(
          container: true,
          label: context.l10n.accessibilityActionListLabel(_itemNodes.length),
          hint: context.l10n.accessibilityActionListHint,
          explicitChildNodes: true,
          child: AnimatedContainer(
            duration: baseAnimationDuration,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: ListView.builder(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              semanticChildCount: children.length,
              itemCount: children.length,
              itemBuilder: (context, index) => children[index],
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
          final target =
              (widget.initialIndex ?? 0).clamp(0, _itemNodes.length - 1);
          _focusIndex(target);
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
    if (focusContext == null) return;
    final renderObject = focusContext.findRenderObject();
    if (_scrollController.hasClients && renderObject != null) {
      final viewport = RenderAbstractViewport.of(renderObject);
      final position = _scrollController.position;
      final movingUp = previousIndex != null && index < previousIndex;
      final alignment = movingUp ? 0.05 : 0.95;
      final target = viewport
          .getOffsetToReveal(
            renderObject,
            alignment,
          )
          .offset;
      final clampedTarget = target.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      position.animateTo(
        clampedTarget,
        duration: baseAnimationDuration,
        curve: Curves.easeInOutCubic,
      );
      return;
    }
    final movingUp = previousIndex != null && index < previousIndex;
    final alignmentPolicy = movingUp
        ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
        : ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
    Scrollable.ensureVisible(
      focusContext,
      duration: baseAnimationDuration,
      curve: Curves.easeInOutCubic,
      alignment: movingUp ? 0.05 : 0.95,
      alignmentPolicy: alignmentPolicy,
    );
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
    final positionLabel = context.l10n.accessibilityActionItemPosition(
      index + 1,
      totalCount,
      sectionLabel,
    );
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
                ? context.l10n.accessibilityActionReadOnlyHint
                : item.disabled
                    ? null
                    : context.l10n.accessibilityActionActivateHint,
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
                            builder: (_) => Text(context.l10n.commonDismiss),
                            child: Semantics(
                              button: true,
                              label: context.l10n.accessibilityDismissHighlight,
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
