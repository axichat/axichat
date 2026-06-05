import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every divergent surface has an explicit lifecycle test owner', () {
    final missing = _registeredDivergentSurfaceOwners.entries
        .where((entry) => !_testFileMentions(entry.value, entry.key))
        .map((entry) => '${entry.key} -> ${entry.value}')
        .toList(growable: false);

    expect(
      missing,
      isEmpty,
      reason:
          'Every divergent BuildContext surface must have a widget lifecycle '
          'test that opens it from a disposable child context, unmounts the '
          'opener, rebuilds/interacts inside the divergent surface, then closes '
          'it while asserting no provider or deactivated-context errors.',
    );
  });
}

const Map<String, String> _registeredDivergentSurfaceOwners = <String, String>{
  'openComposeDraft': 'test/draft/view/compose_draft_context_test.dart',
  'showAccountRecoveryDialog':
      'test/authentication/view/recovery_dialog_context_test.dart',
  'showRecoveryEmailSetupDialog':
      'test/settings/view/account_recovery_settings_context_test.dart',
  'showRecoveryTotpSetupDialog':
      'test/settings/view/account_recovery_settings_context_test.dart',
  'AvatarEditorRoute': 'test/avatar/view/avatar_editor_context_test.dart',
  'ArchivesRoute': 'test/chats/view/archives_context_test.dart',
  'AttachmentGalleryRoute':
      'test/attachments/view/attachment_gallery_context_test.dart',
  'ArchivedChatRoute': 'test/chats/view/archived_chat_context_test.dart',
  'ProfileRoute': 'test/profile/view/profile_context_test.dart',
  'showContactDetailsSheet':
      'test/contacts/view/contact_details_context_test.dart',
  'showAddToFolderSheet': 'test/folders/view/folder_picker_sheet_test.dart',
  'showContactFolderRuleSheet':
      'test/folders/view/folder_picker_sheet_test.dart',
  'showFolderCreateDialog': 'test/folders/view/folder_picker_sheet_test.dart',
  'showNotificationDialog':
      'test/notifications/view/notification_context_test.dart',
  'showPendingAttachmentPreview':
      'test/attachments/view/pending_attachment_preview_context_test.dart',
  'showCalendarTaskSearch':
      'test/calendar/view/shell/calendar_task_search_test.dart',
  'showCalendarTaskShareSheet':
      'test/calendar/view/tasks/calendar_task_share_context_test.dart',
  'showCalendarAvailabilityShareSheet':
      'test/calendar/view/availability/calendar_availability_share_context_test.dart',
  'showCalendarAvailabilityShareViewer':
      'test/calendar/view/availability/availability_viewer_context_test.dart',
  'showCalendarCriticalPathShareSheet':
      'test/calendar/view/sidebar/calendar_critical_path_share_context_test.dart',
  'showCriticalPathPicker':
      'test/calendar/view/sidebar/critical_path_picker_context_test.dart',
  'showQuickAddModal':
      'test/calendar/view/shell/calendar_view_interaction_test.dart',
  'showDayEventEditor':
      'test/calendar/view/shell/calendar_view_interaction_test.dart',
  'showCalendarTaskCopySheet':
      'test/calendar/view/tasks/calendar_task_copy_context_test.dart',
  'showCalendarExportFormatSheet':
      'test/calendar/view/tasks/calendar_transfer_context_test.dart',
  'RoomAvatarEditorSheet.show': 'test/muc/view/room_members_sheet_test.dart',
  'showTransportChoiceDialog':
      'test/common/ui/transport_choice_dialog_context_test.dart',
  'showLinkActionDialog': 'test/common/ui/link_action_dialog_context_test.dart',
  'confirm': 'test/common/ui/axi_confirm_context_test.dart',
  'AxiPopover': 'test/common/ui/axi_popover_back_test.dart',
  'AxiMore': 'test/common/ui/axi_more_context_test.dart',
  'RecipientChipsBar overlay':
      'test/chat/view/recipient_chips_bar_context_test.dart',
  'CalendarNavigation overlay':
      'test/calendar/view/shell/calendar_navigation_context_test.dart',
  'CalendarDateTimeField overlay':
      'test/calendar/view/tasks/calendar_date_time_field_context_test.dart',
  'CalendarGrid task popover':
      'test/calendar/view/grid/calendar_grid_context_test.dart',
  'BaseTaskTile popover':
      'test/calendar/view/tasks/base_task_tile_context_test.dart',
  'TaskSidebar popovers':
      'test/calendar/view/sidebar/task_sidebar_context_test.dart',
};

bool _testFileMentions(String path, String surfaceId) {
  final file = File(path);
  if (!file.existsSync()) {
    return false;
  }
  return file.readAsStringSync().contains(surfaceId);
}
