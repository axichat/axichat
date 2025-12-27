import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_ics_raw.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';

const String _icsDiagnosticsTitle = 'ICS diagnostics';
const String _icsDiagnosticsMetadataTitle = 'Metadata';
const String _icsDiagnosticsRawPropertiesTitle = 'Raw properties';
const String _icsDiagnosticsRawComponentsTitle = 'Raw components';
const String _icsDiagnosticsUidLabel = 'UID';
const String _icsDiagnosticsDtStampLabel = 'DTSTAMP';
const String _icsDiagnosticsCreatedLabel = 'CREATED';
const String _icsDiagnosticsLastModifiedLabel = 'LAST-MODIFIED';
const String _icsDiagnosticsSequenceLabel = 'SEQUENCE';
const String _icsDiagnosticsNotSetLabel = 'Not set';
const String _icsDiagnosticsParametersLabel = 'Parameters';
const String _icsDiagnosticsComponentPropertiesLabel = 'Properties';
const String _icsDiagnosticsComponentChildrenLabel = 'Subcomponents';
const String _icsDiagnosticsPropertyFallbackLabel = 'Property';
const String _icsDiagnosticsComponentFallbackLabel = 'Component';
const String _icsDiagnosticsParameterFallbackLabel = 'Parameter';
const String _icsDiagnosticsParameterSeparator = ', ';
const String _icsDiagnosticsParameterValueSeparator = '=';
const String _icsDiagnosticsCountSeparator = ' | ';
const String _icsDiagnosticsPropertySingular = 'property';
const String _icsDiagnosticsPropertyPlural = 'properties';
const String _icsDiagnosticsChildSingular = 'subcomponent';
const String _icsDiagnosticsChildPlural = 'subcomponents';
const double _icsDiagnosticsLabelFontSize = 12;
const double _icsDiagnosticsLabelLetterSpacing = 0.2;

bool hasIcsDiagnosticsData(CalendarIcsMeta? meta) {
  if (meta == null) {
    return false;
  }
  if (_hasMetadataValues(meta)) {
    return true;
  }
  if (meta.rawProperties.isNotEmpty || meta.rawComponents.isNotEmpty) {
    return true;
  }
  return false;
}

bool _hasMetadataValues(CalendarIcsMeta meta) {
  final String? uid = meta.uid?.trim();
  if (uid != null && uid.isNotEmpty) {
    return true;
  }
  if (meta.dtStamp != null ||
      meta.created != null ||
      meta.lastModified != null ||
      meta.sequence != null) {
    return true;
  }
  return false;
}

class CalendarIcsDiagnosticsSection extends StatelessWidget {
  const CalendarIcsDiagnosticsSection({
    super.key,
    required this.icsMeta,
    this.title = _icsDiagnosticsTitle,
  });

  final CalendarIcsMeta? icsMeta;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (!hasIcsDiagnosticsData(icsMeta)) {
      return const SizedBox.shrink();
    }
    final CalendarIcsMeta meta = icsMeta!;
    final List<_IcsMetaEntry> metadataEntries = _collectMetadataEntries(meta);
    final List<CalendarRawProperty> rawProperties = meta.rawProperties;
    final List<CalendarRawComponent> rawComponents = meta.rawComponents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(title: title),
        if (metadataEntries.isNotEmpty) ...[
          const SizedBox(height: calendarGutterSm),
          _DiagnosticsGroup(
            label: _icsDiagnosticsMetadataTitle,
            child: _IcsMetadataList(entries: metadataEntries),
          ),
        ],
        if (rawProperties.isNotEmpty) ...[
          const SizedBox(height: calendarGutterMd),
          _DiagnosticsGroup(
            label: _icsDiagnosticsRawPropertiesTitle,
            child: _RawPropertiesList(properties: rawProperties),
          ),
        ],
        if (rawComponents.isNotEmpty) ...[
          const SizedBox(height: calendarGutterMd),
          _DiagnosticsGroup(
            label: _icsDiagnosticsRawComponentsTitle,
            child: _RawComponentsList(components: rawComponents),
          ),
        ],
      ],
    );
  }
}

class _DiagnosticsGroup extends StatelessWidget {
  const _DiagnosticsGroup({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiagnosticsGroupLabel(label: label),
        const SizedBox(height: calendarInsetSm),
        child,
      ],
    );
  }
}

class _DiagnosticsGroupLabel extends StatelessWidget {
  const _DiagnosticsGroupLabel({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      fontSize: _icsDiagnosticsLabelFontSize,
      fontWeight: FontWeight.w600,
      color: calendarSubtitleColor,
      letterSpacing: _icsDiagnosticsLabelLetterSpacing,
    );
    return Text(label.toUpperCase(), style: labelStyle);
  }
}

