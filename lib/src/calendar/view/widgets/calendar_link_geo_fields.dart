import 'package:flutter/material.dart';

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

class CalendarLinkGeoFields extends StatefulWidget {
  const CalendarLinkGeoFields({
    super.key,
    required this.url,
    required this.geo,
    required this.onUrlChanged,
    required this.onGeoChanged,
    this.title = _linkGeoSectionTitle,
  });

  final String? url;
  final CalendarGeo? geo;
  final ValueChanged<String?> onUrlChanged;
  final ValueChanged<CalendarGeo?> onGeoChanged;
  final String title;

  @override
  State<CalendarLinkGeoFields> createState() => _CalendarLinkGeoFieldsState();
}

class _CalendarLinkGeoFieldsState extends State<CalendarLinkGeoFields> {
  late final TextEditingController _urlController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.url ?? '');
    _latitudeController =
        TextEditingController(text: _formatCoordinate(widget.geo?.latitude));
    _longitudeController =
        TextEditingController(text: _formatCoordinate(widget.geo?.longitude));
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

  @override
  Widget build(BuildContext context) {
    const TextInputType geoKeyboard =
        TextInputType.numberWithOptions(decimal: true, signed: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(title: widget.title),
        const SizedBox(height: calendarGutterSm),
        TaskTextField(
          controller: _urlController,
          labelText: _linkFieldLabel,
          hintText: _linkFieldHint,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.url,
          onChanged: _handleUrlChanged,
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
              ),
            ),
          ],
        ),
      ],
    );
  }
}
