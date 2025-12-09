import 'dart:math';
import 'dart:typed_data';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/avatar/avatar_templates.dart';
import 'package:axichat/src/profile/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AvatarEditorScreen extends StatelessWidget {
  const AvatarEditorScreen({super.key, required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    final templates = buildDefaultAvatarTemplates();
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
          value: locate<ProfileCubit>(),
        ),
        BlocProvider.value(
          value: locate<SettingsCubit>(),
        ),
        BlocProvider(
          create: (_) => AvatarEditorCubit(
            xmppService: locate<XmppService>(),
            templates: templates,
            profileCubit: locate<ProfileCubit>(),
          )..initialize(context.colorScheme),
        ),
      ],
      child: _AvatarEditorBody(
        templates: templates,
      ),
    );
  }
}

class _AvatarEditorBody extends StatelessWidget {
  const _AvatarEditorBody({required this.templates});

  final List<AvatarTemplate> templates;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<AvatarEditorCubit, AvatarEditorState>(
      builder: (context, state) {
        final profile = context.watch<ProfileCubit>().state;
        final colors = context.colorScheme;
        final isWide = MediaQuery.sizeOf(context).width >= largeScreen;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.profileTitle),
            elevation: 0,
            backgroundColor: colors.background,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: AxiIconButton(
                iconData: LucideIcons.arrowLeft,
                tooltip: l10n.commonBack,
                color: colors.foreground,
                borderColor: colors.border,
                onPressed: context.pop,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10.0,
                    children: [
                      _AvatarSummaryCard(
                        state: state,
                        profile: profile,
                        isWide: isWide,
                      ),
                      _CropCard(state: state),
                      _BackgroundPicker(
                        state: state,
                      ),
                      _DefaultsSection(
                        templates: templates,
                        state: state,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarSummaryCard extends StatelessWidget {
  const _AvatarSummaryCard({
    required this.state,
    required this.profile,
    required this.isWide,
  });

  final AvatarEditorState state;
  final ProfileState profile;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final cubit = context.read<AvatarEditorCubit>();
    final size = isWide ? 104.0 : 88.0;
    final previewBytes = state.previewBytes ?? state.sourceBytes;

    return ShadCard(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12.0,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 12.0,
            children: [
              Hero(
                tag: 'avatar',
                child: AxiAvatar(
                  jid: profile.jid,
                  size: size,
                  subscription: Subscription.both,
                  avatarBytes: previewBytes,
                  avatarPath: previewBytes == null ? profile.avatarPath : null,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4.0,
                  children: [
                    Text(
                      profile.username,
                      style: context.textTheme.h3
                          .copyWith(color: colors.foreground),
                    ),
                    Text(
                      profile.jid,
                      style: context.textTheme.muted,
                    ),
                    if (state.estimatedBytes != null)
                      Text(
                        '${state.estimatedBytes! ~/ 1024} KB • ${state.draft?.mimeType ?? ''}',
                        style: context.textTheme.small
                            .copyWith(color: colors.mutedForeground),
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8.0,
                children: [
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: state.processing ? null : cubit.pickImage,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8.0,
                      children: [
                        Icon(LucideIcons.upload),
                        Text('Upload image'),
                      ],
                    ),
                  ),
                  ShadButton(
                    size: ShadButtonSize.sm,
                    onPressed: state.draft == null ||
                            state.processing ||
                            state.publishing
                        ? null
                        : cubit.publish,
                    child: state.publishing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.commonSave),
                  ),
                ],
              ),
            ],
          ),
          if (state.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: colors.destructive.withAlpha((0.1 * 255).round()),
                borderRadius: context.radius,
                border: Border.all(color: colors.destructive),
              ),
              child: Text(
                state.error!,
                style:
                    context.textTheme.small.copyWith(color: colors.destructive),
              ),
            ),
        ],
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  const _CropCard({required this.state});

  final AvatarEditorState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final previewBytes = state.previewBytes ?? state.sourceBytes;
    final hasPreview = previewBytes != null &&
        previewBytes.isNotEmpty &&
        state.imageWidth != null &&
        state.imageHeight != null;
    return ShadCard(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12.0,
        children: [
          Text(
            'Crop & compress',
            style: context.textTheme.h4.copyWith(color: colors.foreground),
          ),
          if (!hasPreview)
            Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: context.radius,
                border: Border.all(color: colors.border),
              ),
              child: Text(
                'Add a photo or pick a default avatar',
                style: context.textTheme.small.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            )
          else
            _CropperCanvas(
              bytes: previewBytes,
              state: state,
            ),
          Text(
            'Drag the corners to position your crop. We resize to 256×256 and keep files under 64KB.',
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _CropperCanvas extends StatefulWidget {
  const _CropperCanvas({
    required this.bytes,
    required this.state,
  });

  final Uint8List bytes;
  final AvatarEditorState state;

  @override
  State<_CropperCanvas> createState() => _CropperCanvasState();
}

enum _DragHandle {
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class _CropperCanvasState extends State<_CropperCanvas> {
  static const double _maxCanvas = 240.0;
  static const double _handleSize = 14.0;
  static const double _minPaintPadding = 0.0;
  static const double _minCropSide = 48.0;

  _DragHandle? _handle;
  Rect? _startRect;
  Offset? _startLocal;
  double _scaleX = 1;
  double _scaleY = 1;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final cubit = context.read<AvatarEditorCubit>();
    final imageWidth = (widget.state.imageWidth ?? 1).toDouble();
    final imageHeight = (widget.state.imageHeight ?? 1).toDouble();
    final cropRect =
        widget.state.cropRect ?? _fallbackCropRect(imageWidth, imageHeight);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSide = min(constraints.maxWidth, _maxCanvas);
        final aspect = imageWidth / imageHeight;
        final renderWidth = aspect >= 1 ? maxSide : maxSide * aspect;
        final renderHeight = aspect >= 1 ? maxSide / aspect : maxSide;
        _scaleX = renderWidth / imageWidth;
        _scaleY = renderHeight / imageHeight;
        final selectionRect = Rect.fromLTWH(
          cropRect.left * _scaleX,
          cropRect.top * _scaleY,
          cropRect.width * _scaleX,
          cropRect.height * _scaleY,
        );
        return Center(
          child: SizedBox(
            width: renderWidth,
            height: renderHeight,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: context.radius,
                  child: Image.memory(
                    widget.bytes,
                    width: renderWidth,
                    height: renderHeight,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) => _onPanStart(
                      details.localPosition,
                      selectionRect,
                      imageWidth,
                      imageHeight,
                    ),
                    onPanUpdate: (details) => _onPanUpdate(
                      details.localPosition,
                      cubit,
                    ),
                    onPanEnd: (_) => _resetDrag(),
                    onPanCancel: _resetDrag,
                    child: CustomPaint(
                      painter: _CropOverlayPainter(
                        selection: selectionRect,
                        colors: colors,
                        handleSize: _handleSize,
                        padding: _minPaintPadding,
                      ),
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

  void _onPanStart(
    Offset local,
    Rect selectionRect,
    double imageWidth,
    double imageHeight,
  ) {
    _handle = _hitTest(local, selectionRect);
    _startLocal = local;
    _startRect =
        widget.state.cropRect ?? _fallbackCropRect(imageWidth, imageHeight);
  }

  void _onPanUpdate(
    Offset local,
    AvatarEditorCubit cubit,
  ) {
    if (_handle == null || _startRect == null || _startLocal == null) return;
    final deltaDisplay = local - _startLocal!;
    final deltaImage = Offset(
      deltaDisplay.dx / _scaleX,
      deltaDisplay.dy / _scaleY,
    );
    final updated = _updatedRect(
      _startRect!,
      deltaImage,
      _handle!,
    );
    cubit.updateCropRect(updated);
  }

  void _resetDrag() {
    _handle = null;
    _startRect = null;
    _startLocal = null;
  }

  _DragHandle _hitTest(Offset local, Rect selection) {
    final hitboxes = <Rect, _DragHandle>{
      Rect.fromCenter(
        center: selection.topLeft,
        width: _handleSize * 2,
        height: _handleSize * 2,
      ): _DragHandle.topLeft,
      Rect.fromCenter(
        center: selection.topRight,
        width: _handleSize * 2,
        height: _handleSize * 2,
      ): _DragHandle.topRight,
      Rect.fromCenter(
        center: selection.bottomLeft,
        width: _handleSize * 2,
        height: _handleSize * 2,
      ): _DragHandle.bottomLeft,
      Rect.fromCenter(
        center: selection.bottomRight,
        width: _handleSize * 2,
        height: _handleSize * 2,
      ): _DragHandle.bottomRight,
    };
    for (final entry in hitboxes.entries) {
      if (entry.key.contains(local)) return entry.value;
    }
    if (selection.contains(local)) return _DragHandle.move;
    return _DragHandle.move;
  }

  Rect _updatedRect(
    Rect startRect,
    Offset delta,
    _DragHandle handle,
  ) {
    switch (handle) {
      case _DragHandle.move:
        return startRect.shift(delta);
      case _DragHandle.topLeft:
        return _resizeFromCorner(
          movingCorner: startRect.topLeft + delta,
          anchor: startRect.bottomRight,
        );
      case _DragHandle.topRight:
        return _resizeFromCorner(
          movingCorner: startRect.topRight + delta,
          anchor: startRect.bottomLeft,
        );
      case _DragHandle.bottomLeft:
        return _resizeFromCorner(
          movingCorner: startRect.bottomLeft + delta,
          anchor: startRect.topRight,
        );
      case _DragHandle.bottomRight:
        return _resizeFromCorner(
          movingCorner: startRect.bottomRight + delta,
          anchor: startRect.topLeft,
        );
    }
  }

  Rect _resizeFromCorner({
    required Offset movingCorner,
    required Offset anchor,
  }) {
    final width = (anchor.dx - movingCorner.dx).abs();
    final height = (anchor.dy - movingCorner.dy).abs();
    final side = max(_minCropSide, max(width, height));
    final anchorAtBottomRight =
        anchor.dx >= movingCorner.dx && anchor.dy >= movingCorner.dy;
    if (anchorAtBottomRight) {
      return Rect.fromLTWH(anchor.dx - side, anchor.dy - side, side, side);
    }
    final anchorAtTopLeft =
        anchor.dx <= movingCorner.dx && anchor.dy <= movingCorner.dy;
    if (anchorAtTopLeft) {
      return Rect.fromLTWH(anchor.dx, anchor.dy, side, side);
    }
    final anchorAtTopRight = anchor.dx >= movingCorner.dx;
    if (anchorAtTopRight) {
      return Rect.fromLTWH(anchor.dx - side, anchor.dy, side, side);
    }
    return Rect.fromLTWH(anchor.dx, anchor.dy - side, side, side);
  }

  Rect _fallbackCropRect(double imageWidth, double imageHeight) {
    final side = min(imageWidth, imageHeight) * 0.7;
    final left = (imageWidth - side) / 2;
    final top = (imageHeight - side) / 2;
    return Rect.fromLTWH(left, top, side, side);
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({
    required this.selection,
    required this.colors,
    required this.handleSize,
    required this.padding,
  });

  final Rect selection;
  final ShadColorScheme colors;
  final double handleSize;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          selection.deflate(padding),
          const Radius.circular(8),
        ),
      )
      ..fillType = PathFillType.evenOdd;
    final scrimPaint = Paint()
      ..color = colors.background.withValues(alpha: 0.7);
    canvas.drawPath(scrimPath, scrimPaint);

    final borderPaint = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        selection.deflate(padding),
        const Radius.circular(8),
      ),
      borderPaint,
    );

    final gridPaint = Paint()
      ..color = colors.border
      ..strokeWidth = 1;
    final thirds = [1 / 3, 2 / 3];
    for (final t in thirds) {
      final dx = selection.left + selection.width * t;
      final dy = selection.top + selection.height * t;
      canvas.drawLine(
        Offset(dx, selection.top + padding),
        Offset(dx, selection.bottom - padding),
        gridPaint,
      );
      canvas.drawLine(
        Offset(selection.left + padding, dy),
        Offset(selection.right - padding, dy),
        gridPaint,
      );
    }

    final handlePaint = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.fill;
    for (final offset in [
      selection.topLeft,
      selection.topRight,
      selection.bottomLeft,
      selection.bottomRight,
    ]) {
      final rect = Rect.fromCenter(
        center: offset,
        width: handleSize,
        height: handleSize,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        handlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.selection != selection || oldDelegate.colors != colors;
}

class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker({required this.state});

  final AvatarEditorState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AvatarEditorCubit>();
    final colors = context.colorScheme;
    final palette = [
      colors.background,
      colors.card,
      colors.secondary,
      colors.accent,
      colors.primary,
      colors.foreground.withAlpha((0.75 * 255).round()),
    ];
    final needsPicker = state.template?.hasAlphaBackground == true ||
        state.source == AvatarSource.upload;
    if (!needsPicker) return const SizedBox.shrink();
    return ShadCard(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10.0,
        children: [
          Text(
            'Background color (for transparent avatars)',
            style: context.textTheme.h4.copyWith(color: colors.foreground),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final color in palette)
                GestureDetector(
                  onTap: () => cubit.setBackgroundColor(color, colors),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: state.backgroundColor == color
                            ? colors.primary
                            : colors.border,
                        width: state.backgroundColor == color ? 2 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DefaultsSection extends StatelessWidget {
  const _DefaultsSection({
    required this.templates,
    required this.state,
  });

  final List<AvatarTemplate> templates;
  final AvatarEditorState state;

  String _labelForCategory(AvatarTemplateCategory category) {
    return switch (category) {
      AvatarTemplateCategory.abstract => 'Abstract',
      AvatarTemplateCategory.science => 'Science',
      AvatarTemplateCategory.sports => 'Sports',
      AvatarTemplateCategory.music => 'Music',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final cubit = context.read<AvatarEditorCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12.0,
      children: [
        Text(
          'Default avatars',
          style: context.textTheme.h4.copyWith(color: colors.foreground),
        ),
        for (final category in AvatarTemplateCategory.values)
          _CategoryRow(
            title: _labelForCategory(category),
            templates: templates
                .where((template) => template.category == category)
                .toList(),
            selectedId: state.template?.id,
            onSelect: (template) => cubit.selectTemplate(template, colors),
            backgroundColor: state.backgroundColor,
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.title,
    required this.templates,
    required this.selectedId,
    required this.onSelect,
    required this.backgroundColor,
  });

  final String title;
  final List<AvatarTemplate> templates;
  final String? selectedId;
  final void Function(AvatarTemplate) onSelect;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    if (templates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8.0,
      children: [
        Text(
          title,
          style: context.textTheme.muted.copyWith(
            color: colors.mutedForeground,
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final template = templates[index];
              return _TemplatePreviewCard(
                template: template,
                isSelected: template.id == selectedId,
                backgroundColor: backgroundColor,
                onTap: () => onSelect(template),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TemplatePreviewCard extends StatefulWidget {
  const _TemplatePreviewCard({
    required this.template,
    required this.isSelected,
    required this.backgroundColor,
    required this.onTap,
  });

  final AvatarTemplate template;
  final bool isSelected;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  State<_TemplatePreviewCard> createState() => _TemplatePreviewCardState();
}

class _TemplatePreviewCardState extends State<_TemplatePreviewCard> {
  late Future<GeneratedAvatar> _future;
  ShadColorScheme? _colors;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colors = context.colorScheme;
    final hasChanged = !_initialized || _colors != colors;
    if (hasChanged) {
      _colors = colors;
      _future = widget.template.generator(widget.backgroundColor, colors);
      _initialized = true;
    }
  }

  @override
  void didUpdateWidget(covariant _TemplatePreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final colors = _colors ?? context.colorScheme;
    final templateChanged = widget.template != oldWidget.template;
    final needsRefresh = templateChanged ||
        (widget.template.hasAlphaBackground &&
            widget.backgroundColor != oldWidget.backgroundColor);
    if (needsRefresh) {
      _future = widget.template.generator(widget.backgroundColor, colors);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 120,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: context.radius,
          border: Border.all(
            color: widget.isSelected ? colors.primary : colors.border,
            width: widget.isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8.0,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: FutureBuilder<GeneratedAvatar>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return ClipRRect(
                        borderRadius: context.radius,
                        child: Image.memory(
                          snapshot.data!.bytes,
                          fit: BoxFit.cover,
                        ),
                      );
                    }
                    return Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              child: Text(
                widget.template.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.small.copyWith(
                  color: colors.foreground,
                  fontWeight: widget.isSelected ? FontWeight.w700 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
