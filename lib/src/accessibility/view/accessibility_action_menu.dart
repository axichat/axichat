import 'package:axichat/src/accessibility/bloc/accessibility_action_bloc.dart';
import 'package:axichat/src/accessibility/models/accessibility_action_models.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/accessibility/view/shortcut_hint.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

class _AccessibilityMenuScaffold extends StatelessWidget {
  const _AccessibilityMenuScaffold({required this.state});

  final AccessibilityActionState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
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
            shortcuts: const {
              escapeShortcut: _AccessibilityDismissIntent(),
            },
            child: Actions(
              actions: {
                _AccessibilityDismissIntent:
                    CallbackAction<_AccessibilityDismissIntent>(
                  onInvoke: (_) {
                    if (state.stack.length > 1) {
                      bloc.add(const AccessibilityMenuBack());
                    } else {
                      bloc.add(const AccessibilityMenuClosed());
                    }
                    return null;
                  },
                ),
              },
              child: FocusScope(
                autofocus: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 720,
                    maxHeight: 640,
                  ),
                  child: AxiModalSurface(
                    padding: const EdgeInsets.all(20),
                    child: _AccessibilityActionContent(state: state),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccessibilityActionContent extends StatelessWidget {
  const _AccessibilityActionContent({required this.state});

  final AccessibilityActionState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
    final headerTitle = _headerLabelFor(state.currentEntry.kind, context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _AccessibilityMenuHeader(
          breadcrumb: headerTitle,
          onBack: state.stack.length > 1
              ? () => bloc.add(const AccessibilityMenuBack())
              : null,
          onClose: () => bloc.add(const AccessibilityMenuClosed()),
        ),
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
            child: _AccessibilitySectionList(sections: state.sections),
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
        return 'Find action';
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
}

class _AccessibilityMenuHeader extends StatelessWidget {
  const _AccessibilityMenuHeader({
    required this.breadcrumb,
    required this.onClose,
    this.onBack,
  });

  final String breadcrumb;
  final VoidCallback onClose;
  final VoidCallback? onBack;

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
                    (recipient) => InputChip(
                      label: Text(recipient.displayName),
                      onDeleted: () => bloc.add(
                        AccessibilityRecipientRemoved(recipient.jid),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: context.textTheme.small,
        ),
        const SizedBox(height: 6),
        ShadInput(
          controller: _controller,
          enabled: widget.enabled,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          placeholder: Text(widget.hintText),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

class _AccessibilitySectionList extends StatelessWidget {
  const _AccessibilitySectionList({required this.sections});

  final List<AccessibilityMenuSection> sections;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AccessibilityActionBloc>();
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: context.colorScheme.border,
    );
    final children = <Widget>[];
    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      if (section.title != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              section.title!,
              style: context.textTheme.small.copyWith(
                color: context.colorScheme.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      for (var itemIndex = 0; itemIndex < section.items.length; itemIndex++) {
        final item = section.items[itemIndex];
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AccessibilityActionTile(
              item: item,
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
        final hasMoreItems = itemIndex < section.items.length - 1;
        if (hasMoreItems) {
          children.add(divider);
        }
      }
      final hasMoreSections = sectionIndex < sections.length - 1;
      if (hasMoreSections) {
        children.add(const SizedBox(height: 12));
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            children: children,
          ),
        );
      },
    );
  }
}

class _AccessibilityActionTile extends StatelessWidget {
  const _AccessibilityActionTile({
    required this.item,
    required this.onTap,
    this.onDismiss,
  });

  final AccessibilityMenuItem item;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tileColor =
        item.highlight ? scheme.primary.withValues(alpha: 0.08) : scheme.card;
    final foreground =
        item.destructive ? scheme.destructive : scheme.foreground;
    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          (textTheme.bodyMedium ?? const TextStyle()).copyWith(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }
}

class _AccessibilityDismissIntent extends Intent {
  const _AccessibilityDismissIntent();
}
