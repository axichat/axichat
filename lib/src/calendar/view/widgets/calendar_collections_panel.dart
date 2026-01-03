// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_collection.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_availability_preview.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';

const String _collectionsButtonLabel = 'Calendars';
const String _collectionsPanelTitle = 'Calendars & overlays';
const String _collectionsSectionLabel = 'Calendars';
const String _overlaysSectionLabel = 'Overlays';
const String _accessSectionLabel = 'Access';
const String _collectionFallbackName = 'Primary calendar';
const String _collectionDefaultLabel = 'Default';
const String _collectionOwnerLabel = 'Owner';
const String _collectionOwnerPrivateLabel = 'Private';
const String _collectionTimeZoneLabel = 'Time zone';
const String _collectionMethodLabel = 'Method';
const String _collectionSharingLabel = 'Sharing policy';
const String _collectionColorLabel = 'Color';
const String _collectionVisibilityLabel = 'Visible';
const String _collectionLayerLabel = 'Layer';
const String _overlayRangeLabel = 'Range';
const String _overlayRedactedLabel = 'Redacted';
const String _overlayItemLabel = 'Availability overlay';
const String _overlayPreviewLabel = 'Preview';
const String _overlayVisibleLabel = 'Visible';
const String _overlayLayerLabel = 'Layer';
const String _accessReadLabel = 'Read';
const String _accessWriteLabel = 'Write';
const String _accessManageLabel = 'Manage';
const String _accessDeleteLabel = 'Delete';
const String _overlayRedactedYesLabel = 'Yes';
const String _overlayRedactedNoLabel = 'No';
const String _layerPrimaryLabel = 'Primary';
const String _layerAboveLabel = 'Above';
const String _layerBelowLabel = 'Below';
const String _collectionsOverlayKeyPrimary = 'primary';
const double _collectionsPanelWidth = calendarQuickAddModalMaxWidth;
const double _collectionsPanelMaxHeight = calendarQuickAddModalMaxHeight;
const double _collectionsPanelHeaderIconSize = 18.0;
const double _collectionsPanelLabelFontSize = 12.0;
const double _collectionsPanelLabelLetterSpacing = 0.2;
const double _collectionsPanelBorderWidth = 1.0;
const double _collectionsPanelShadowAlpha = 0.14;
const double _collectionsPanelShadowBlur = 20.0;
const double _collectionsPanelShadowOffsetY = 8.0;
const double _collectionsPanelSpacerHeight = 12.0;
const double _collectionsPanelMetadataGap = 6.0;
const double _collectionsPanelItemSpacing = 12.0;
const double _collectionsPanelIconSize = 16.0;
const double _collectionsPanelToggleSpacing = 8.0;

class CalendarCollectionsContext {
  const CalendarCollectionsContext({
    required this.collection,
    required this.overlays,
    this.chatAcl,
    this.chatTitle,
  });

  final CalendarCollection? collection;
  final Map<String, CalendarAvailabilityOverlay> overlays;
  final CalendarChatAcl? chatAcl;
  final String? chatTitle;
}

enum CalendarLayerPosition { primary, above, below }

extension CalendarLayerPositionLabelX on CalendarLayerPosition {
  String get label => switch (this) {
        CalendarLayerPosition.primary => _layerPrimaryLabel,
        CalendarLayerPosition.above => _layerAboveLabel,
        CalendarLayerPosition.below => _layerBelowLabel,
      };
}

class CalendarLayerSetting {
  const CalendarLayerSetting({
    required this.isVisible,
    required this.layer,
  });

  final bool isVisible;
  final CalendarLayerPosition layer;

  CalendarLayerSetting copyWith({
    bool? isVisible,
    CalendarLayerPosition? layer,
  }) {
    return CalendarLayerSetting(
      isVisible: isVisible ?? this.isVisible,
      layer: layer ?? this.layer,
    );
  }
}

class CalendarCollectionsButton extends StatefulWidget {
  const CalendarCollectionsButton({
    super.key,
    required this.context,
    required this.compact,
  });