class _IcsMetaEntry {
  const _IcsMetaEntry({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

List<_IcsMetaEntry> _collectMetadataEntries(CalendarIcsMeta meta) {
  final List<_IcsMetaEntry> entries = <_IcsMetaEntry>[];
  final String? uid = meta.uid?.trim();
  if (uid != null && uid.isNotEmpty) {
    entries.add(_IcsMetaEntry(label: _icsDiagnosticsUidLabel, value: uid));
  }
  final DateTime? dtStamp = meta.dtStamp;
  if (dtStamp != null) {
    entries.add(
      _IcsMetaEntry(
        label: _icsDiagnosticsDtStampLabel,
        value: _formatDateTime(dtStamp),
      ),
    );
  }
  final DateTime? created = meta.created;
  if (created != null) {
    entries.add(
      _IcsMetaEntry(
        label: _icsDiagnosticsCreatedLabel,
        value: _formatDateTime(created),
      ),
    );
  }
  final DateTime? lastModified = meta.lastModified;
  if (lastModified != null) {
    entries.add(
      _IcsMetaEntry(
        label: _icsDiagnosticsLastModifiedLabel,
        value: _formatDateTime(lastModified),
      ),
    );
  }
  final int? sequence = meta.sequence;
  if (sequence != null) {
    entries.add(
      _IcsMetaEntry(
        label: _icsDiagnosticsSequenceLabel,
        value: sequence.toString(),
      ),
    );
  }
  return entries;
}

String _formatDateTime(DateTime value) {
  return value.toIso8601String();
}

class _IcsMetadataList extends StatelessWidget {
  const _IcsMetadataList({
    required this.entries,
  });

  final List<_IcsMetaEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: calendarInsetMd),
              child: _IcsMetaRow(entry: entry),
            ),
          )
          .toList(),
    );
  }
}

class _IcsMetaRow extends StatelessWidget {
  const _IcsMetaRow({
    required this.entry,
  });

  final _IcsMetaEntry entry;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      fontSize: _icsDiagnosticsLabelFontSize,
      fontWeight: FontWeight.w600,
      color: calendarSubtitleColor,
      letterSpacing: _icsDiagnosticsLabelLetterSpacing,
    );
    final TextStyle valueStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.label.toUpperCase(), style: labelStyle),
        const SizedBox(height: calendarInsetSm),
        Text(entry.value, style: valueStyle),
      ],
    );
  }
}

class _RawPropertiesList extends StatelessWidget {
  const _RawPropertiesList({
    required this.properties,
  });

  final List<CalendarRawProperty> properties;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: properties
          .map(
            (property) => Padding(
              padding: const EdgeInsets.only(bottom: calendarInsetLg),
              child: _RawPropertyTile(property: property),
            ),
          )
          .toList(),
    );
  }
}

class _RawPropertyTile extends StatelessWidget {
  const _RawPropertyTile({
    required this.property,
    this.isCompact = false,
  });

  final CalendarRawProperty property;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final String name = _resolvePropertyName(property.name);
    final String value = _resolvePropertyValue(property.value);
    final List<CalendarPropertyParameter> parameters = property.parameters;
    final TextStyle titleStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    final TextStyle valueStyle = context.textTheme.muted.copyWith(
      color: calendarSubtitleColor,
    );
    final EdgeInsets contentPadding = isCompact
        ? const EdgeInsets.symmetric(
            horizontal: calendarInsetMd,
            vertical: calendarInsetSm,
          )
        : const EdgeInsets.symmetric(
            horizontal: calendarGutterSm,
            vertical: calendarInsetMd,
          );

    final Widget content = Padding(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: titleStyle),
          const SizedBox(height: calendarInsetSm),
          Text(value, style: valueStyle),
          if (parameters.isNotEmpty) ...[
            const SizedBox(height: calendarInsetSm),
            const _DiagnosticsGroupLabel(label: _icsDiagnosticsParametersLabel),
            const SizedBox(height: calendarInsetSm),
            Wrap(
              spacing: calendarInsetSm,
              runSpacing: calendarInsetSm,
              children: parameters
                  .map(
                    (parameter) =>
                        _ParameterChip(label: parameter.labelForDiagnostics),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );

    if (isCompact) {
      return content;
    }

    return Container(
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: content,
    );
  }
}

class _ParameterChip extends StatelessWidget {
  const _ParameterChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarInsetMd,
        vertical: calendarInsetSm,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Text(label, style: labelStyle),
    );
  }
}

