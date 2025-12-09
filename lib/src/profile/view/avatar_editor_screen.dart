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
                    onPressed: state.processing
                        ? null
                        : () => cubit.shuffleTemplate(colors),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8.0,
                      children: [
                        Icon(LucideIcons.shuffle),
                        Text('Shuffle'),
                      ],
                    ),
                  ),
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
    final cubit = context.read<AvatarEditorCubit>();
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6.0,
                  children: [
                    Text(
                      'Crop & focus',
                      style: context.textTheme.h4
                          .copyWith(color: colors.foreground),
                    ),
                    Text(
                      'Drag or resize the 3×3 grid to set your crop. The image stays fixed and the grid snaps to the center when you get close. Double tap to reset.',
                      style: context.textTheme.small
                          .copyWith(color: colors.mutedForeground),
                    ),
                  ],
                ),
              ),
              if (hasPreview)
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: cubit.resetCrop,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8.0,
                    children: [
                      Icon(LucideIcons.refreshCcw),
                      Text('Reset'),
                    ],
                  ),
                ),
            ],
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
                'Add a photo or pick a default avatar to adjust the framing.',
                style: context.textTheme.small.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12.0,
              children: [
                _CropperCanvas(
                  bytes: previewBytes,
                  state: state,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Use the handles on the grid to resize or drag the square; it will snap to center when aligned.',
                        style: context.textTheme.small.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 4.0,
                      children: [
                        Text(
                          '${state.cropRect?.width.round() ?? 0} px crop',
                          style: context.textTheme.small
                              .copyWith(color: colors.foreground),
                        ),
                        Text(
                          'Saved at 256×256 • < 64 KB',
                          style: context.textTheme.small.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
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

class _CropperCanvasState extends State<_CropperCanvas> {
  static const double _maxCanvas = 320.0;
  static const double _handleTouchSize = 28.0;
  static const double _snapDistance = 12.0;

  Rect? _startRectImage;
  Offset? _startLocal;
  double _scaleX = 1;
  double _scaleY = 1;
  _CropDragMode _dragMode = _CropDragMode.none;

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
          child: ClipRRect(
            borderRadius: context.radius,
            child: Stack(
              children: [
                SizedBox(
                  width: renderWidth,
                  height: renderHeight,
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
                      cropRect,
                      selectionRect,
                    ),
                    onPanUpdate: (details) => _onPanUpdate(
                      details.localPosition,
                      cubit,
                      imageWidth,
                      imageHeight,
                    ),
                    onPanEnd: (_) => _resetDrag(),
                    onPanCancel: _resetDrag,
                    onDoubleTap: cubit.resetCrop,
                    child: CustomPaint(
                      painter: _CropOverlayPainter(
                        selection: selectionRect,
                        colors: colors,
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
    Rect cropRect,
    Rect selectionRect,
  ) {
    _startLocal = local;
    _startRectImage = cropRect;
    _dragMode = _hitTest(selectionRect, local);
  }

  void _onPanUpdate(
    Offset local,
    AvatarEditorCubit cubit,
    double imageWidth,
    double imageHeight,
  ) {
    if (_dragMode == _CropDragMode.none ||
        _startRectImage == null ||
        _startLocal == null) {
      return;
    }
    final deltaDisplay = local - _startLocal!;
    final deltaImage = Offset(
      deltaDisplay.dx / _scaleX,
      deltaDisplay.dy / _scaleY,
    );
    final startRect = _startRectImage!;
    Rect? next;
    switch (_dragMode) {
      case _CropDragMode.move:
        next = startRect.shift(deltaImage);
        break;
      case _CropDragMode.topLeft:
      case _CropDragMode.topRight:
      case _CropDragMode.bottomLeft:
      case _CropDragMode.bottomRight:
        next = _resizeFromCorner(startRect, deltaImage, _dragMode);
        break;
      case _CropDragMode.none:
        break;
    }
    if (next == null) return;
    next = _snapToCenter(next, imageWidth, imageHeight);
    cubit.updateCropRect(next);
  }

  void _resetDrag() {
    _startRectImage = null;
    _startLocal = null;
    _dragMode = _CropDragMode.none;
  }

  Rect _resizeFromCorner(
    Rect start,
    Offset deltaImage,
    _CropDragMode corner,
  ) {
    var left = start.left;
    var top = start.top;
    var right = start.right;
    var bottom = start.bottom;
    switch (corner) {
      case _CropDragMode.topLeft:
        left += deltaImage.dx;
        top += deltaImage.dy;
        break;
      case _CropDragMode.topRight:
        right += deltaImage.dx;
        top += deltaImage.dy;
        break;
      case _CropDragMode.bottomLeft:
        left += deltaImage.dx;
        bottom += deltaImage.dy;
        break;
      case _CropDragMode.bottomRight:
        right += deltaImage.dx;
        bottom += deltaImage.dy;
        break;
      case _CropDragMode.move:
      case _CropDragMode.none:
        break;
    }
    const minSide = AvatarEditorCubit.minCropSide;
    left = min(left, right - minSide);
    top = min(top, bottom - minSide);
    right = max(right, left + minSide);
    bottom = max(bottom, top + minSide);
    final width = right - left;
    final height = bottom - top;
    final side = max(minSide, max(width, height));
    return switch (corner) {
      _CropDragMode.topLeft =>
        Rect.fromLTWH(right - side, bottom - side, side, side),
      _CropDragMode.topRight => Rect.fromLTWH(left, bottom - side, side, side),
      _CropDragMode.bottomLeft => Rect.fromLTWH(right - side, top, side, side),
      _CropDragMode.bottomRight => Rect.fromLTWH(left, top, side, side),
      _CropDragMode.move => start,
      _CropDragMode.none => start,
    };
  }

  Rect _snapToCenter(Rect rect, double imageWidth, double imageHeight) {
    final imageCenter = Offset(imageWidth / 2, imageHeight / 2);
    final minScale = min(_scaleX, _scaleY);
    final thresholdImage =
        minScale <= 0 ? _snapDistance : _snapDistance / minScale;
    if ((rect.center - imageCenter).distance <= thresholdImage) {
      return Rect.fromCenter(
        center: imageCenter,
        width: rect.width,
        height: rect.height,
      );
    }
    return rect;
  }

  _CropDragMode _hitTest(Rect selectionRect, Offset local) {
    const handle = _handleTouchSize;
    final handleRects = <_CropDragMode, Rect>{
      _CropDragMode.topLeft: Rect.fromCenter(
        center: selectionRect.topLeft,
        width: handle,
        height: handle,
      ),
      _CropDragMode.topRight: Rect.fromCenter(
        center: selectionRect.topRight,
        width: handle,
        height: handle,
      ),
      _CropDragMode.bottomLeft: Rect.fromCenter(
        center: selectionRect.bottomLeft,
        width: handle,
        height: handle,
      ),
      _CropDragMode.bottomRight: Rect.fromCenter(
        center: selectionRect.bottomRight,
        width: handle,
        height: handle,
      ),
    };
    for (final entry in handleRects.entries) {
      if (entry.value.contains(local)) return entry.key;
    }
    if (selectionRect.contains(local)) return _CropDragMode.move;
    return _CropDragMode.none;
  }

  Rect _fallbackCropRect(double imageWidth, double imageHeight) {
    final side = min(imageWidth, imageHeight) * 0.72;
    final safeSide = max(side, AvatarEditorCubit.minCropSide);
    final left = (imageWidth - safeSide) / 2;
    final top = (imageHeight - safeSide) / 2;
    return Rect.fromLTWH(left, top, safeSide, safeSide);
  }
}

enum _CropDragMode { move, topLeft, topRight, bottomLeft, bottomRight, none }

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({
    required this.selection,
    required this.colors,
  });

  final Rect selection;
  final ShadColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          selection,
          const Radius.circular(12),
        ),
      )
      ..fillType = PathFillType.evenOdd;
    final scrimPaint = Paint()
      ..color = colors.background.withValues(alpha: 0.65);
    canvas.drawPath(scrimPath, scrimPaint);

    final borderPaint = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        selection,
        const Radius.circular(12),
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
        Offset(dx, selection.top),
        Offset(dx, selection.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(selection.left, dy),
        Offset(selection.right, dy),
        gridPaint,
      );
    }

    final cornerPaint = Paint()
      ..color = colors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const handleLength = 14.0;
    for (final corner in [
      selection.topLeft,
      selection.topRight,
      selection.bottomLeft,
      selection.bottomRight,
    ]) {
      final horizontal = Offset(
        corner.dx +
            (corner.dx == selection.left ? handleLength : -handleLength),
        corner.dy,
      );
      final vertical = Offset(
        corner.dx,
        corner.dy + (corner.dy == selection.top ? handleLength : -handleLength),
      );
      canvas.drawLine(corner, horizontal, cornerPaint);
      canvas.drawLine(corner, vertical, cornerPaint);
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
    final presets = [
      colors.accent,
      colors.primary,
      colors.secondary,
      colors.card,
      colors.background,
      colors.foreground.withAlpha((0.65 * 255).round()),
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
            'Background color',
            style: context.textTheme.h4.copyWith(color: colors.foreground),
          ),
          Text(
            'Tap or drag to tint transparent avatars before saving.',
            style:
                context.textTheme.small.copyWith(color: colors.mutedForeground),
          ),
          _ColorField(
            color: state.backgroundColor,
            onChanged: (color) => cubit.setBackgroundColor(color, colors),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HexColorInput(
                  color: state.backgroundColor,
                  onSubmitted: (color) =>
                      cubit.setBackgroundColor(color, colors),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 6.0,
                children: [
                  Text(
                    'Preview',
                    style: context.textTheme.small.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: context.radius,
                      color: state.backgroundColor,
                      border: Border.all(color: colors.border),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in presets)
                GestureDetector(
                  onTap: () => cubit.setBackgroundColor(preset, colors),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: preset,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: state.backgroundColor == preset
                            ? colors.primary
                            : colors.border,
                        width: state.backgroundColor == preset ? 2 : 1,
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

class _ColorField extends StatelessWidget {
  const _ColorField({
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return SizedBox(
      height: 164,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final knobCenter = _knobOffsetForColor(color, size);

          void update(Offset position) {
            final dx = position.dx.clamp(0.0, size.width);
            final dy = position.dy.clamp(0.0, size.height);
            final hue = (dx / size.width) * 360.0;
            final tone = 1 - (dy / size.height);
            final saturation = (0.35 + tone * 0.65).clamp(0.0, 1.0);
            final value = (0.65 + tone * 0.35).clamp(0.0, 1.0);
            final selection = HSVColor.fromAHSV(
              1,
              hue,
              saturation,
              value,
            ).toColor();
            onChanged(selection);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) => update(details.localPosition),
            onPanUpdate: (details) => update(details.localPosition),
            child: ClipRRect(
              borderRadius: context.radius,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFF5A5A),
                            Color(0xFFF59E0B),
                            Color(0xFF22C55E),
                            Color(0xFF06B6D4),
                            Color(0xFF6366F1),
                            Color(0xFFF472B6),
                            Color(0xFFFF5A5A),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (knobCenter.dx - 9).clamp(0.0, size.width - 18),
                    top: (knobCenter.dy - 9).clamp(0.0, size.height - 18),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(color: colors.background, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HexColorInput extends StatefulWidget {
  const _HexColorInput({
    required this.color,
    required this.onSubmitted,
  });

  final Color color;
  final ValueChanged<Color> onSubmitted;

  @override
  State<_HexColorInput> createState() => _HexColorInputState();
}

class _HexColorInputState extends State<_HexColorInput> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.color));
  }

  @override
  void didUpdateWidget(covariant _HexColorInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final formatted = _format(widget.color);
    if (_controller.text.toUpperCase() != formatted.toUpperCase()) {
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6.0,
      children: [
        Text(
          'Hex value',
          style:
              context.textTheme.small.copyWith(color: colors.mutedForeground),
        ),
        ShadInput(
          controller: _controller,
          keyboardType: TextInputType.text,
          placeholder: const Text('#AABBCC or #FFAABBCC'),
          onChanged: (_) {
            if (_error != null) {
              setState(() {
                _error = null;
              });
            }
          },
          onSubmitted: _handleSubmitted,
        ),
        if (_error != null)
          Text(
            _error!,
            style: context.textTheme.small.copyWith(color: colors.destructive),
          ),
      ],
    );
  }

  void _handleSubmitted(String value) {
    final parsed = _parse(value);
    if (parsed == null) {
      setState(() {
        _error = 'Use 6 or 8 hex digits';
      });
      return;
    }
    setState(() {
      _error = null;
    });
    widget.onSubmitted(parsed);
  }

  Color? _parse(String value) {
    final normalized = value.trim().replaceAll('#', '');
    if (normalized.length != 6 && normalized.length != 8) return null;
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return null;
    final argb = normalized.length == 6 ? (0xFF000000 | parsed) : parsed;
    return Color(argb);
  }

  String _format(Color color) {
    final hex = [color.r, color.g, color.b]
        .map(
          (channel) =>
              (channel * 255.0).round().clamp(0, 255).toRadixString(16),
        )
        .map((channel) => channel.padLeft(2, '0'))
        .join()
        .toUpperCase();
    return '#$hex';
  }
}

Offset _knobOffsetForColor(Color color, Size size) {
  final hsv = HSVColor.fromColor(color);
  final toneValues = <double>[
    (hsv.saturation - 0.35) / 0.65,
    (hsv.value - 0.65) / 0.35,
  ].where((value) => value.isFinite).toList();
  final tone = toneValues.isEmpty
      ? 0.5
      : toneValues.reduce((a, b) => a + b) / toneValues.length;
  final clampedTone = tone.clamp(0.0, 1.0);
  final dx = (hsv.hue / 360.0).clamp(0.0, 1.0) * size.width;
  final dy = (1 - clampedTone) * size.height;
  return Offset(dx, dy);
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
      AvatarTemplateCategory.stem => 'STEM',
      AvatarTemplateCategory.sports => 'Sports',
      AvatarTemplateCategory.music => 'Music',
      AvatarTemplateCategory.misc => 'Hobbies & Games',
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
