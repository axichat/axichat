import 'package:axichat/src/app.dart';
import 'package:axichat/src/avatar/avatar_templates.dart';
import 'package:axichat/src/avatar/bloc/avatar_editor_cubit.dart';
import 'package:axichat/src/avatar/view/widgets/avatar_cropper.dart';
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
            shape: Border(
              bottom: BorderSide(
                color: colors.border,
              ),
            ),
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
                      _AvatarEditorToolsSection(state: state),
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

class _AvatarEditorToolsSection extends StatelessWidget {
  const _AvatarEditorToolsSection({required this.state});

  final AvatarEditorState state;

  @override
  Widget build(BuildContext context) {
    final template = state.template;
    final showBackgroundPicker = state.source == AvatarSource.template &&
        template != null &&
        template.category != AvatarTemplateCategory.abstract &&
        template.hasAlphaBackground;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isCompact = maxWidth < mediumScreen;
        if (isCompact) {
          return Column(
            spacing: _avatarEditorToolsSpacing,
            children: [
              _CropCard(state: state),
              if (showBackgroundPicker) _BackgroundPicker(state: state),
            ],
          );
        }

        final panelCount = showBackgroundPicker ? 2 : 1;
        final panelWidth = (panelCount == 2
                ? (maxWidth - _avatarEditorToolsSpacing) / panelCount
                : maxWidth)
            .clamp(0.0, _avatarEditorToolsMaxPanelWidth)
            .toDouble();
        return Wrap(
          spacing: _avatarEditorToolsSpacing,
          runSpacing: _avatarEditorToolsSpacing,
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

const _avatarEditorToolsSpacing = 12.0;
const _avatarEditorToolsMaxPanelWidth = 420.0;

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
    final avatarSavedMessage = l10n.avatarSavedMessage;
    final showSuccessMessage = !state.publishing &&
        state.error == null &&
        state.lastSavedHash != null &&
        state.draft?.hash == state.lastSavedHash;

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
                    onPressed:
                        state.processing || state.publishing || state.shuffling
                            ? null
                            : () => cubit.shuffleTemplate(colors),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8.0,
                      children: [
                        if (state.shuffling)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.foreground,
                              ),
                              backgroundColor:
                                  colors.foreground.withValues(alpha: 0.2),
                            ),
                          )
                        else
                          const Icon(LucideIcons.refreshCw, size: 20),
                        Text(l10n.signupAvatarShuffle),
                      ],
                    ),
                  ),
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: state.processing || state.publishing
                        ? null
                        : cubit.pickImage,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8.0,
                      children: [
                        const Icon(LucideIcons.upload),
                        Text(l10n.signupAvatarUploadImage),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8.0,
                      children: [
                        if (state.publishing)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
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
                          const Icon(LucideIcons.save, size: 18),
                        Text(l10n.avatarSaveAvatar),
                      ],
                    ),
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
          if (showSuccessMessage)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.10),
                borderRadius: context.radius,
                border: Border.all(color: colors.primary),
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
          Text(
            l10n.avatarCropTitle,
            style: context.textTheme.h4.copyWith(color: colors.foreground),
          ),
          Text(
            l10n.avatarCropDescription,
            style:
                context.textTheme.small.copyWith(color: colors.mutedForeground),
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
                l10n.avatarCropPlaceholder,
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
                Center(
                  child: AvatarCropper(
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
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 4.0,
                    children: [
                      Text(
                        l10n.avatarCropSizeLabel(cropRect.width.round()),
                        style: context.textTheme.small
                            .copyWith(color: colors.foreground),
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
    final cubit = context.read<AvatarEditorCubit>();
    final colors = context.colorScheme;
    final template = state.template;
    final presets = [
      Colors.transparent,
      colors.accent,
      colors.primary,
      colors.secondary,
      colors.card,
      colors.background,
      colors.foreground.withAlpha((0.65 * 255).round()),
    ];
    final needsPicker = state.source == AvatarSource.template &&
        template != null &&
        template.category != AvatarTemplateCategory.abstract &&
        template.hasAlphaBackground;
    if (!needsPicker) return const SizedBox.shrink();
    return ShadCard(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12.0,
        children: [
          Text(
            l10n.avatarBackgroundTitle,
            style: context.textTheme.h4.copyWith(color: colors.foreground),
          ),
          Text(
            l10n.avatarBackgroundDescription,
            style:
                context.textTheme.small.copyWith(color: colors.mutedForeground),
          ),
          Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: _avatarEditorColorPickerWidth),
              child: ColorPicker(
                color: state.backgroundColor,
                onColorChanged: (color) =>
                    cubit.setBackgroundColor(color, colors),
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
                colorCodePrefixStyle: context.textTheme.small
                    .copyWith(color: colors.mutedForeground),
                heading: Text(
                  l10n.avatarBackgroundWheelTitle,
                  style: context.textTheme.small
                      .copyWith(color: colors.foreground),
                ),
                subheading: Text(
                  l10n.avatarBackgroundWheelDescription,
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
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: state.backgroundColor == Colors.transparent
                  ? null
                  : () => cubit.setBackgroundColor(Colors.transparent, colors),
              child: Text(l10n.avatarBackgroundTransparent),
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
                  l10n.avatarBackgroundPreview,
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

const _avatarEditorColorPickerWidth = 340.0;

class _DefaultsSection extends StatelessWidget {
  const _DefaultsSection({
    required this.templates,
    required this.state,
  });

  final List<AvatarTemplate> templates;
  final AvatarEditorState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final cubit = context.read<AvatarEditorCubit>();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _avatarDefaultsSectionSpacing,
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
                : (maxWidth - (_avatarDefaultsWrapSpacing * (columns - 1))) /
                    columns;
            final templatesByCategory =
                <AvatarTemplateCategory, List<AvatarTemplate>>{
              for (final category in AvatarTemplateCategory.values)
                category: templates
                    .where(
                      (template) => template.category == category,
                    )
                    .toList(),
            };
            return Wrap(
              spacing: _avatarDefaultsWrapSpacing,
              runSpacing: _avatarDefaultsWrapSpacing,
              children: [
                for (final entry in templatesByCategory.entries)
                  if (entry.value.isNotEmpty)
                    SizedBox(
                      width: cardWidth,
                      child: _CategoryCarouselCard(
                        title: entry.key.label(l10n),
                        templates: entry.value,
                        selectedId: state.template?.id,
                        onSelect: (template) =>
                            cubit.selectTemplate(template, colors),
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

const _avatarDefaultsSectionSpacing = 12.0;
const _avatarDefaultsWrapSpacing = 12.0;
const _avatarDefaultsColumnsWide = 3;
const _avatarDefaultsColumnsMedium = 2;
const _avatarDefaultsColumnsNarrow = 1;

const _avatarDefaultsCarouselCardPadding = EdgeInsets.all(12.0);
const _avatarDefaultsCarouselCardSpacing = 10.0;
const _avatarDefaultsCarouselControlSpacing = 6.0;
const _avatarDefaultsCarouselControlAnimationCurve = Curves.easeOutCubic;

const _avatarTemplateCarouselHeight = 160.0;
const _avatarTemplateCardWidth = 120.0;
const _avatarTemplateCardAnimationDuration = Duration(milliseconds: 160);
const _avatarTemplateCarouselItemSpacing = 12.0;
const _avatarTemplateCarouselMinViewportFraction = 0.28;

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
    final templates = widget.templates;
    if (templates.isEmpty) return const SizedBox.shrink();
    final canNavigate = templates.length > 1;
    return ShadCard(
      padding: _avatarDefaultsCarouselCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _avatarDefaultsCarouselCardSpacing,
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
                          duration: baseAnimationDuration,
                          curve: _avatarDefaultsCarouselControlAnimationCurve,
                        )
                    : null,
              ),
              const SizedBox(width: _avatarDefaultsCarouselControlSpacing),
              AxiIconButton(
                iconData: LucideIcons.chevronRight,
                tooltip: l10n.commonNext,
                onPressed: canNavigate
                    ? () => _carouselController.nextPage(
                          duration: baseAnimationDuration,
                          curve: _avatarDefaultsCarouselControlAnimationCurve,
                        )
                    : null,
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final viewportFraction =
                  (_avatarTemplateCardWidth / constraints.maxWidth)
                      .clamp(_avatarTemplateCarouselMinViewportFraction, 1.0);
              return CarouselSlider.builder(
                carouselController: _carouselController,
                itemCount: templates.length,
                itemBuilder: (context, index, _) {
                  final template = templates[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _avatarTemplateCarouselItemSpacing / 2,
                    ),
                    child: _TemplatePreviewCard(
                      template: template,
                      isSelected: template.id == widget.selectedId,
                      backgroundColor: widget.backgroundColor,
                      onTap: () => widget.onSelect(template),
                    ),
                  );
                },
                options: CarouselOptions(
                  height: _avatarTemplateCarouselHeight,
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
    final previewBackground =
        template.hasAlphaBackground ? colors.card : colors.card;
    final assetPath = template.assetPath;
    final labelStyle = isSelected
        ? context.textTheme.p.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          )
        : context.textTheme.small.copyWith(
            color: colors.mutedForeground,
          );
    final border = isSelected
        ? Border.all(
            color: colors.primary,
            width: 2,
          )
        : null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: _avatarTemplateCardAnimationDuration,
          width: _avatarTemplateCardWidth,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: context.radius,
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8.0,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: ClipRRect(
                    borderRadius: context.radius,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: previewBackground),
                      child: assetPath == null
                          ? Center(
                              child: Icon(
                                LucideIcons.imageOff,
                                size: 20,
                                color: colors.mutedForeground,
                              ),
                            )
                          : Image.asset(
                              assetPath,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
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
      ).withTapBounce(),
    );
  }
}
