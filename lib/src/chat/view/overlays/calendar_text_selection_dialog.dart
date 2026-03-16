part of '../chat.dart';

class _CalendarTextSelectionDialog extends StatefulWidget {
  const _CalendarTextSelectionDialog({required this.initialText});

  final String initialText;

  @override
  State<_CalendarTextSelectionDialog> createState() =>
      _CalendarTextSelectionDialogState();
}

class _CalendarTextSelectionDialogState
    extends State<_CalendarTextSelectionDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String _selection = '';

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialText.trim();
    _controller = TextEditingController(text: seeded);
    _focusNode = FocusNode();
    _selection = seeded;
    _controller.addListener(_handleControllerChanged);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: seeded.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _handleControllerChanged();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final text = _controller.text;
    final selection = _controller.selection;
    final fallback = text.trim();
    var next = fallback;
    if (selection.isValid && !selection.isCollapsed) {
      final start = math.min(selection.baseOffset, selection.extentOffset);
      final end = math.max(selection.baseOffset, selection.extentOffset);
      if (start >= 0 && end <= text.length) {
        next = text.substring(start, end).trim();
      }
    }
    if (_selection == next) return;
    setState(() {
      _selection = next;
    });
  }

  String get _effectiveText {
    final trimmedSelection = _selection.trim();
    if (trimmedSelection.isNotEmpty) return trimmedSelection;
    return _controller.text.trim();
  }

  bool get _canSubmit => _effectiveText.isNotEmpty;

  void _submit() {
    final text = _effectiveText;
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final spacing = context.spacing;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: spacing.l,
        vertical: spacing.m,
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final maxWidth = math.min(
            constraints.maxWidth,
            context.sizing.dialogMaxWidth,
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: AxiModalSurface(
                padding: EdgeInsets.all(spacing.m),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.chatChooseTextToAdd,
                              style: textTheme.h4,
                            ),
                          ),
                          AxiIconButton(
                            iconData: LucideIcons.x,
                            tooltip: l10n.commonClose,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing.s),
                      Text(
                        l10n.chatChooseTextToAddHint,
                        style: textTheme.muted.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                      SizedBox(height: spacing.s),
                      AxiTextInput(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 4,
                        maxLines: 8,
                        keyboardType: TextInputType.multiline,
                        autofocus: true,
                      ),
                      SizedBox(height: spacing.m),
                      Row(
                        children: [
                          AxiButton(
                            variant: AxiButtonVariant.ghost,
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: Text(l10n.commonCancel),
                          ),
                          SizedBox(width: spacing.s),
                          Expanded(
                            child: AxiButton.primary(
                              onPressed: _canSubmit ? _submit : null,
                              child: Text(l10n.chatActionAddToCalendar),
                            ),
                          ),
                        ],
                      ),
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
