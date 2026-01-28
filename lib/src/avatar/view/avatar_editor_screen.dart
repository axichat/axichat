// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/avatar_editor_state_extensions.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/avatar/models/avatar_models.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:carousel_slider/carousel_slider.dart';
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
        BlocProvider.value(value: locate<ProfileCubit>()),
        BlocProvider.value(value: locate<SettingsCubit>()),
        BlocProvider(
          create: (context) => AvatarEditorCubit(
            xmppService: locate<XmppService>(),
            templates: templates,
          )..initialize(ShadTheme.of(context, listen: false).colorScheme),
        ),
      ],
      child: _AvatarEditorBody(templates: templates),
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
        final colors = context.colorScheme;
        final spacing = context.spacing;
        final isWide = MediaQuery.sizeOf(context).width >= largeScreen;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.profileTitle),
            elevation: 0,
            backgroundColor: colors.background,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            shape: Border(
              bottom: context.borderSide.copyWith(color: colors.border),
            ),
            leading: Padding(
              padding: EdgeInsets.only(left: spacing.s),
              child: AxiIconButton.ghost(
                iconData: LucideIcons.arrowLeft,
                tooltip: l10n.commonBack,
                onPressed: context.pop,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(spacing.m),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: largeScreen),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: spacing.s,
                    children: [
                      _AvatarSummaryCard(
                        state: state,
                        profile: context.watch<ProfileCubit>().state,
                        isWide: isWide,
                      ),
                      _AvatarEditorToolsSection(state: state),
                      _DefaultsSection(templates: templates, state: state),
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

class _AvatarEditorToolsSection extends StatelessWidget {
  const _AvatarEditorToolsSection({required this.state});

  final AvatarEditorState state;

  @override
  Widget build(BuildContext context) {
    final template = state.draftAvatar?.template;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final toolsSpacing = spacing.s;
    final maxPanelWidth = sizing.menuMaxWidth;
    final showBackgroundPicker =
        state.draftAvatar?.source == AvatarSource.template &&
            template != null &&
            template.category != AvatarTemplateCategory.abstract &&
            template.hasAlphaBackground;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isCompact = maxWidth < mediumScreen;
        if (isCompact) {
          return Column(
            spacing: toolsSpacing,
            children: [
              _CropCard(state: state),
              if (showBackgroundPicker) _BackgroundPicker(state: state),
            ],
          );
        }

        final panelCount = showBackgroundPicker ? 2 : 1;
        final panelWidth = (panelCount == 2
                ? (maxWidth - toolsSpacing) / panelCount
                : maxWidth)
            .clamp(0.0, maxPanelWidth)
            .toDouble();
        return Wrap(
          spacing: toolsSpacing,
          runSpacing: toolsSpacing,
          alignment: WrapAlignment.center,
          children: [
            SizedBox(
              width: panelWidth,
              child: _CropCard(state: state),
            ),
            if (showBackgroundPicker)
              SizedBox(
                width: panelWidth,
                child: _BackgroundPicker(state: state),
              ),
          ],
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
    final spacing = context.spacing;
    final sizing = context.sizing;
    final size =
        isWide ? sizing.buttonHeightLg * 2 : sizing.buttonHeightLg * 1.5;
    final previewBytes = state.displayedBytes;
    final errorText = state.errorType?.resolve(l10n);
    final avatarSavedMessage = l10n.avatarSavedMessage;
    final showSuccessMessage = !state.publishing &&
        errorText == null &&
        state.lastSavedHash != null &&
        state.draftAvatar?.payload.hash == state.lastSavedHash;

    return ShadCard(
      padding: EdgeInsets.all(spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.s,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: spacing.s,
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
                  spacing: spacing.xs,
                  children: [
                    Text(
                      profile.username,
                      style: context.textTheme.h3.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                    Text(profile.jid, style: context.textTheme.muted),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: spacing.s,
                children: [
                  AxiButton.outline(
                    size: AxiButtonSize.sm,
                    loading: state.shuffling,
                    onPressed:
                        state.processing || state.publishing || state.shuffling
                            ? null
                            : () => context
                                .read<AvatarEditorCubit>()
                                .shuffleTemplate(colors),
                    leading: Icon(
                      LucideIcons.refreshCw,
                      size: sizing.iconButtonIconSize,
                    ),
                    child: Text(l10n.signupAvatarShuffle),
                  ),
                  AxiButton.outline(
                    size: AxiButtonSize.sm,
                    onPressed: state.processing || state.publishing
                        ? null
                        : context.read<AvatarEditorCubit>().pickImage,
                    leading: Icon(
                      LucideIcons.upload,
                      size: sizing.iconButtonIconSize,
                    ),
                    child: Text(l10n.signupAvatarUploadImage),
                  ),
                  AxiButton.primary(
                    size: AxiButtonSize.sm,
                    loading: state.publishing,
                    onPressed: state.draftAvatar == null ||
                            state.processing ||
                            state.publishing
                        ? null
                        : context.read<AvatarEditorCubit>().publish,
                    leading: Icon(
                      LucideIcons.save,
                      size: sizing.iconButtonIconSize,
                    ),
                    child: Text(l10n.avatarSaveAvatar),
                  ),
                ],
              ),
            ],
          ),
          if (errorText != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(spacing.m),
              decoration: BoxDecoration(
                color: colors.destructive.withAlpha((0.1 * 255).round()),
                borderRadius: context.radius,
                border: Border.fromBorderSide(
                  context.borderSide.copyWith(color: colors.destructive),
                ),
              ),
              child: Text(
                errorText,
                style: context.textTheme.small.copyWith(
                  color: colors.destructive,
                ),
              ),
            ),
          if (showSuccessMessage)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(spacing.m),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: context.radius,
                border: Border.fromBorderSide(
                  context.borderSide.copyWith(color: colors.primary),
                ),
              ),
              child: Text(
                avatarSavedMessage,
                style: context.textTheme.small.copyWith(color: colors.primary),
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
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final draftAvatar = state.draftAvatar;
    final sourceBytes = draftAvatar?.sourceBytes;
    final imageWidth = draftAvatar?.sourceWidth?.toDouble();
    final imageHeight = draftAvatar?.sourceHeight?.toDouble();
    final canCommit =
        draftAvatar?.source == AvatarSource.upload && !state.processing;
    final cropRect = (draftAvatar?.cropRect == null ||
            imageWidth == null ||
            imageHeight == null)
        ? (imageWidth != null && imageHeight != null
            ? AxiImageCropper.fallbackCropRect(
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                minCropSide: AvatarEditorCubit.minCropSide,
              )
            : null)
        : draftAvatar?.cropRect;
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
      padding: EdgeInsets.all(spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.s,
        children: [
          Text(
            l10n.avatarCropTitle,
            style: context.textTheme.h4.copyWith(color: colors.foreground),
          ),
          Text(
            l10n.avatarCropDescription,
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          if (!hasPreview)
            Container(
              height: sizing.buttonHeightLg * 4,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: context.radius,
                border: Border.fromBorderSide(
                  context.borderSide.copyWith(color: colors.border),
                ),
              ),
              child: Text(
                l10n.avatarCropPlaceholder,
                style: context.textTheme.small.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.s,
              children: [
                Center(
                  child: AxiImageCropper(
                    bytes: sourceBytes,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight,
                    cropRect: cropRect,
                    onCropChanged:
                        context.read<AvatarEditorCubit>().updateCropRect,
                    onCropReset: context.read<AvatarEditorCubit>().resetCrop,
                    onCropCommitted: canCommit
                        ? (rect) =>
                            context.read<AvatarEditorCubit>().commitCrop(rect)
                        : null,
                    minCropSide: AvatarEditorCubit.minCropSide,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: AxiButton.secondary(
                    onPressed: canCommit
                        ? () => context
                            .read<AvatarEditorCubit>()
                            .commitCrop(cropRect)
                        : null,
                    child: Text(l10n.commonDone),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: spacing.xs,
                    children: [
                      Text(
                        l10n.avatarCropSizeLabel(cropRect.width.round()),
                        style: context.textTheme.small.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                      Text(
                        l10n.avatarCropSavedSize,
                        style: context.textTheme.small.copyWith(
                          color: colors.mutedForeground,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
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
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final template = state.draftAvatar?.template;
    final presets = [
      Colors.transparent,
      colors.accent,
      colors.primary,
      colors.secondary,
      colors.card,
      colors.background,
      colors.foreground.withAlpha((0.65 * 255).round()),
    ];
    final needsPicker = state.draftAvatar?.source == AvatarSource.template &&
        template != null &&
        template.category != AvatarTemplateCategory.abstract &&
        template.hasAlphaBackground;
    if (!needsPicker) return const SizedBox.shrink();
    return ShadCard(
      padding: EdgeInsets.all(spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.s,
        children: [
          Text(
            l10n.avatarBackgroundTitle,
            style: context.textTheme.h4.copyWith(color: colors.foreground),
          ),
          Text(
            l10n.avatarBackgroundDescription,
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
              child: ColorPicker(
                color: state.backgroundColor,
                onColorChanged: (color) => context
                    .read<AvatarEditorCubit>()
                    .setBackgroundColor(color, colors),
                pickersEnabled: const {
                  ColorPickerType.both: false,
                  ColorPickerType.primary: false,
                  ColorPickerType.accent: false,
                  ColorPickerType.bw: false,
                  ColorPickerType.custom: false,
                  ColorPickerType.customSecondary: false,
                  ColorPickerType.wheel: true,
                },
                width: sizing.iconButtonSize,
                height: sizing.iconButtonSize,
                spacing: spacing.s,
                runSpacing: spacing.s,
                hasBorder: true,
                borderColor: context.borderSide.color,
                borderRadius: context.radius.topLeft.x,
                wheelDiameter: sizing.menuMaxWidth * 0.7,
                wheelWidth: spacing.m,
                showColorCode: true,
                colorCodeHasColor: true,
                colorCodeTextStyle: context.textTheme.small.copyWith(
                  color: colors.foreground,
                ),
                colorCodePrefixStyle: context.textTheme.small.copyWith(
                  color: colors.mutedForeground,
                ),
                heading: Text(
                  l10n.avatarBackgroundWheelTitle,
                  style: context.textTheme.small.copyWith(
                    color: colors.foreground,
                  ),
                ),
                subheading: Text(
                  l10n.avatarBackgroundWheelDescription,
                  style: context.textTheme.small.copyWith(
                    color: colors.mutedForeground,
                  ),
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
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AxiButton.outline(
              size: AxiButtonSize.sm,
              onPressed: state.backgroundColor == Colors.transparent
                  ? null
                  : () => context.read<AvatarEditorCubit>().setBackgroundColor(
                        Colors.transparent,
                        colors,
                      ),
              child: Text(l10n.avatarBackgroundTransparent),
            ),
          ),
          Wrap(
            spacing: spacing.s,
            runSpacing: spacing.s,
            children: [
              for (final preset in presets)
                ColorIndicator(
                  color: preset,
                  width: sizing.iconButtonSize,
                  height: sizing.iconButtonSize,
                  borderRadius: context.radius.topLeft.x,
                  hasBorder: true,
                  borderColor: preset == state.backgroundColor
                      ? colors.primary
                      : context.borderSide.color,
                  elevation: preset == state.backgroundColor ? 2 : 0,
                  isSelected: preset == state.backgroundColor,
                  onSelect: () => context
                      .read<AvatarEditorCubit>()
                      .setBackgroundColor(preset, colors),
                ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ColorIndicator(
                color: state.backgroundColor,
                width: sizing.iconButtonTapTarget,
                height: sizing.iconButtonTapTarget,
                borderRadius: context.radius.topLeft.x,
                hasBorder: true,
                borderColor: context.borderSide.color,
              ),
              SizedBox(width: spacing.s),
              Expanded(
                child: Text(
                  l10n.avatarBackgroundPreview,
                  style: context.textTheme.small.copyWith(
                    color: colors.mutedForeground,
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
  const _DefaultsSection({required this.templates, required this.state});

  final List<AvatarTemplate> templates;
  final AvatarEditorState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spacing.s,
      children: [
        Text(
          l10n.avatarDefaultsTitle,
          style: context.textTheme.h4.copyWith(color: colors.foreground),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final columns = maxWidth >= largeScreen
                ? _avatarDefaultsColumnsWide
                : maxWidth >= mediumScreen
                    ? _avatarDefaultsColumnsMedium
                    : _avatarDefaultsColumnsNarrow;
            final cardWidth = columns == _avatarDefaultsColumnsNarrow
                ? maxWidth
                : (maxWidth - (spacing.s * (columns - 1))) / columns;
            final templatesByCategory =
                <AvatarTemplateCategory, List<AvatarTemplate>>{
              for (final category in AvatarTemplateCategory.values)
                category: templates
                    .where((template) => template.category == category)
                    .toList(),
            };
            return Wrap(
              spacing: spacing.s,
              runSpacing: spacing.s,
              children: [
                for (final entry in templatesByCategory.entries)
                  if (entry.value.isNotEmpty)
                    SizedBox(
                      width: cardWidth,
                      child: _CategoryCarouselCard(
                        title: entry.key.label(l10n),
                        templates: entry.value,
                        selectedId: state.draftAvatar?.template?.id,
                        onSelect: (template) => context
                            .read<AvatarEditorCubit>()
                            .selectTemplate(template, colors),
                        backgroundColor: state.backgroundColor,
                      ),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

const _avatarDefaultsColumnsWide = 3;
const _avatarDefaultsColumnsMedium = 2;
const _avatarDefaultsColumnsNarrow = 1;

extension _AvatarTemplateCategoryLabel on AvatarTemplateCategory {
  String label(AppLocalizations l10n) => switch (this) {
        AvatarTemplateCategory.abstract => l10n.avatarCategoryAbstract,
        AvatarTemplateCategory.stem => l10n.avatarCategoryStem,
        AvatarTemplateCategory.sports => l10n.avatarCategorySports,
        AvatarTemplateCategory.music => l10n.avatarCategoryMusic,
        AvatarTemplateCategory.misc => l10n.avatarCategoryMisc,
      };
}

extension _AvatarTemplateLocalization on AvatarTemplate {
  String label(AppLocalizations l10n) {
    if (id.startsWith('abstract-')) {
      final number = int.tryParse(id.split('-').last);
      return l10n.avatarTemplateAbstract(number ?? 0);
    }
    switch (id) {
      case 'stem-atom':
        return l10n.avatarTemplateAtom;
      case 'stem-beaker':
        return l10n.avatarTemplateBeaker;
      case 'stem-compass':
        return l10n.avatarTemplateCompass;
      case 'stem-cpu':
        return l10n.avatarTemplateCpu;
      case 'stem-gear':
        return l10n.avatarTemplateGear;
      case 'stem-globe':
        return l10n.avatarTemplateGlobe;
      case 'stem-laptop':
        return l10n.avatarTemplateLaptop;
      case 'stem-microscope':
        return l10n.avatarTemplateMicroscope;
      case 'stem-robot':
        return l10n.avatarTemplateRobot;
      case 'stem-stethoscope':
        return l10n.avatarTemplateStethoscope;
      case 'stem-telescope':
        return l10n.avatarTemplateTelescope;
      case 'sports-archery':
        return l10n.avatarTemplateArchery;
      case 'sports-baseball':
        return l10n.avatarTemplateBaseball;
      case 'sports-basketball':
        return l10n.avatarTemplateBasketball;
      case 'sports-boxing':
        return l10n.avatarTemplateBoxing;
      case 'sports-cycling':
        return l10n.avatarTemplateCycling;
      case 'sports-darts':
        return l10n.avatarTemplateDarts;
      case 'sports-football':
        return l10n.avatarTemplateFootball;
      case 'sports-golf':
        return l10n.avatarTemplateGolf;
      case 'sports-pingpong':
        return l10n.avatarTemplatePingPong;
      case 'sports-ski':
        return l10n.avatarTemplateSkiing;
      case 'sports-soccer':
        return l10n.avatarTemplateSoccer;
      case 'sports-tennis':
        return l10n.avatarTemplateTennis;
      case 'sports-volleyball':
        return l10n.avatarTemplateVolleyball;
      case 'music-drum':
        return l10n.avatarTemplateDrums;
      case 'music-electricguitar':
        return l10n.avatarTemplateElectricGuitar;
      case 'music-guitar':
        return l10n.avatarTemplateGuitar;
      case 'music-microphone':
        return l10n.avatarTemplateMicrophone;
      case 'music-piano':
        return l10n.avatarTemplatePiano;
      case 'music-saxophone':
        return l10n.avatarTemplateSaxophone;
      case 'music-violin':
        return l10n.avatarTemplateViolin;
      case 'misc-cards':
        return l10n.avatarTemplateCards;
      case 'misc-chess':
        return l10n.avatarTemplateChess;
      case 'misc-chess2':
        return l10n.avatarTemplateChessAlt;
      case 'misc-dice':
        return l10n.avatarTemplateDice;
      case 'misc-dice2':
        return l10n.avatarTemplateDiceAlt;
      case 'misc-esports':
        return l10n.avatarTemplateEsports;
      case 'misc-sword':
        return l10n.avatarTemplateSword;
      case 'misc-videogames':
        return l10n.avatarTemplateVideoGames;
      case 'misc-videogames2':
        return l10n.avatarTemplateVideoGamesAlt;
      default:
        return id;
    }
  }
}

class _CategoryCarouselCard extends StatefulWidget {
  const _CategoryCarouselCard({
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
  State<_CategoryCarouselCard> createState() => _CategoryCarouselCardState();
}

class _CategoryCarouselCardState extends State<_CategoryCarouselCard> {
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    final templates = widget.templates;
    if (templates.isEmpty) return const SizedBox.shrink();
    final canNavigate = templates.length > 1;
    final cardWidth = sizing.buttonHeightLg * 2.5;
    final carouselHeight = sizing.buttonHeightLg * 3;
    final minViewportFraction =
        (cardWidth / (cardWidth + spacing.s * 2)).clamp(0.2, 1.0).toDouble();
    return ShadCard(
      padding: EdgeInsets.all(spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.s,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: context.textTheme.muted.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ),
              AxiIconButton(
                iconData: LucideIcons.chevronLeft,
                tooltip: l10n.commonPrevious,
                onPressed: canNavigate
                    ? () => _carouselController.previousPage(
                          duration: animationDuration,
                          curve: Curves.easeOutCubic,
                        )
                    : null,
              ),
              SizedBox(width: spacing.xs),
              AxiIconButton(
                iconData: LucideIcons.chevronRight,
                tooltip: l10n.commonNext,
                onPressed: canNavigate
                    ? () => _carouselController.nextPage(
                          duration: animationDuration,
                          curve: Curves.easeOutCubic,
                        )
                    : null,
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final viewportFraction = (cardWidth / constraints.maxWidth).clamp(
                minViewportFraction,
                1.0,
              );
              return CarouselSlider.builder(
                carouselController: _carouselController,
                itemCount: templates.length,
                itemBuilder: (context, index, _) {
                  final template = templates[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing.s / 2),
                    child: _TemplatePreviewCard(
                      template: template,
                      isSelected: template.id == widget.selectedId,
                      backgroundColor: widget.backgroundColor,
                      onTap: () => widget.onSelect(template),
                    ),
                  );
                },
                options: CarouselOptions(
                  height: carouselHeight,
                  viewportFraction: viewportFraction,
                  enlargeCenterPage: true,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TemplatePreviewCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    final previewBackground =
        template.hasAlphaBackground ? colors.card : colors.card;
    final assetPath = template.assetPath;
    final labelStyle = isSelected
        ? context.textTheme.p.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          )
        : context.textTheme.small.copyWith(color: colors.mutedForeground);
    final border = isSelected
        ? Border.fromBorderSide(
            context.borderSide.copyWith(color: colors.primary),
          )
        : null;
    final cardWidth = sizing.buttonHeightLg * 2.5;
    final overlayShape = RoundedSuperellipseBorder(
      borderRadius: context.radius,
      side: context.borderSide,
    );
    return AxiTapBounce(
      enabled: true,
      child: Material(
        color: Colors.transparent,
        shape: overlayShape,
        clipBehavior: Clip.antiAlias,
        child: ShadFocusable(
          canRequestFocus: true,
          builder: (context, focused, child) =>
              child ?? const SizedBox.shrink(),
          child: ShadGestureDetector(
            cursor: SystemMouseCursors.click,
            hoverStrategies: ShadTheme.of(context).hoverStrategies,
            onTap: onTap,
            child: AnimatedContainer(
              duration: animationDuration,
              width: cardWidth,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: context.radius,
                border: border,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: spacing.xs,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(spacing.s),
                      child: ClipRRect(
                        borderRadius: context.radius,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: previewBackground),
                          child: assetPath == null
                              ? Center(
                                  child: Icon(
                                    LucideIcons.imageOff,
                                    size: sizing.iconButtonIconSize,
                                    color: colors.mutedForeground,
                                  ),
                                )
                              : Image.asset(assetPath, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.s,
                      vertical: spacing.s,
                    ),
                    child: Text(
                      template.label(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
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
