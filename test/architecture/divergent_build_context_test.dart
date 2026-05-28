import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('divergent BuildContext surfaces', () {
    test(
      'current route/sheet/dialog/popover/overlay inventory is registered',
      () {
        final actual = _surfaceCounts(_libSourceFiles());

        expect(
          _formatCounts(actual),
          _formatCounts(_registeredSurfaceCounts),
          reason:
              'A divergent BuildContext surface was added or removed. '
              'Register new routes, dialogs, sheets, popovers, and overlays here '
              'so lifecycle/provider tests stay app-wide.',
        );
      },
    );

    test('typed routes with divergent builders stay registered', () {
      final actual = _routeSurfaceIds();

      expect(
        actual,
        _registeredRouteSurfaceIds,
        reason:
            'A GoRouter route was added or removed. Every route must be in the '
            'divergent-context test registry because route builders are not the '
            'same BuildContext as their openers.',
      );
    });
  });

  group('provider lookup safety', () {
    test('UI does not read services, stores, managers, or repositories', () {
      final offenses = _uiProviderLookups()
          .where((lookup) => lookup.isServiceLike)
          .map((lookup) => lookup.location)
          .toList();

      expect(
        offenses,
        isEmpty,
        reason:
            'Rendered UI must depend on blocs/cubits or local UI scopes. '
            'Services/stores/managers/repositories must be reached through the '
            'owning bloc/cubit or app provider wiring, not from a divergent '
            'BuildContext.',
      );
    });

    test(
      'UI does not use ancestor/provider APIs known to break across surfaces',
      () {
        final offenses = _sourceOffenses(_uiSourceFiles(), <Pattern>[
          RegExp(r'\bProvider\.of<'),
          RegExp(r'\bRepositoryProvider\.of<'),
          RegExp(r'\bfindAncestorWidgetOfExactType<'),
          RegExp(r'\brootContext\b'),
        ]);

        expect(
          offenses,
          isEmpty,
          reason:
              'These APIs are unsafe or forbidden in Axichat UI because they hide '
              'provider-boundary errors in routes, dialogs, sheets, popovers, and '
              'overlays.',
        );
      },
    );

    test('rendered UI does not retain service lookups through widget.locate', () {
      final offenses = _sourceOffenses(_uiSourceFiles(), <Pattern>[
        RegExp(
          r'\bwidget\.locate<[^>]*(Service|Store|Manager|Repository|Controller|Capability)[^>]*>',
        ),
      ]);

      expect(
        offenses,
        isEmpty,
        reason:
            'locate is only safe as a boundary bridge. Divergent surfaces should '
            'use it to re-provide existing blocs/cubits, not retain it and do '
            'service/provider lookups during later rebuilds.',
      );
    });
  });
}

const Map<String, int> _registeredSurfaceCounts = <String, int>{
  'lib/src/accessibility/view/accessibility_action_menu.dart': 1,
  'lib/src/attachments/view/attachment_gallery_view.dart': 1,
  'lib/src/attachments/view/pending_attachment_preview.dart': 1,
  'lib/src/authentication/view/endpoint_config_sheet.dart': 1,
  'lib/src/authentication/view/logout_button.dart': 1,
  'lib/src/calendar/view/availability/availability_request_sheet.dart': 2,
  'lib/src/calendar/view/availability/availability_viewer.dart': 2,
  'lib/src/calendar/view/availability/calendar_availability_editor_sheet.dart':
      1,
  'lib/src/calendar/view/availability/calendar_availability_share_sheet.dart':
      2,
  'lib/src/calendar/view/availability/calendar_free_busy_editor.dart': 2,
  'lib/src/calendar/view/chat/chat_task_card.dart': 1,
  'lib/src/calendar/view/grid/calendar_grid.dart': 5,
  'lib/src/calendar/view/month/day_event_editor.dart': 1,
  'lib/src/calendar/view/shell/calendar_navigation.dart': 3,
  'lib/src/calendar/view/shell/calendar_task_search.dart': 2,
  'lib/src/calendar/view/sidebar/calendar_critical_path_share_sheet.dart': 1,
  'lib/src/calendar/view/sidebar/critical_path_copy_sheet.dart': 1,
  'lib/src/calendar/view/sidebar/critical_path_panel.dart': 3,
  'lib/src/calendar/view/sidebar/task_sidebar.dart': 3,
  'lib/src/calendar/view/tasks/base_task_tile.dart': 2,
  'lib/src/calendar/view/tasks/calendar_date_time_field.dart': 3,
  'lib/src/calendar/view/tasks/calendar_task_share_sheet.dart': 1,
  'lib/src/calendar/view/tasks/calendar_transfer_sheet.dart': 1,
  'lib/src/calendar/view/tasks/quick_add_modal.dart': 1,
  'lib/src/calendar/view/tasks/task_copy_sheet.dart': 1,
  'lib/src/chat/view/chat.dart': 7,
  'lib/src/chat/view/composer/attachment_preview.dart': 2,
  'lib/src/chat/view/composer/composer_section.dart': 1,
  'lib/src/chat/view/overlays/chat_message_details.dart': 2,
  'lib/src/chat/view/overlays/room_members_sheet.dart': 3,
  'lib/src/chats/view/chats_filter_button.dart': 1,
  'lib/src/chats/view/chats_list.dart': 1,
  'lib/src/chats/view/contact_rename_dialog.dart': 1,
  'lib/src/common/ui/axi_adaptive_sheet.dart': 4,
  'lib/src/common/ui/axi_confirm.dart': 2,
  'lib/src/common/ui/axi_dialog_fab.dart': 1,
  'lib/src/common/ui/axi_fade_page_route.dart': 2,
  'lib/src/common/ui/axi_more.dart': 2,
  'lib/src/common/ui/axi_popover.dart': 6,
  'lib/src/common/ui/fade_scale_dialog.dart': 2,
  'lib/src/common/ui/link_action_dialog.dart': 1,
  'lib/src/common/ui/recipient_chips_bar.dart': 8,
  'lib/src/common/ui/transport_choice_dialog.dart': 1,
  'lib/src/contacts/view/contacts_list.dart': 4,
  'lib/src/draft/view/compose_launcher.dart': 2,
  'lib/src/draft/view/draft_form.dart': 4,
  'lib/src/email/view/email_contact_import_tile.dart': 2,
  'lib/src/email/view/email_forwarding_guide.dart': 4,
  'lib/src/folders/view/folder_picker_sheet.dart': 3,
  'lib/src/notifications/view/notification_dialog.dart': 2,
  'lib/src/profile/view/contact_export_sheet.dart': 1,
  'lib/src/profile/view/profile_screen.dart': 1,
  'lib/src/profile/view/profile_tile.dart': 1,
  'lib/src/settings/view/settings_controls.dart': 6,
};

