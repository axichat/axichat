import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';

const List<String> _emptyCategories = <String>[];

CalendarIcsMeta? applyIcsMetaOverrides({
  required CalendarIcsMeta? base,
  CalendarIcsStatus? status,
  CalendarTransparency? transparency,
  List<String>? categories,
  String? url,
  CalendarGeo? geo,
}) {
  if (base == null) {
    if (status == null &&
        transparency == null &&
        categories == null &&
        url == null &&
        geo == null) {
      return null;
    }
    return CalendarIcsMeta(
      status: status,
      transparency: transparency,
      categories: categories ?? _emptyCategories,
      url: url,
      geo: geo,
    );
  }
  return base.copyWith(
    status: status,
    transparency: transparency,
    categories: categories ?? base.categories,
    url: url,
    geo: geo,
  );
}

List<String>? resolveCategoryOverride({
  required CalendarIcsMeta? base,
  required List<String> categories,
}) {
  if (base == null && categories.isEmpty) {
    return null;
  }
  return categories;
}