  final CalendarCollectionsContext context;
  final bool compact;

  @override
  State<CalendarCollectionsButton> createState() =>
      _CalendarCollectionsButtonState();
}

class _CalendarCollectionsButtonState extends State<CalendarCollectionsButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isBottomSheetOpen = false;
  late Map<String, CalendarLayerSetting> _collectionSettings;
  late Map<String, CalendarLayerSetting> _overlaySettings;

  bool get _isOpen => _overlayEntry != null || _isBottomSheetOpen;

  @override
  void initState() {
    super.initState();
    _collectionSettings = _seedCollectionSettings(widget.context);
    _overlaySettings = _seedOverlaySettings(widget.context);
  }

  @override
  void didUpdateWidget(covariant CalendarCollectionsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _collectionSettings = _mergeSettings(
      previous: _collectionSettings,
      incoming: _seedCollectionSettings(widget.context),
    );
    _overlaySettings = _mergeSettings(
      previous: _overlaySettings,
      incoming: _seedOverlaySettings(widget.context),
    );
    _overlayEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _removeOverlay(requestRebuild: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color foreground = context.colorScheme.primary;
    final bool isOpen = _isOpen;
    final Color iconColor = isOpen ? calendarPrimaryColor : foreground;

    final Widget button = widget.compact
        ? ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: _toggleOverlay,
            child: Icon(
              Icons.layers_outlined,
              size: _collectionsPanelIconSize,
              color: iconColor,
            ),
          ).withTapBounce()
        : ShadButton.secondary(
            size: ShadButtonSize.sm,
            onPressed: _toggleOverlay,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: _collectionsPanelIconSize,
                  color: iconColor,
                ),
                const SizedBox(width: calendarInsetSm),
                const Text(_collectionsButtonLabel),
              ],
            ),
          ).withTapBounce();

    return CompositedTransformTarget(
      link: _link,
      child: SizedBox(
        height: 40,
        child: button,
      ),
    );
  }

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }
    if (_isBottomSheetOpen) {
      return;
    }
    _showOverlay();
  }

  void _showOverlay() {
    if (ResponsiveHelper.isCompact(context)) {
      _showBottomSheet();
      return;
    }

    final OverlayState overlay = Overlay.of(context);
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final double buttonWidth = renderBox?.size.width ?? 0;
    final double buttonHeight = renderBox?.size.height ?? 0;
    final double horizontalOffset = buttonWidth - _collectionsPanelWidth;
    final double verticalOffset = buttonHeight + calendarGutterSm;

    final OverlayEntry entry = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          onTap: _removeOverlay,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Positioned.fill(child: Container()),
              CompositedTransformFollower(
                link: _link,
                offset: Offset(horizontalOffset, verticalOffset),
                showWhenUnlinked: false,
                child: Material(
                  color: Colors.transparent,
                  child: CalendarCollectionsPanel(
                    context: widget.context,
                    collectionSettings: _collectionSettings,
                    overlaySettings: _overlaySettings,
                    onCollectionVisibilityChanged: _handleCollectionVisibility,
                    onCollectionLayerChanged: _handleCollectionLayer,
                    onOverlayVisibilityChanged: _handleOverlayVisibility,
                    onOverlayLayerChanged: _handleOverlayLayer,
                    onClose: _removeOverlay,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    setState(() => _overlayEntry = entry);
    overlay.insert(entry);
  }

  Future<void> _showBottomSheet() async {
    if (!mounted) {
      return;
    }
    setState(() => _isBottomSheetOpen = true);
    await showAdaptiveBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        return CalendarCollectionsPanel(
          context: widget.context,
          useSheetStyle: true,
          collectionSettings: _collectionSettings,
          overlaySettings: _overlaySettings,
          onCollectionVisibilityChanged: (id, value) {
            _handleCollectionVisibility(id, value);
          },
          onCollectionLayerChanged: (id, value) {
            _handleCollectionLayer(id, value);
          },
          onOverlayVisibilityChanged: (id, value) {
            _handleOverlayVisibility(id, value);
          },
          onOverlayLayerChanged: (id, value) {
            _handleOverlayLayer(id, value);
          },
          onClose: () {
            _handleBottomSheetClosed();
            Navigator.of(sheetContext).maybePop();
          },
        );
      },
    );
    _handleBottomSheetClosed();
  }

  void _handleBottomSheetClosed() {
    if (mounted) {
      setState(() => _isBottomSheetOpen = false);
    }
  }

  void _removeOverlay({bool requestRebuild = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (requestRebuild && mounted) {
      setState(() {});
    }
  }

  Map<String, CalendarLayerSetting> _seedCollectionSettings(
    CalendarCollectionsContext context,
  ) {
    final CalendarCollection? collection = context.collection;
    final String key = collection?.id.trim().isNotEmpty == true
        ? collection!.id
        : _collectionsOverlayKeyPrimary;
    return {
      key: const CalendarLayerSetting(
        isVisible: true,
        layer: CalendarLayerPosition.primary,
      ),
    };
  }

  Map<String, CalendarLayerSetting> _seedOverlaySettings(
    CalendarCollectionsContext context,
  ) {
    if (context.overlays.isEmpty) {
      return const {};
    }
    final Map<String, CalendarLayerSetting> seeded =
        <String, CalendarLayerSetting>{};
    for (final String key in context.overlays.keys) {
      seeded[key] = const CalendarLayerSetting(
        isVisible: true,
        layer: CalendarLayerPosition.above,
      );
    }
    return seeded;
  }

  Map<String, CalendarLayerSetting> _mergeSettings({
    required Map<String, CalendarLayerSetting> previous,
    required Map<String, CalendarLayerSetting> incoming,
  }) {
    final Map<String, CalendarLayerSetting> merged =
        Map<String, CalendarLayerSetting>.from(previous);
    incoming.forEach((key, value) {
      merged.putIfAbsent(key, () => value);
    });
    merged.removeWhere((key, _) => !incoming.containsKey(key));
    return merged;
  }

  void _handleCollectionVisibility(String id, bool isVisible) {
    setState(() {
      final CalendarLayerSetting current = _collectionSettings[id] ??
          const CalendarLayerSetting(
            isVisible: true,
            layer: CalendarLayerPosition.primary,
          );
      _collectionSettings = Map<String, CalendarLayerSetting>.from(
        _collectionSettings,
      )..[id] = current.copyWith(isVisible: isVisible);
    });
    _overlayEntry?.markNeedsBuild();
  }

  void _handleCollectionLayer(String id, CalendarLayerPosition layer) {
    setState(() {
      final CalendarLayerSetting current = _collectionSettings[id] ??
          const CalendarLayerSetting(
            isVisible: true,
            layer: CalendarLayerPosition.primary,
          );
      _collectionSettings = Map<String, CalendarLayerSetting>.from(
        _collectionSettings,
      )..[id] = current.copyWith(layer: layer);
    });
    _overlayEntry?.markNeedsBuild();
  }

  void _handleOverlayVisibility(String id, bool isVisible) {
    setState(() {
      final CalendarLayerSetting current = _overlaySettings[id] ??
          const CalendarLayerSetting(
            isVisible: true,
            layer: CalendarLayerPosition.above,
          );
      _overlaySettings = Map<String, CalendarLayerSetting>.from(
        _overlaySettings,
      )..[id] = current.copyWith(isVisible: isVisible);
    });
    _overlayEntry?.markNeedsBuild();
  }

  void _handleOverlayLayer(String id, CalendarLayerPosition layer) {
    setState(() {
      final CalendarLayerSetting current = _overlaySettings[id] ??
          const CalendarLayerSetting(
            isVisible: true,
            layer: CalendarLayerPosition.above,
          );
      _overlaySettings = Map<String, CalendarLayerSetting>.from(
        _overlaySettings,
      )..[id] = current.copyWith(layer: layer);
    });
    _overlayEntry?.markNeedsBuild();
  }
}

class CalendarCollectionsPanel extends StatelessWidget {
  const CalendarCollectionsPanel({
    super.key,
    required this.context,
    required this.collectionSettings,
    required this.overlaySettings,
    required this.onCollectionVisibilityChanged,
    required this.onCollectionLayerChanged,
    required this.onOverlayVisibilityChanged,
    required this.onOverlayLayerChanged,
    required this.onClose,
    this.useSheetStyle = false,
  });

  final CalendarCollectionsContext context;
  final Map<String, CalendarLayerSetting> collectionSettings;
  final Map<String, CalendarLayerSetting> overlaySettings;
  final void Function(String id, bool visible) onCollectionVisibilityChanged;
  final void Function(String id, CalendarLayerPosition layer)
      onCollectionLayerChanged;
  final void Function(String id, bool visible) onOverlayVisibilityChanged;
  final void Function(String id, CalendarLayerPosition layer)
      onOverlayLayerChanged;
  final VoidCallback onClose;
  final bool useSheetStyle;

  @override
  Widget build(BuildContext context) {
    final Widget content = CalendarCollectionsContent(
      context: this.context,
      collectionSettings: collectionSettings,
      overlaySettings: overlaySettings,
      onCollectionVisibilityChanged: onCollectionVisibilityChanged,
      onCollectionLayerChanged: onCollectionLayerChanged,
      onOverlayVisibilityChanged: onOverlayVisibilityChanged,
      onOverlayLayerChanged: onOverlayLayerChanged,
    );

    if (useSheetStyle) {
      final header = AxiSheetHeader(
        title: const Text(_collectionsPanelTitle),
        onClose: onClose,
      );
      return AxiSheetScaffold.scroll(
        header: header,
        bodyPadding: const EdgeInsets.fromLTRB(
          calendarGutterLg,
          0,
          calendarGutterLg,
          calendarGutterLg,
        ),
        children: [content],
      );
    }

    final Color shadowColor = Theme.of(context)
        .shadowColor
        .withValues(alpha: _collectionsPanelShadowAlpha);

    return Container(
      width: _collectionsPanelWidth,
      constraints: const BoxConstraints(
        maxHeight: _collectionsPanelMaxHeight,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(
          color: calendarBorderColor,
          width: _collectionsPanelBorderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: _collectionsPanelShadowBlur,
            offset: const Offset(0, _collectionsPanelShadowOffsetY),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CollectionsPanelHeader(
              onClose: onClose,
            ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  calendarGutterLg,
                  0,
                  calendarGutterLg,
                  calendarGutterLg,
                ),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalendarCollectionsContent extends StatelessWidget {
  const CalendarCollectionsContent({
    super.key,
    required this.context,
    required this.collectionSettings,
    required this.overlaySettings,
    required this.onCollectionVisibilityChanged,
    required this.onCollectionLayerChanged,
    required this.onOverlayVisibilityChanged,
    required this.onOverlayLayerChanged,
  });

  final CalendarCollectionsContext context;
  final Map<String, CalendarLayerSetting> collectionSettings;
  final Map<String, CalendarLayerSetting> overlaySettings;
  final void Function(String id, bool visible) onCollectionVisibilityChanged;
  final void Function(String id, CalendarLayerPosition layer)
      onCollectionLayerChanged;
  final void Function(String id, bool visible) onOverlayVisibilityChanged;
  final void Function(String id, CalendarLayerPosition layer)
      onOverlayLayerChanged;

  @override
  Widget build(BuildContext context) {
    final CalendarCollectionsContext collectionsContext = this.context;
    final List<_CalendarCollectionEntry> collections =
        _CalendarCollectionEntry.from(collectionsContext.collection);
    final bool hasOverlays = collectionsContext.overlays.isNotEmpty;
    final CalendarChatAcl? chatAcl = collectionsContext.chatAcl;
    final String? chatTitle = _safeDisplayTitle(collectionsContext.chatTitle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: _collectionsSectionLabel),
        const SizedBox(height: calendarGutterSm),
        ...collections.map((entry) {
          final CalendarLayerSetting setting = collectionSettings[entry.id] ??
              const CalendarLayerSetting(
                isVisible: true,
                layer: CalendarLayerPosition.primary,
              );
          return Padding(
            padding: const EdgeInsets.only(
              bottom: _collectionsPanelItemSpacing,
            ),
            child: _CollectionCard(
              entry: entry,
              setting: setting,
              allowLayering: collections.length > 1,
              onVisibilityChanged: (value) =>
                  onCollectionVisibilityChanged(entry.id, value),
              onLayerChanged: (value) =>
                  onCollectionLayerChanged(entry.id, value),
            ),
          );
        }),
        if (hasOverlays) ...[
          const SizedBox(height: _collectionsPanelSpacerHeight),
          const TaskSectionHeader(title: _overlaysSectionLabel),
          const SizedBox(height: calendarGutterSm),
          ...this.context.overlays.entries.map((entry) {
            final CalendarLayerSetting setting = overlaySettings[entry.key] ??
                const CalendarLayerSetting(
                  isVisible: true,
                  layer: CalendarLayerPosition.above,
                );
            return Padding(
              padding: const EdgeInsets.only(
                bottom: _collectionsPanelItemSpacing,
              ),
              child: _OverlayCard(
                overlay: entry.value,
                setting: setting,
                onVisibilityChanged: (value) =>
                    onOverlayVisibilityChanged(entry.key, value),
                onLayerChanged: (value) =>
                    onOverlayLayerChanged(entry.key, value),
              ),
            );
          }),
        ],
        if (chatAcl != null) ...[
          const SizedBox(height: _collectionsPanelSpacerHeight),
          TaskSectionHeader(
            title: chatTitle == null || chatTitle.trim().isEmpty
                ? _accessSectionLabel
                : '$chatTitle $_accessSectionLabel',
            uppercase: false,
          ),
          const SizedBox(height: calendarGutterSm),
          _ChatAccessCard(acl: chatAcl),
        ],
      ],
    );
  }
}

class _CollectionsPanelHeader extends StatelessWidget {
  const _CollectionsPanelHeader({
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final Color foreground = calendarTitleColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        calendarGutterLg,
        calendarGutterMd,
        calendarGutterLg,
        calendarGutterSm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.layers_outlined,
            size: _collectionsPanelHeaderIconSize,
            color: foreground,
          ),
          const SizedBox(width: calendarGutterSm),
          Expanded(
            child: Text(
              _collectionsPanelTitle,
              style: calendarTitleTextStyle.copyWith(fontSize: 16),
            ),
          ),
          AxiIconButton(
            iconData: Icons.close,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
            color: calendarSubtitleColor,
            backgroundColor: calendarContainerColor,
            borderColor: calendarBorderColor,
            iconSize: 16,
            buttonSize: 32,
            tapTargetSize: 36,
            cornerRadius: 12,
          ),
        ],
      ),
    );
  }
}

class _CalendarCollectionEntry {
  const _CalendarCollectionEntry({
    required this.id,
    required this.name,
    required this.collection,
  });

  final String id;
  final String name;
  final CalendarCollection? collection;

  static List<_CalendarCollectionEntry> from(CalendarCollection? collection) {
    if (collection == null) {
      return const [
        _CalendarCollectionEntry(
          id: _collectionsOverlayKeyPrimary,
          name: _collectionFallbackName,
          collection: null,
        ),
      ];
    }
    final String id = collection.id.trim().isEmpty
        ? _collectionsOverlayKeyPrimary
        : collection.id;
    final String resolvedName = collection.name.trim().isEmpty
        ? _collectionFallbackName
        : collection.name.trim();
    return [
      _CalendarCollectionEntry(
        id: id,
        name: resolvedName,
        collection: collection,
      ),
    ];
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.entry,
    required this.setting,
    required this.allowLayering,
    required this.onVisibilityChanged,
    required this.onLayerChanged,
  });

  final _CalendarCollectionEntry entry;
  final CalendarLayerSetting setting;
  final bool allowLayering;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<CalendarLayerPosition> onLayerChanged;

  @override
  Widget build(BuildContext context) {
    final CalendarCollection? collection = entry.collection;
    final String ownerLabel = _safeOwnerLabel(collection?.owner);
    final String timeZoneLabel = _safeValueLabel(collection?.timeZone);
    final String methodLabel =
        collection?.method?.label ?? _collectionDefaultLabel;
    final String sharingLabel =
        _safeValueLabel(collection?.sharingPolicy?.value);
    final String colorLabel = _safeValueLabel(collection?.color);

    return Container(
      padding: const EdgeInsets.all(calendarGutterMd),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CollectionHeaderRow(
            name: entry.name,
            isVisible: setting.isVisible,
            onVisibilityChanged: onVisibilityChanged,
          ),
          const SizedBox(height: _collectionsPanelMetadataGap),
          _MetaRow(label: _collectionOwnerLabel, value: ownerLabel),
          _MetaRow(label: _collectionTimeZoneLabel, value: timeZoneLabel),
          _MetaRow(label: _collectionMethodLabel, value: methodLabel),
          _MetaRow(label: _collectionSharingLabel, value: sharingLabel),
          _MetaRow(label: _collectionColorLabel, value: colorLabel),
          const SizedBox(height: _collectionsPanelMetadataGap),
          _LayerRow(
            label: _collectionLayerLabel,
            value: setting.layer,
            allowSelect: allowLayering,
            onChanged: onLayerChanged,
          ),
        ],
      ),
    );
  }
}