class _RawComponentsList extends StatelessWidget {
  const _RawComponentsList({
    required this.components,
    this.depth = 0,
  });

  final List<CalendarRawComponent> components;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: components
          .map(
            (component) => Padding(
              padding: const EdgeInsets.only(bottom: calendarInsetLg),
              child: _RawComponentTile(
                component: component,
                depth: depth,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RawComponentTile extends StatelessWidget {
  const _RawComponentTile({
    required this.component,
    required this.depth,
  });

  final CalendarRawComponent component;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final String name = _resolveComponentName(component.name);
    final List<CalendarRawProperty> properties = component.properties;
    final List<CalendarRawComponent> children = component.components;
    final EdgeInsets padding = EdgeInsets.only(left: calendarInsetMd * depth);

    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: calendarGutterSm,
          vertical: calendarInsetMd,
        ),
        decoration: BoxDecoration(
          color: calendarContainerColor,
          borderRadius: BorderRadius.circular(calendarBorderRadius),
          border: Border.all(color: calendarBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RawComponentHeader(
              name: name,
              propertyCount: properties.length,
              childCount: children.length,
            ),
            if (properties.isNotEmpty) ...[
              const SizedBox(height: calendarInsetSm),
              const _DiagnosticsGroupLabel(
                label: _icsDiagnosticsComponentPropertiesLabel,
              ),
              const SizedBox(height: calendarInsetSm),
              ...properties.map(
                (property) => Padding(
                  padding: const EdgeInsets.only(bottom: calendarInsetSm),
                  child: _RawPropertyTile(
                    property: property,
                    isCompact: true,
                  ),
                ),
              ),
            ],
            if (children.isNotEmpty) ...[
              const SizedBox(height: calendarInsetSm),
              const _DiagnosticsGroupLabel(
                label: _icsDiagnosticsComponentChildrenLabel,
              ),
              const SizedBox(height: calendarInsetSm),
              _RawComponentsList(
                components: children,
                depth: depth + 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RawComponentHeader extends StatelessWidget {
  const _RawComponentHeader({
    required this.name,
    required this.propertyCount,
    required this.childCount,
  });

  final String name;
  final int propertyCount;
  final int childCount;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    final TextStyle subtitleStyle = context.textTheme.muted.copyWith(
      color: calendarSubtitleColor,
    );
    final String? counts = _formatComponentCounts(
      propertyCount: propertyCount,
      childCount: childCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name.toUpperCase(), style: titleStyle),
        if (counts != null) ...[
          const SizedBox(height: calendarInsetSm),
          Text(counts, style: subtitleStyle),
        ],
      ],
    );
  }
}

String? _formatComponentCounts({
  required int propertyCount,
  required int childCount,
}) {
  final List<String> parts = <String>[];
  if (propertyCount > 0) {
    parts.add(
      _formatCount(
        propertyCount,
        _icsDiagnosticsPropertySingular,
        _icsDiagnosticsPropertyPlural,
      ),
    );
  }
  if (childCount > 0) {
    parts.add(
      _formatCount(
        childCount,
        _icsDiagnosticsChildSingular,
        _icsDiagnosticsChildPlural,
      ),
    );
  }
  if (parts.isEmpty) {
    return null;
  }
  return parts.join(_icsDiagnosticsCountSeparator);
}

String _formatCount(int count, String singular, String plural) {
  final String label = count == 1 ? singular : plural;
  return '$count $label';
}

String _resolvePropertyName(String name) {
  final String trimmed = name.trim();
  return trimmed.isEmpty ? _icsDiagnosticsPropertyFallbackLabel : trimmed;
}

String _resolveComponentName(String name) {
  final String trimmed = name.trim();
  return trimmed.isEmpty ? _icsDiagnosticsComponentFallbackLabel : trimmed;
}

String _resolvePropertyValue(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? _icsDiagnosticsNotSetLabel : trimmed;
}

extension CalendarPropertyParameterLabel on CalendarPropertyParameter {
  String get labelForDiagnostics {
    final String trimmedName = name.trim();
    final String label = trimmedName.isEmpty
        ? _icsDiagnosticsParameterFallbackLabel
        : trimmedName;
    final List<String> cleanedValues = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (cleanedValues.isEmpty) {
      return label;
    }
    final String joined = cleanedValues.join(_icsDiagnosticsParameterSeparator);
    return '$label$_icsDiagnosticsParameterValueSeparator$joined';
  }
}