const List<String> _registeredRouteSurfaceIds = <String>[
  'HomeShellRoute',
  'HomeRoute',
  'ProfileRoute',
  'AvatarEditorRoute',
  'ArchivesRoute',
  'AttachmentGalleryRoute',
  'BlocklistRoute',
  'ArchivedChatRoute',
  'GuestCalendarRoute',
  'EmailDemoRoute',
  'LoginRoute',
];

final RegExp _surfacePattern = RegExp(
  r'('
  r'showAdaptiveBottomSheet|'
  r'showFadeScaleDialog|'
  r'showDialog|'
  r'showGeneralDialog|'
  r'showModalBottomSheet|'
  r'Navigator\.of\([^)]*\)\.push|'
  r'AxiFadePageRoute|'
  r'PageRouteBuilder|'
  r'context\.push\(|'
  r'AxiPopover|'
  r'OverlayPortal|'
  r'OverlayEntry'
  r')',
);

final RegExp _routePattern = RegExp(
  r'^class\s+([A-Za-z0-9_]+Route)\s+extends\s+'
  r'(StatefulShellRouteData|TransitionGoRouteData)',
);

final RegExp _providerLookupPattern = RegExp(
  r'\b(?:(?:context\.(?:read|watch|select)|locate|widget\.locate)'
  r'<([^>]+)>|Provider\.of<([^>]+)>|RepositoryProvider\.of<([^>]+)>)',
);

Map<String, int> _surfaceCounts(List<File> files) {
  final counts = <String, int>{};
  for (final file in files) {
    final path = _relativePath(file);
    final matches = _matchingLines(file, _surfacePattern);
    if (matches.isNotEmpty) {
      counts[path] = matches.length;
    }
  }
  return counts;
}

List<String> _routeSurfaceIds() {
  final routes = File('lib/src/routes.dart');
  return routes
      .readAsLinesSync()
      .map((line) => _routePattern.firstMatch(line.trim())?.group(1))
      .whereType<String>()
      .toList(growable: false);
}

List<_ProviderLookup> _uiProviderLookups() {
  final lookups = <_ProviderLookup>[];
  for (final file in _uiSourceFiles()) {
    final path = _relativePath(file);
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      for (final match in _providerLookupPattern.allMatches(line)) {
        final type = match.group(1) ?? match.group(2) ?? match.group(3);
        if (type == null) {
          continue;
        }
        lookups.add(
          _ProviderLookup(
            type: type.trim(),
            location: _SourceLocation(
              path: path,
              line: index + 1,
              source: line.trim(),
            ),
          ),
        );
      }
    }
  }
  return lookups;
}

List<_SourceLocation> _sourceOffenses(
  List<File> files,
  List<Pattern> patterns,
) {
  final offenses = <_SourceLocation>[];
  for (final file in files) {
    final path = _relativePath(file);
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      if (patterns.any(line.contains)) {
        offenses.add(
          _SourceLocation(path: path, line: index + 1, source: line.trim()),
        );
      }
    }
  }
  return offenses;
}

List<String> _matchingLines(File file, RegExp pattern) {
  return file
      .readAsLinesSync()
      .where((line) => pattern.hasMatch(line))
      .toList(growable: false);
}

List<File> _libSourceFiles() {
  return Directory('lib/src')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !_relativePath(file).endsWith('.g.dart'))
      .toList(growable: false)
    ..sort((a, b) => _relativePath(a).compareTo(_relativePath(b)));
}

List<File> _uiSourceFiles() {
  return _libSourceFiles()
      .where((file) {
        final path = _relativePath(file);
        return path.contains('/view/') || path.startsWith('lib/src/common/ui/');
      })
      .toList(growable: false);
}

String _relativePath(File file) {
  return file.path.replaceAll(r'\', '/');
}

String _formatCounts(Map<String, int> counts) {
  final entries = counts.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');
}

final class _ProviderLookup {
  const _ProviderLookup({required this.type, required this.location});

  final String type;
  final _SourceLocation location;

  bool get isServiceLike {
    if (type.endsWith('Bloc') || type.endsWith('Cubit')) {
      return false;
    }
    return type == 'Capability' ||
        type == 'CredentialStore' ||
        type == 'http.Client' ||
        type.endsWith('Service') ||
        type.endsWith('Store') ||
        type.endsWith('Manager') ||
        type.endsWith('Repository') ||
        type.endsWith('Controller') ||
        type.endsWith('Queue');
  }
}

final class _SourceLocation {
  const _SourceLocation({
    required this.path,
    required this.line,
    required this.source,
  });

  final String path;
  final int line;
  final String source;

  @override
  String toString() => '$path:$line: $source';
}