class _CollectionHeaderRow extends StatelessWidget {
  const _CollectionHeaderRow({
    required this.name,
    required this.isVisible,
    required this.onVisibilityChanged,
  });

  final String name;
  final bool isVisible;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w700,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(name, style: titleStyle),
        ),
        const SizedBox(width: _collectionsPanelToggleSpacing),
        ShadSwitch(
          label: const Text(_collectionVisibilityLabel),
          value: isVisible,
          onChanged: onVisibilityChanged,
        ),
      ],
    );
  }
}

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({
    required this.overlay,
    required this.setting,
    required this.onVisibilityChanged,
    required this.onLayerChanged,
  });

  final CalendarAvailabilityOverlay overlay;
  final CalendarLayerSetting setting;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<CalendarLayerPosition> onLayerChanged;

  @override
  Widget build(BuildContext context) {
    final String ownerLabel = _safeOwnerLabel(overlay.owner);
    final String rangeLabel = _formatOverlayRange(overlay);
    final String redactedLabel =
        overlay.isRedacted ? _overlayRedactedYesLabel : _overlayRedactedNoLabel;

    return Container(
      padding: const EdgeInsets.all(calendarGutterMd),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverlayHeaderRow(
            isVisible: setting.isVisible,
            onVisibilityChanged: onVisibilityChanged,
          ),
          const SizedBox(height: _collectionsPanelMetadataGap),
          _MetaRow(label: _collectionOwnerLabel, value: ownerLabel),
          _MetaRow(label: _overlayRangeLabel, value: rangeLabel),
          _MetaRow(label: _overlayRedactedLabel, value: redactedLabel),
          _OverlayPreviewSection(overlay: overlay),
          const SizedBox(height: _collectionsPanelMetadataGap),
          _LayerRow(
            label: _overlayLayerLabel,
            value: setting.layer,
            allowSelect: true,
            onChanged: onLayerChanged,
          ),
        ],
      ),
    );
  }
}

