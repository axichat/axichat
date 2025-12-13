import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/avatar/view/widgets/avatar_cropper.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8.0,
                      children: [
                        if (state.processing)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.primaryForeground,
                              ),
                              backgroundColor:
                                  colors.primaryForeground.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          )
                        else
                          const Icon(LucideIcons.refreshCw, size: 20),
                        const Text('Shuffle'),
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
    final sourceBytes = state.sourceBytes;
    final imageWidth = state.imageWidth?.toDouble();
    final imageHeight = state.imageHeight?.toDouble();
    final cropRect =
        (state.cropRect == null || imageWidth == null || imageHeight == null)
            ? (imageWidth != null && imageHeight != null
                ? AvatarCropper.fallbackCropRect(
                    imageWidth: imageWidth,
                    imageHeight: imageHeight,
                    minCropSide: AvatarEditorCubit.minCropSide,
                  )
                : null)
            : state.cropRect;
    final hasPreview = sourceBytes != null &&
        sourceBytes.isNotEmpty &&
        imageWidth != null &&
        imageHeight != null &&
        imageWidth > 0 &&
        imageHeight > 0 &&
        cropRect != null &&
        cropRect.width > 0 &&
        cropRect.height > 0;
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
                      'Drag or resize the square to set your crop. Use reset to center and follow the circle to match the saved avatar.',
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
                AvatarCropper(
                  bytes: sourceBytes,
                  imageWidth: imageWidth,
                  imageHeight: imageHeight,
                  cropRect: cropRect,
                  onCropChanged: cubit.updateCropRect,
                  onCropReset: cubit.resetCrop,
                  colors: colors,
                  borderRadius: context.radius,
                  minCropSide: AvatarEditorCubit.minCropSide,
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
                          '${cropRect.width.round()} px crop',
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
        spacing: 12.0,
        children: [
          Text(
            'Background color',
            style: context.textTheme.h4.copyWith(color: colors.foreground),
          ),
          Text(
            'Use the wheel or presets to tint transparent avatars before saving.',
            style:
                context.textTheme.small.copyWith(color: colors.mutedForeground),
          ),
          ColorPicker(
            color: state.backgroundColor,
            onColorChanged: (color) => cubit.setBackgroundColor(color, colors),
            pickersEnabled: const {
              ColorPickerType.both: false,
              ColorPickerType.primary: false,
              ColorPickerType.accent: false,
              ColorPickerType.bw: false,
              ColorPickerType.custom: false,
              ColorPickerType.customSecondary: false,
              ColorPickerType.wheel: true,
            },
            width: 40,
            height: 40,
            spacing: 8,
            runSpacing: 8,
            hasBorder: true,
            borderColor: colors.border,
            borderRadius: context.radius.topLeft.x,
            wheelDiameter: 220,
            wheelWidth: 14,
            showColorCode: true,
            colorCodeHasColor: true,
            colorCodeTextStyle:
                context.textTheme.small.copyWith(color: colors.foreground),
            colorCodePrefixStyle:
                context.textTheme.small.copyWith(color: colors.mutedForeground),
            heading: Text(
              'Wheel & hex',
              style: context.textTheme.small.copyWith(color: colors.foreground),
            ),
            subheading: Text(
              'Drag the wheel or enter a hex value.',
              style: context.textTheme.small
                  .copyWith(color: colors.mutedForeground),
            ),
            actionButtons: const ColorPickerActionButtons(
              dialogActionButtons: false,
              closeButton: false,
              okButton: false,
            ),
            copyPasteBehavior: const ColorPickerCopyPasteBehavior(
              longPressMenu: false,
              editFieldCopyButton: true,
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in presets)
                ColorIndicator(
                  color: preset,
                  width: 32,
                  height: 32,
                  borderRadius: 16,
                  hasBorder: true,
                  borderColor: preset == state.backgroundColor
                      ? colors.primary
                      : colors.border,
                  elevation: preset == state.backgroundColor ? 2 : 0,
                  isSelected: preset == state.backgroundColor,
                  onSelect: () => cubit.setBackgroundColor(preset, colors),
                ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ColorIndicator(
                color: state.backgroundColor,
                width: 44,
                height: 44,
                borderRadius: context.radius.topLeft.x,
                hasBorder: true,
                borderColor: colors.border,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Preview saved circle tint.',
                  style: context.textTheme.small
                      .copyWith(color: colors.mutedForeground),
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
