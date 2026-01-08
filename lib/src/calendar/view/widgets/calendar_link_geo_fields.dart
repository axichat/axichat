// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/calendar/view/widgets/task_text_field.dart';
import 'package:axichat/src/common/ui/ui.dart';

const String _linkGeoSectionTitle = 'Link & geo';
const String _linkFieldLabel = 'Link';
const String _linkFieldHint = 'https://';
const String _latitudeFieldLabel = 'Latitude';
const String _latitudeFieldHint = '0.0000';
const String _longitudeFieldLabel = 'Longitude';
const String _longitudeFieldHint = '0.0000';
const String _geoSeparator = ', ';
const int _geoPrecision = 4;

class CalendarLinkGeoFields extends StatefulWidget {
  const CalendarLinkGeoFields({
    super.key,
    required this.url,
    required this.geo,
    required this.onUrlChanged,
    required this.onGeoChanged,
    this.title = _linkGeoSectionTitle,
    this.enabled = true,
  });

  final String? url;
  final CalendarGeo? geo;
  final ValueChanged<String?> onUrlChanged;
  final ValueChanged<CalendarGeo?> onGeoChanged;
  final String title;
  final bool enabled;

  @override
  State<CalendarLinkGeoFields> createState() => _CalendarLinkGeoFieldsState();
}

class _CalendarLinkGeoFieldsState extends State<CalendarLinkGeoFields> {
  late final TextEditingController _urlController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.url ?? '');
    _latitudeController =
        TextEditingController(text: _formatCoordinate(widget.geo?.latitude));
    _longitudeController =
        TextEditingController(text: _formatCoordinate(widget.geo?.longitude));
    _expanded = _shouldStartExpanded(widget);
  }

  @override
  void didUpdateWidget(covariant CalendarLinkGeoFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _syncController(_urlController, widget.url ?? '');
    }
    if (oldWidget.geo != widget.geo) {
      _syncController(
        _latitudeController,
        _formatCoordinate(widget.geo?.latitude),
      );
      _syncController(
        _longitudeController,
        _formatCoordinate(widget.geo?.longitude),
      );
    }
    if (!_expanded && _shouldStartExpanded(widget)) {
      setState(() => _expanded = true);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String _formatCoordinate(double? value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  void _handleUrlChanged(String value) {
    final String trimmed = value.trim();
    widget.onUrlChanged(trimmed.isEmpty ? null : trimmed);
  }

  void _handleGeoChanged() {
    final String latRaw = _latitudeController.text.trim();
    final String lonRaw = _longitudeController.text.trim();
    if (latRaw.isEmpty && lonRaw.isEmpty) {
      widget.onGeoChanged(null);
      return;
    }
    final double? lat = double.tryParse(latRaw);
    final double? lon = double.tryParse(lonRaw);
    if (lat == null || lon == null) {
      widget.onGeoChanged(null);
      return;
    }
    widget.onGeoChanged(CalendarGeo(latitude: lat, longitude: lon));
  }

  bool _shouldStartExpanded(CalendarLinkGeoFields widget) {
    final String? url = widget.url?.trim();
    return (url != null && url.isNotEmpty) || widget.geo != null;
  }

  String _formatUrlLabel(String value) {
    final Uri? uri = Uri.tryParse(value);
    if (uri == null) {
      return value;
    }
    return uri.host.isNotEmpty ? uri.host : value;
  }

  String _formatChipCoordinate(double value) {
    return value.toStringAsFixed(_geoPrecision);
  }

  @override
  Widget build(BuildContext context) {
    const TextInputType geoKeyboard =
        TextInputType.numberWithOptions(decimal: true, signed: true);
    final List<Widget> chips = <Widget>[];
    final String? url = widget.url?.trim();
    if (url != null && url.isNotEmpty) {
      chips.add(
        _LinkGeoChip(
          icon: Icons.link,
          label: _formatUrlLabel(url),
        ),
      );
    }
    final CalendarGeo? geo = widget.geo;
    if (geo != null) {
      final String lat = _formatChipCoordinate(geo.latitude);
      final String lon = _formatChipCoordinate(geo.longitude);
      chips.add(
        _LinkGeoChip(
          icon: Icons.place_outlined,
          label: '$lat$_geoSeparator$lon',
        ),
      );
    }
    final bool hasChips = chips.isNotEmpty;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasChips) ...[
          Wrap(
            spacing: calendarInsetSm,
            runSpacing: calendarInsetSm,
            children: chips,
          ),
          const SizedBox(height: calendarGutterSm),
        ],
        TaskTextField(
          controller: _urlController,
          labelText: _linkFieldLabel,
          hintText: _linkFieldHint,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.url,
          onChanged: _handleUrlChanged,
          enabled: widget.enabled,
        ),
        const SizedBox(height: calendarGutterMd),
        Row(
          children: [
            Expanded(
              child: TaskTextField(
                controller: _latitudeController,
                labelText: _latitudeFieldLabel,
                hintText: _latitudeFieldHint,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.none,
                keyboardType: geoKeyboard,
                onChanged: (_) => _handleGeoChanged(),
                enabled: widget.enabled,
              ),
            ),
            const SizedBox(width: calendarGutterSm),
            Expanded(
              child: TaskTextField(
                controller: _longitudeController,
                labelText: _longitudeFieldLabel,
                hintText: _longitudeFieldHint,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.none,
                keyboardType: geoKeyboard,
                onChanged: (_) => _handleGeoChanged(),
                enabled: widget.enabled,
              ),
            ),
          ],
        ),
      ],
    );
    return TaskSectionExpander(
      title: widget.title,
      isExpanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      enabled: widget.enabled,
      child: content,
    );
  }
}

class _LinkGeoChip extends StatelessWidget {
  const _LinkGeoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetMd,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: calendarGutterLg,
            color: calendarSubtitleColor,
          ),
          const SizedBox(width: calendarInsetMd),
          Flexible(
            child: Text(
              label,
              style: labelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