class _OverlayPreviewSection extends StatelessWidget {
  const _OverlayPreviewSection({
    required this.overlay,
  });

  final CalendarAvailabilityOverlay overlay;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      fontSize: _collectionsPanelLabelFontSize,
      fontWeight: FontWeight.w600,
      color: calendarSubtitleColor,
      letterSpacing: _collectionsPanelLabelLetterSpacing,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: _collectionsPanelMetadataGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_overlayPreviewLabel.toUpperCase(), style: labelStyle),
          const SizedBox(height: calendarInsetSm),
          CalendarAvailabilityPreview(overlay: overlay),
        ],
      ),
    );
  }
}

class _OverlayHeaderRow extends StatelessWidget {
  const _OverlayHeaderRow({
    required this.isVisible,
    required this.onVisibilityChanged,
  });

  final bool isVisible;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w700,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(_overlayItemLabel, style: titleStyle),
        ),
        const SizedBox(width: _collectionsPanelToggleSpacing),
        ShadSwitch(
          label: const Text(_overlayVisibleLabel),
          value: isVisible,
          onChanged: onVisibilityChanged,
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      fontSize: _collectionsPanelLabelFontSize,
      fontWeight: FontWeight.w600,
      color: calendarSubtitleColor,
      letterSpacing: _collectionsPanelLabelLetterSpacing,
    );
    final TextStyle valueStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: _collectionsPanelMetadataGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: labelStyle),
          const SizedBox(height: calendarInsetSm),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.label,
    required this.value,
    required this.allowSelect,
    required this.onChanged,
  });

  final String label;
  final CalendarLayerPosition value;
  final bool allowSelect;
  final ValueChanged<CalendarLayerPosition> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!allowSelect) {
      return _MetaRow(
        label: label,
        value: value.label,
      );
    }

    final List<ShadOption<CalendarLayerPosition>> options =
        CalendarLayerPosition.values
            .map(
              (layer) => ShadOption<CalendarLayerPosition>(
                value: layer,
                child: Text(layer.label),
              ),
            )
            .toList(growable: false);

    return _LayerSelectField(
      label: label,
      value: value,
      options: options,
      onChanged: onChanged,
    );
  }
}

class _LayerSelectField extends StatelessWidget {
  const _LayerSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final CalendarLayerPosition value;
  final List<ShadOption<CalendarLayerPosition>> options;
  final ValueChanged<CalendarLayerPosition> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      fontSize: _collectionsPanelLabelFontSize,
      fontWeight: FontWeight.w600,
      color: calendarSubtitleColor,
      letterSpacing: _collectionsPanelLabelLetterSpacing,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: _collectionsPanelMetadataGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: labelStyle),
          const SizedBox(height: calendarInsetSm),
          ShadSelect<CalendarLayerPosition>(
            initialValue: value,
            onChanged: (next) {
              if (next == null) {
                return;
              }
              onChanged(next);
            },
            options: options,
            selectedOptionBuilder: (context, selected) => Text(selected.label),
            decoration: ShadDecoration(
              color: calendarContainerColor,
              border: ShadBorder.all(
                color: calendarBorderColor,
                radius: BorderRadius.circular(calendarBorderRadius),
                width: _collectionsPanelBorderWidth,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterMd,
              vertical: calendarGutterSm,
            ),
            trailing: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: _collectionsPanelIconSize,
              color: calendarSubtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAccessCard extends StatelessWidget {
  const _ChatAccessCard({
    required this.acl,
  });

  final CalendarChatAcl acl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(calendarGutterMd),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetaRow(label: _accessReadLabel, value: acl.read.label),
          _MetaRow(label: _accessWriteLabel, value: acl.write.label),
          _MetaRow(label: _accessManageLabel, value: acl.manage.label),
          _MetaRow(label: _accessDeleteLabel, value: acl.delete.label),
        ],
      ),
    );
  }
}

String _safeOwnerLabel(String? owner) {
  final String trimmed = owner?.trim() ?? '';
  if (trimmed.isEmpty) {
    return _collectionDefaultLabel;
  }
  if (trimmed.contains('@')) {
    return _collectionOwnerPrivateLabel;
  }
  return trimmed;
}

String _safeValueLabel(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? _collectionDefaultLabel : trimmed;
}

String? _safeDisplayTitle(String? value) {
  final String trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.contains('@')) {
    return null;
  }
  return trimmed;
}

String _formatOverlayRange(CalendarAvailabilityOverlay overlay) {
  final DateTime start = overlay.rangeStart.value;
  final DateTime end = overlay.rangeEnd.value;
  final String startLabel = TimeFormatter.formatFriendlyDate(start);
  final String endLabel = TimeFormatter.formatFriendlyDate(end);
  return '$startLabel - $endLabel';
}
