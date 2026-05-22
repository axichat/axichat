// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/availability/availability_request_sheet.dart';
import 'package:axichat/src/calendar/view/availability/calendar_availability_editor_sheet.dart';
import 'package:axichat/src/calendar/view/month/day_event_editor.dart';
import 'package:axichat/src/calendar/view/sidebar/critical_path_copy_sheet.dart';
import 'package:axichat/src/calendar/view/sidebar/critical_path_panel.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_transfer_sheet.dart';
import 'package:axichat/src/calendar/view/tasks/quick_add_modal.dart';
import 'package:axichat/src/calendar/view/tasks/location_autocomplete.dart';
import 'package:axichat/src/calendar/view/tasks/task_copy_sheet.dart';
import 'package:axichat/src/calendar/view/tasks/task_view_sheet.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/view/contact_export_sheet.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
// Widgetbook is only used by this development entrypoint.
// ignore: depend_on_referenced_packages
import 'package:widgetbook/widgetbook.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _ensureWidgetbookStorage();
  runApp(const AffectedModalWidgetbook());
}

class AffectedModalWidgetbook extends StatelessWidget {
  const AffectedModalWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      appBuilder: _widgetbookAppBuilder,
      addons: [
        ViewportAddon([
          const ViewportData(
            name: 'Phone sheet',
            width: 390,
            height: 844,
            pixelRatio: 1,
            platform: TargetPlatform.android,
            safeAreas: EdgeInsets.only(bottom: 24),
          ),
          const ViewportData(
            name: 'Desktop dialog',
            width: 1280,
            height: 900,
            pixelRatio: 1,
            platform: TargetPlatform.macOS,
          ),
        ]),
        LocalizationAddon(
          locales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          initialLocale: const Locale('en'),
        ),
      ],
      directories: affectedModalDirectories(),
    );
  }
}

Widget _widgetbookAppBuilder(BuildContext context, Widget child) {
  final ShadThemeData shadTheme = AppTheme.build(
    shadColor: ShadColor.neutral,
    brightness: Brightness.light,
    platform: Theme.of(context).platform,
  );
  final ThemeData materialTheme = ThemeData(
    platform: Theme.of(context).platform,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: shadTheme.colorScheme.primary,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: shadTheme.colorScheme.background,
    cardColor: shadTheme.colorScheme.card,
    dividerColor: shadTheme.colorScheme.border,
    extensions: [
      AppTheme.tokens(brightness: Brightness.light),
      axiBorders,
      axiRadii,
      axiSpacing,
      axiSizing,
      axiMotion,
    ],
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: materialTheme,
    home: ShadTheme(
      data: shadTheme,
      child: BlocProvider(
        create: (context) => SettingsCubit(),
        child: EnvScope(
          child: Scaffold(body: SafeArea(child: child)),
        ),
      ),
    ),
  );
}

List<WidgetbookNode> affectedModalDirectories() {
  final Map<String, List<_AffectedModalStory>> grouped = {};
  for (final story in _affectedModalStories()) {
    grouped.putIfAbsent(story.group, () => <_AffectedModalStory>[]).add(story);
  }
  return [
    WidgetbookCategory(
      name: 'Affected modals',
      isInitiallyExpanded: true,
      children: [
        for (final entry in grouped.entries)
          WidgetbookFolder(
            name: entry.key,
            isInitiallyExpanded: entry.key == 'Calendar',
            children: [
              for (final story in entry.value)
                WidgetbookComponent(
                  name: story.name,
                  useCases: [
                    WidgetbookUseCase(
                      name: story.contract,
                      builder: (context) => _AffectedModalPreview(story: story),
                    ),
                  ],
                ),
            ],
          ),
      ],
    ),
  ];
}

List<_AffectedModalStory> _affectedModalStories() {
  return [
    _AffectedModalStory(
      group: 'Shared primitives',
      name: 'AxiSheetScaffold tall editor',
      contract: 'scrolling body with fixed actions',
      summary: 'Shared tall-sheet layout used by calendar and chat editors.',
      content: (context, close) => _editorSheet(
        context,
        close,
        title: 'Shared editor shell',
        subtitle: 'Header divider, body gutter, scroll body, fixed actions.',
        fields: const ['Title', 'Description', 'Location'],
        sections: const ['Schedule', 'Reminders', 'Participants'],
      ),
    ),
    _AffectedModalStory(
      group: 'Shared primitives',
      name: 'AxiInputDialog',
      contract: 'dialog text prompt',
      summary:
          'Shared input prompt used by folder, roster, blocklist, chat room, email import, and logout flows.',
      preferDialogOnMobile: true,
      content: (context, close) => _inputPromptSheet(
        context,
        close,
        title: 'Input dialog',
        fieldLabel: 'Name',
        description:
            'The repaired dialog keeps the input below the header divider.',
        primaryLabel: context.l10n.commonContinue,
      ),
    ),
    _AffectedModalStory(
      group: 'Shared primitives',
      name: 'AxiMore action menu',
      contract: 'short action sheet/dialog',
      summary:
          'The short action menu keeps dialog presentation on mobile when requested.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'More options',
        subtitle: 'Action-list sheet using the shared header/body contract.',
        options: const [
          _StoryOption('Archive', LucideIcons.archive),
          _StoryOption('Copy link', LucideIcons.link),
          _StoryOption('Delete', LucideIcons.trash2, destructive: true),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Quick add task',
      contract: 'actual quick-add sheet',
      summary: 'Keyboard footer behavior and bottom inset repair target.',
      actualOpen: (context) => showQuickAddModal(
        context: context,
        prefilledDateTime: _storyDate(),
        prefilledText: 'Plan launch review tomorrow at 10',
        onTaskAdded: (_, _) {},
        locationHelper: LocationAutocompleteHelper.fromSeeds(const []),
      ),
      content: (context, close) => QuickAddModal(
        surface: QuickAddModalSurface.bottomSheet,
        prefilledDateTime: _storyDate(),
        prefilledText: 'Plan launch review tomorrow at 10',
        onTaskAdded: (_, _) {},
        locationHelper: LocationAutocompleteHelper.fromSeeds(const []),
        onDismiss: close,
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'New day event',
      contract: 'actual route launcher',
      summary:
          'Keyboard footer behavior, header divider, and body gutter repair target.',
      actualOpen: (context) =>
          showDayEventEditor(context: context, initialDate: _storyDate()),
      content: (context, close) => _editorSheet(
        context,
        close,
        title: 'New day event',
        subtitle: 'All-day event editor with header divider and fixed actions.',
        fields: const ['Title', 'Optional details'],
        sections: const ['Dates', 'Reminders', 'Categories', 'Participants'],
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Edit task',
      contract: 'tall editor sheet',
      summary: 'Preserved header save/close actions and local spacing.',
      content: (context, close) => _editorSheet(
        context,
        close,
        title: 'Edit task',
        subtitle: 'Task editor preview with save and close header actions.',
        headerActions: [
          AxiIconButton.outline(
            iconData: Icons.check,
            tooltip: context.l10n.commonSave,
            onPressed: () {},
            color: calendarPrimaryColor,
          ),
          AxiIconButton.outline(
            iconData: Icons.close,
            tooltip: context.l10n.calendarCloseTooltip,
            onPressed: close,
            color: calendarSubtitleColor,
          ),
        ],
        fields: const ['Task name', 'Description', 'Location'],
        sections: const [
          'Checklist',
          'Schedule',
          'Deadline',
          'Recurrence',
          'Critical paths',
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Split task picker',
      contract: 'date-time picker sheet',
      summary:
          'Scaffolded picker affected by edge dividers and zero surface padding.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Split task',
        subtitle: 'Choose where the scheduled task should split.',
        options: const [
          _StoryOption('09:30', LucideIcons.clock3),
          _StoryOption('10:00', LucideIcons.clock4),
          _StoryOption('10:30', LucideIcons.clock5),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Critical path picker',
      contract: 'actual picker sheet',
      summary: 'Live-update picker preserved by the repair.',
      preferDialogOnMobile: true,
      actualOpen: (context) => showCriticalPathPicker(
        context: context,
        paths: _storyCriticalPaths(),
        stayOpen: true,
      ),
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Add to critical path',
        subtitle: 'Picker with fixed footer create action.',
        options: const [
          _StoryOption('Launch path', LucideIcons.route),
          _StoryOption('Design review', LucideIcons.route),
        ],
        footerLabel: 'New critical path',
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Critical path name prompt',
      contract: 'short dialog prompt',
      summary: 'Short name prompt must stay a dialog on mobile.',
      preferDialogOnMobile: true,
      actualOpen: (context) =>
          promptCriticalPathName(context: context, title: 'New critical path'),
      content: (context, close) => _inputPromptSheet(
        context,
        close,
        title: 'New critical path',
        fieldLabel: 'Critical path name',
        description:
            'Name prompts use the shared scaffolded input-dialog spacing.',
        primaryLabel: context.l10n.commonSave,
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Critical path copy',
      contract: 'actual copy decision sheet',
      summary: 'Short copy flow with shared actions and dividers.',
      preferDialogOnMobile: true,
      actualOpen: (context) => showCalendarCriticalPathCopySheet(
        context: context,
        path: _storyCriticalPaths().first,
        tasks: [_storyTask()],
        canAddToPersonal: true,
        canAddToChat: true,
      ),
      content: (context, close) => CalendarCriticalPathCopyDecisionSheet(
        path: _storyCriticalPaths().first,
        tasks: [_storyTask()],
        canAddToPersonal: true,
        canAddToChat: true,
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Critical path share',
      contract: 'share composer sheet',
      summary:
          'Scaffolded share sheet affected by footer and edge-divider behavior.',
      content: (context, close) => _editorSheet(
        context,
        close,
        title: 'Share critical path',
        subtitle: 'Recipient picker, fragment preview, and send action.',
        fields: const ['Recipients', 'Message'],
        sections: const ['Critical path preview', 'Permissions'],
        primaryLabel: 'Share',
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Task copy',
      contract: 'actual copy decision sheet',
      summary: 'Short copy flow with shared actions and dividers.',
      preferDialogOnMobile: true,
      actualOpen: (context) => showCalendarTaskCopySheet(
        context: context,
        task: _storyTask(),
        canAddToPersonal: true,
        canAddToChat: true,
      ),
      content: (context, close) => CalendarTaskCopyDecisionSheet(
        task: _storyTask(),
        canAddToPersonal: true,
        canAddToChat: true,
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Task share',
      contract: 'share composer sheet',
      summary: 'Task share sheet uses the same zero-padding scaffold contract.',
      content: (context, close) => _editorSheet(
        context,
        close,
        title: 'Share task',
        subtitle:
            'Recipient chips, read-only toggle, preview, and send action.',
        fields: const ['Recipients', 'Message'],
        sections: const ['Task preview', 'Read-only copy'],
        primaryLabel: 'Share',
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Task view',
      contract: 'actual view sheet',
      summary: 'Read-only task viewer with action list.',
      content: (context, close) =>
          CalendarTaskViewSheet(task: _storyTask(), onCopyPressed: () {}),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Transfer/export format',
      contract: 'actual short format picker',
      summary: 'Short transfer/export choice sheet remains dialog-preferred.',
      preferDialogOnMobile: true,
      actualOpen: (context) => showCalendarExportFormatSheet(context),
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Choose export format',
        options: const [
          _StoryOption('ICS calendar file', LucideIcons.calendarCheck2),
          _StoryOption('JSON backup', LucideIcons.braces),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Date-time picker',
      contract: 'picker bottom sheet',
      summary:
          'Calendar date/time bottom sheet uses zero surface padding and shared close chrome.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Pick date and time',
        subtitle: 'Month grid and time selectors preview.',
        options: const [
          _StoryOption('May 18, 2026', LucideIcons.calendarDays),
          _StoryOption('10:00 AM', LucideIcons.clock),
          _StoryOption('Done', LucideIcons.check),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Task search',
      contract: 'search sheet',
      summary:
          'Task search sheet uses calendar modal context and scaffolded list content.',
      content: (context, close) => _editorSheet(
        context,
        close,
        title: 'Search tasks',
        subtitle: 'Search input, results list, and close action.',
        fields: const ['Search tasks'],
        sections: const ['Today', 'This week', 'Unscheduled'],
        primaryLabel: 'Select',
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Availability editor',
      contract: 'actual availability editor shell',
      summary: 'Availability windows editor is a scaffolded tall sheet.',
      actualOpen: (context) => showCalendarAvailabilityEditorSheet(
        context: context,
        model: _storyCalendarModel(),
      ),
      content: (context, close) =>
          CalendarAvailabilityEditorSheet(model: _storyCalendarModel()),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Free-busy editor',
      contract: 'free-busy tall sheet',
      summary: 'Free/busy editor shares the same tall editor footer contract.',
      content: (context, close) => _editorSheet(
        context,
        close,
        title: 'Edit free/busy',
        subtitle: 'Intervals, status labels, and save footer.',
        fields: const ['Summary', 'Description'],
        sections: const [
          'Busy interval',
          'Tentative interval',
          'Free interval',
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Availability request',
      contract: 'actual request sheet',
      summary: 'Request sheet uses a scaffolded editor with fixed footer.',
      actualOpen: (context) => showCalendarAvailabilityRequestSheet(
        context: context,
        share: _storyAvailabilityShare(),
        requesterJid: 'me@example.com',
      ),
      content: (context, close) => CalendarAvailabilityRequestSheet(
        share: _storyAvailabilityShare(),
        requesterJid: 'me@example.com',
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Availability decision',
      contract: 'actual decision sheet',
      summary: 'Short decision sheet with shared action footer.',
      actualOpen: (context) => showCalendarAvailabilityDecisionSheet(
        context: context,
        request: _storyAvailabilityRequest(),
        canAddToPersonal: true,
        canAddToChat: true,
      ),
      content: (context, close) => CalendarAvailabilityDecisionSheet(
        request: _storyAvailabilityRequest(),
        canAddToPersonal: true,
        canAddToChat: true,
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Availability share',
      contract: 'share composer sheet',
      summary: 'Availability share sheet has the same scaffold/action layout.',
      content: (context, close) => _editorSheet(
        context,
        close,
        title: 'Share availability',
        subtitle: 'Preset name prompt, chat picker, and free/busy preview.',
        fields: const ['Recipients', 'Message'],
        sections: const ['Availability preview', 'Privacy'],
        primaryLabel: 'Share',
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Availability viewer',
      contract: 'viewer sheet',
      summary:
          'Viewer surface affected by modal surface and scaffold dividers.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Shared availability',
        subtitle: 'Read-only free/busy overlay with request action.',
        options: const [
          _StoryOption('Available Monday 9-12', LucideIcons.calendarRange),
          _StoryOption('Busy Monday 1-3', LucideIcons.calendarX),
        ],
        footerLabel: 'Request time',
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Calendar navigation',
      contract: 'navigation sheet',
      summary: 'Compact calendar navigation sheet uses zero surface padding.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Go to date',
        subtitle: 'Calendar navigation controls in a bottom sheet.',
        options: const [
          _StoryOption('Today', LucideIcons.calendarClock),
          _StoryOption('This week', LucideIcons.calendarDays),
          _StoryOption('Choose month', LucideIcons.calendar),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Calendar',
      name: 'Task sidebar sheet',
      contract: 'sidebar modal sheet',
      summary:
          'Sidebar add/search/edit sheets share the repaired scaffold contract.',
      content: (context, close) => _editorSheet(
        context,
        close,
        title: 'Task sidebar',
        subtitle: 'Compact task management sheet.',
        fields: const ['Add task', 'Filter tasks'],
        sections: const ['Inbox', 'Scheduled', 'Critical paths'],
      ),
    ),
    _AffectedModalStory(
      group: 'Folders',
      name: 'Add to folder',
      contract: 'folder picker sheet',
      summary:
          'Route surface padding was repaired so dividers are edge-to-edge.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Add to folder',
        subtitle: 'Message folder membership picker.',
        options: const [
          _StoryOption('Important', LucideIcons.star),
          _StoryOption('Receipts', LucideIcons.receiptText),
          _StoryOption('Projects', LucideIcons.folder),
        ],
        footerLabel: 'New folder',
      ),
    ),
    _AffectedModalStory(
      group: 'Folders',
      name: 'Contact folder rule',
      contract: 'folder rule sheet',
      summary: 'Same edge-divider repair as add-to-folder.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Folder rule',
        subtitle: 'Assign future messages from this contact.',
        options: const [
          _StoryOption('Marketing', LucideIcons.megaphone),
          _StoryOption('Newsletters', LucideIcons.newspaper),
          _StoryOption('Projects', LucideIcons.folder),
        ],
        footerLabel: 'New folder',
      ),
    ),
    _AffectedModalStory(
      group: 'Folders',
      name: 'New folder',
      contract: 'input dialog',
      summary: 'Original complaint: text field touched the divider.',
      preferDialogOnMobile: true,
      content: (context, close) => _inputPromptSheet(
        context,
        close,
        title: 'New folder',
        fieldLabel: 'Folder name',
        description: 'The body gutter now travels with the header divider.',
        primaryLabel: 'Create',
      ),
    ),
    _AffectedModalStory(
      group: 'Contacts and profile',
      name: 'Contact export',
      contract: 'actual short picker',
      summary: 'Contact export uses the short dialog-preferred scaffold.',
      preferDialogOnMobile: true,
      actualOpen: (context) => showContactExportFormatSheet(context),
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Export contacts',
        options: const [
          _StoryOption('CSV', LucideIcons.fileSpreadsheet),
          _StoryOption('vCard', LucideIcons.idCard),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Contacts and profile',
      name: 'Contact details',
      contract: 'details sheet',
      summary:
          'Contact details sheet is affected through adaptive sheet surface padding.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Contact details',
        subtitle: 'alice@example.com',
        options: const [
          _StoryOption('Start chat', LucideIcons.messageCircle),
          _StoryOption('Rename', LucideIcons.pencil),
          _StoryOption('Folder rule', LucideIcons.workflow),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Contacts and profile',
      name: 'Contact add / roster add',
      contract: 'input dialog',
      summary: 'AxiInputDialog user affected by the shared spacing repair.',
      preferDialogOnMobile: true,
      content: (context, close) => _inputPromptSheet(
        context,
        close,
        title: 'Add contact',
        fieldLabel: 'Email or JID',
        description: 'Shared input dialog preview.',
        primaryLabel: 'Add',
      ),
    ),
    _AffectedModalStory(
      group: 'Contacts and profile',
      name: 'Contact rename',
      contract: 'rename dialog',
      summary: 'Short text dialog affected by the input-dialog contract.',
      preferDialogOnMobile: true,
      content: (context, close) => _inputPromptSheet(
        context,
        close,
        title: 'Rename contact',
        fieldLabel: 'Display name',
        description: 'Contact rename keeps the same body gutter.',
        primaryLabel: context.l10n.commonSave,
      ),
    ),
    _AffectedModalStory(
      group: 'Chat and draft',
      name: 'Chat pending attachment actions',
      contract: 'action sheet',
      summary:
          'Chat attachment action sheet uses the shared scaffold/action row.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Attachment actions',
        options: const [
          _StoryOption('Preview', LucideIcons.eye),
          _StoryOption('Download', LucideIcons.download),
          _StoryOption('Remove', LucideIcons.trash2, destructive: true),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Chat and draft',
      name: 'Draft pending attachment actions',
      contract: 'action sheet',
      summary:
          'Draft attachment action sheet shares the same modal primitives.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Draft attachment',
        options: const [
          _StoryOption('Preview', LucideIcons.eye),
          _StoryOption('Replace', LucideIcons.refreshCcw),
          _StoryOption('Remove', LucideIcons.trash2, destructive: true),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Chat and draft',
      name: 'Attachment preview/gallery',
      contract: 'fixed-body modal',
      summary: 'Attachment gallery uses the fixed-body scaffold path.',
      content: (context, close) => _fixedBodySheet(
        context,
        close,
        title: 'Attachment preview',
        icon: LucideIcons.image,
        body: 'Large media preview with a fixed header and footer.',
      ),
    ),
    _AffectedModalStory(
      group: 'Chat and draft',
      name: 'Attachment approval',
      contract: 'approval dialog',
      summary:
          'Approval dialogs are affected through AxiModalSurface and shared actions.',
      preferDialogOnMobile: true,
      content: (context, close) => _inputPromptSheet(
        context,
        close,
        title: 'Send attachment?',
        fieldLabel: 'Caption',
        description:
            'Approval dialog with caption and destructive cancel path.',
        primaryLabel: 'Send',
      ),
    ),
    _AffectedModalStory(
      group: 'Chat and draft',
      name: 'Room members',
      contract: 'members sheet',
      summary:
          'Room member sheets use adaptive sheet route and scaffolded content.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Room members',
        subtitle: 'Manage occupants and moderation actions.',
        options: const [
          _StoryOption('Alice', LucideIcons.userRound),
          _StoryOption('Bob', LucideIcons.userRound),
          _StoryOption('Invite member', LucideIcons.userPlus),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Chat and draft',
      name: 'Room avatar upload',
      contract: 'avatar upload sheet',
      summary:
          'Avatar upload sheet uses the same route padding and footer ownership.',
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Room avatar',
        options: const [
          _StoryOption('Choose image', LucideIcons.imagePlus),
          _StoryOption('Crop preview', LucideIcons.crop),
          _StoryOption('Remove avatar', LucideIcons.trash2, destructive: true),
        ],
        footerLabel: 'Save avatar',
      ),
    ),
    _AffectedModalStory(
      group: 'Common app dialogs',
      name: 'Endpoint config',
      contract: 'configuration sheet',
      summary: 'Endpoint configuration sheet is a tall adaptive sheet.',
      content: (context, close) => _editorSheet(
        context,
        close,
        title: 'Custom server',
        subtitle: 'Domain and email provisioning controls.',
        fields: const ['Domain', 'Email provisioning token'],
        sections: const ['SMTP enabled', 'Reset defaults'],
      ),
    ),
    _AffectedModalStory(
      group: 'Common app dialogs',
      name: 'Email forwarding guide',
      contract: 'guide dialog',
      summary: 'Guide dialog uses AxiInputDialog/AxiSheetScaffold structure.',
      preferDialogOnMobile: true,
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Email forwarding',
        subtitle: 'Instructions in a scaffolded dialog surface.',
        options: const [
          _StoryOption('Copy forwarding address', LucideIcons.copy),
          _StoryOption('Open provider settings', LucideIcons.externalLink),
        ],
        footerLabel: 'Done',
      ),
    ),
    _AffectedModalStory(
      group: 'Common app dialogs',
      name: 'Email contact import',
      contract: 'import dialog',
      summary: 'Import dialog is an AxiInputDialog user.',
      preferDialogOnMobile: true,
      content: (context, close) => _inputPromptSheet(
        context,
        close,
        title: 'Import contacts',
        fieldLabel: 'Contact source',
        description:
            'File import status and retry controls use the shared dialog layout.',
        primaryLabel: 'Import',
      ),
    ),
    _AffectedModalStory(
      group: 'Common app dialogs',
      name: 'Block user',
      contract: 'input dialog',
      summary: 'Blocklist prompt uses the repaired AxiInputDialog spacing.',
      preferDialogOnMobile: true,
      content: (context, close) => _inputPromptSheet(
        context,
        close,
        title: 'Block user',
        fieldLabel: 'Email or JID',
        description: 'Destructive prompt preview.',
        primaryLabel: 'Block',
      ),
    ),
    _AffectedModalStory(
      group: 'Common app dialogs',
      name: 'Create chat room',
      contract: 'input dialog',
      summary: 'Chat-room creation prompt is an AxiInputDialog user.',
      preferDialogOnMobile: true,
      content: (context, close) => _inputPromptSheet(
        context,
        close,
        title: 'Create room',
        fieldLabel: 'Room name',
        description: 'Room setup prompt with shared footer actions.',
        primaryLabel: 'Create',
      ),
    ),
    _AffectedModalStory(
      group: 'Common app dialogs',
      name: 'Transport choice',
      contract: 'short choice dialog',
      summary: 'Transport choice is a short action/choice flow.',
      preferDialogOnMobile: true,
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Choose transport',
        options: const [
          _StoryOption('XMPP', LucideIcons.messageCircle),
          _StoryOption('Email', LucideIcons.mail),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Common app dialogs',
      name: 'Link action',
      contract: 'short action dialog',
      summary: 'Link action dialog shares modal surface and action spacing.',
      preferDialogOnMobile: true,
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Open link?',
        subtitle: 'https://example.com',
        options: const [
          _StoryOption('Open', LucideIcons.externalLink),
          _StoryOption('Copy', LucideIcons.copy),
        ],
      ),
    ),
    _AffectedModalStory(
      group: 'Common app dialogs',
      name: 'Logout confirmation',
      contract: 'confirmation dialog',
      summary:
          'Logout confirmation uses AxiInputDialog with loading/disabled action states.',
      preferDialogOnMobile: true,
      content: (context, close) => _choiceSheet(
        context,
        close,
        title: 'Log out?',
        subtitle: 'Confirm before ending the current session.',
        options: const [
          _StoryOption('Cancel', LucideIcons.x),
          _StoryOption('Log out', LucideIcons.logOut, destructive: true),
        ],
      ),
    ),
  ];
}

class _AffectedModalStory {
  const _AffectedModalStory({
    required this.group,
    required this.name,
    required this.contract,
    required this.summary,
    required this.content,
    this.actualOpen,
    this.preferDialogOnMobile = false,
  });

  final String group;
  final String name;
  final String contract;
  final String summary;
  final Widget Function(BuildContext context, VoidCallback close) content;
  final FutureOr<void> Function(BuildContext context)? actualOpen;
  final bool preferDialogOnMobile;
}

class _AffectedModalPreview extends StatelessWidget {
  const _AffectedModalPreview({required this.story});

  final _AffectedModalStory story;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final Size size = MediaQuery.sizeOf(context);
    final double previewHeight =
        size.height * context.sizing.dialogMaxHeightFraction;
    return SingleChildScrollView(
      padding: EdgeInsets.all(spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(story.name, style: context.textTheme.h3),
          SizedBox(height: spacing.xs),
          Text(story.summary, style: context.textTheme.muted),
          SizedBox(height: spacing.m),
          Wrap(
            spacing: spacing.s,
            runSpacing: spacing.s,
            children: [
              AxiButton.primary(
                onPressed: () => unawaited(_openStory(context)),
                leading: Icon(
                  LucideIcons.panelBottomOpen,
                  size: context.sizing.menuItemIconSize,
                ),
                child: const Text('Open modal route'),
              ),
              if (story.actualOpen != null)
                AxiButton.outline(
                  onPressed: () => _openActualStory(context),
                  leading: Icon(
                    LucideIcons.play,
                    size: context.sizing.menuItemIconSize,
                  ),
                  child: const Text('Open production entrypoint'),
                ),
            ],
          ),
          SizedBox(height: spacing.m),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.sizing.dialogMaxWidth,
              ),
              child: SizedBox(
                height: previewHeight,
                child: AxiModalSurface(
                  padding: EdgeInsets.zero,
                  child: story.content(context, () {}),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStory(BuildContext context) {
    return showAdaptiveBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      preferDialogOnMobile: story.preferDialogOnMobile,
      showDragHandle: !story.preferDialogOnMobile,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        return story.content(
          sheetContext,
          () => Navigator.of(sheetContext).maybePop(),
        );
      },
    );
  }

  void _openActualStory(BuildContext context) {
    final FutureOr<void> result = story.actualOpen!(context);
    if (result is Future<void>) {
      unawaited(result);
    }
  }
}

Widget _choiceSheet(
  BuildContext context,
  VoidCallback close, {
  required String title,
  String? subtitle,
  required List<_StoryOption> options,
  String? footerLabel,
}) {
  return AxiSheetScaffold.scroll(
    header: AxiSheetHeader(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      onClose: close,
    ),
    footer: footerLabel == null
        ? null
        : AxiSheetActions(
            children: [
              Expanded(
                child: AxiButton.primary(
                  onPressed: close,
                  widthBehavior: AxiButtonWidth.expand,
                  leading: Icon(
                    LucideIcons.plus,
                    size: context.sizing.menuItemIconSize,
                  ),
                  child: Text(footerLabel),
                ),
              ),
            ],
          ),
    children: [
      for (final option in options) ...[
        option.destructive
            ? AxiListButton.destructiveGhost(
                leading: Icon(option.icon),
                onPressed: close,
                child: Text(option.label),
              )
            : AxiListButton(
                leading: Icon(option.icon),
                onPressed: close,
                child: Text(option.label),
              ),
        if (option != options.last) SizedBox(height: context.spacing.xs),
      ],
    ],
  );
}

Widget _inputPromptSheet(
  BuildContext context,
  VoidCallback close, {
  required String title,
  required String fieldLabel,
  required String description,
  required String primaryLabel,
}) {
  return AxiSheetScaffold.sections(
    header: AxiSheetHeader(title: Text(title), onClose: close),
    footer: AxiSheetActions(
      children: [
        AxiButton.outline(
          onPressed: close,
          child: Text(context.l10n.commonCancel),
        ),
        AxiButton.primary(onPressed: close, child: Text(primaryLabel)),
      ],
    ),
    sections: [
      AxiSheetSection.compact(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(description, style: context.textTheme.muted),
            SizedBox(height: context.spacing.m),
            AxiTextFormField(
              initialValue: fieldLabel,
              placeholder: Text(fieldLabel),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _editorSheet(
  BuildContext context,
  VoidCallback close, {
  required String title,
  String? subtitle,
  required List<String> fields,
  required List<String> sections,
  List<Widget> headerActions = const <Widget>[],
  String primaryLabel = 'Save',
}) {
  return AxiSheetScaffold.sections(
    header: AxiSheetHeader(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      onClose: close,
      actions: headerActions,
      showCloseButton: headerActions.isEmpty,
    ),
    footer: AxiSheetActions(
      children: [
        Expanded(
          child: AxiButton.outline(
            onPressed: close,
            widthBehavior: AxiButtonWidth.expand,
            child: Text(context.l10n.commonCancel),
          ),
        ),
        Expanded(
          child: AxiButton.primary(
            onPressed: close,
            widthBehavior: AxiButtonWidth.expand,
            child: Text(primaryLabel),
          ),
        ),
      ],
    ),
    sections: [
      AxiSheetSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final field in fields) ...[
              AxiTextFormField(
                initialValue: field == fields.first ? field : null,
                placeholder: Text(field),
                minLines: field.toLowerCase().contains('description') ? 3 : 1,
                maxLines: field.toLowerCase().contains('description') ? 4 : 1,
              ),
              if (field != fields.last) SizedBox(height: context.spacing.m),
            ],
          ],
        ),
      ),
      for (final section in sections)
        AxiSheetSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StorySectionHeader(title: section),
              SizedBox(height: context.spacing.s),
              _StorySectionBody(label: '$section controls'),
            ],
          ),
        ),
    ],
  );
}

Widget _fixedBodySheet(
  BuildContext context,
  VoidCallback close, {
  required String title,
  required IconData icon,
  required String body,
}) {
  return AxiSheetScaffold.sections(
    header: AxiSheetHeader(title: Text(title), onClose: close),
    sections: [
      AxiSheetSection(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: context.sizing.attachmentPreviewExtent),
              SizedBox(height: context.spacing.m),
              Text(body, style: context.textTheme.muted),
            ],
          ),
        ),
      ),
    ],
    footer: AxiSheetActions(
      children: [
        Expanded(
          child: AxiButton.outline(
            onPressed: close,
            widthBehavior: AxiButtonWidth.expand,
            child: Text(context.l10n.commonCancel),
          ),
        ),
        Expanded(
          child: AxiButton.primary(
            onPressed: close,
            widthBehavior: AxiButtonWidth.expand,
            child: const Text('Done'),
          ),
        ),
      ],
    ),
  );
}

class _StorySectionHeader extends StatelessWidget {
  const _StorySectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: context.textTheme.large);
  }
}

class _StorySectionBody extends StatelessWidget {
  const _StorySectionBody({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.muted.withValues(
          alpha: context.motion.tapHoverAlpha,
        ),
        borderRadius: context.radius,
        border: Border.fromBorderSide(context.borderSide),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacing.m),
        child: Row(
          children: [
            Icon(
              LucideIcons.slidersHorizontal,
              size: context.sizing.menuItemIconSize,
            ),
            SizedBox(width: context.spacing.s),
            Expanded(child: Text(label, style: context.textTheme.muted)),
          ],
        ),
      ),
    );
  }
}

class _StoryOption {
  const _StoryOption(this.label, this.icon, {this.destructive = false});

  final String label;
  final IconData icon;
  final bool destructive;
}

CalendarTask _storyTask() {
  final DateTime now = _storyDate();
  return CalendarTask(
    id: 'widgetbook-task',
    title: 'Launch review',
    description: 'Confirm scope, owners, and launch checklist.',
    scheduledTime: now,
    duration: const Duration(minutes: 60),
    priority: TaskPriority.important,
    isCompleted: false,
    createdAt: now,
    modifiedAt: now,
    location: 'Studio',
    deadline: now.add(const Duration(days: 1)),
    startHour: now.hour + now.minute / 60,
  );
}

List<CalendarCriticalPath> _storyCriticalPaths() {
  final DateTime now = _storyDate();
  return [
    CalendarCriticalPath(
      id: 'launch-path',
      name: 'Launch path',
      taskIds: const ['widgetbook-task'],
      createdAt: now,
      modifiedAt: now,
    ),
    CalendarCriticalPath(
      id: 'design-review',
      name: 'Design review',
      createdAt: now,
      modifiedAt: now,
    ),
  ];
}

CalendarModel _storyCalendarModel() {
  final CalendarTask task = _storyTask();
  final CalendarAvailability availability = _storyAvailability();
  return CalendarModel(
    tasks: {task.id: task},
    lastModified: _storyDate(),
    checksum: 'widgetbook',
    criticalPaths: {for (final path in _storyCriticalPaths()) path.id: path},
    availability: {availability.id: availability},
  );
}

CalendarAvailability _storyAvailability() {
  final DateTime start = _storyDate();
  final DateTime end = start.add(const Duration(hours: 3));
  return CalendarAvailability(
    id: 'availability',
    start: CalendarDateTime(value: start),
    end: CalendarDateTime(value: end),
    summary: 'Office hours',
    description: 'Available for launch planning.',
    windows: [
      CalendarAvailabilityWindow(
        start: CalendarDateTime(value: start),
        end: CalendarDateTime(value: end),
        summary: 'Planning window',
      ),
    ],
  );
}

CalendarAvailabilityShare _storyAvailabilityShare() {
  final DateTime start = _storyDate();
  final DateTime end = start.add(const Duration(hours: 4));
  return CalendarAvailabilityShare(
    id: 'availability-share',
    overlay: CalendarAvailabilityOverlay(
      owner: 'alice@example.com',
      rangeStart: CalendarDateTime(value: start),
      rangeEnd: CalendarDateTime(value: end),
      intervals: [
        CalendarFreeBusyInterval(
          start: CalendarDateTime(value: start.add(const Duration(hours: 1))),
          end: CalendarDateTime(value: start.add(const Duration(hours: 2))),
          type: CalendarFreeBusyType.busy,
        ),
      ],
    ),
  );
}

CalendarAvailabilityRequest _storyAvailabilityRequest() {
  final DateTime start = _storyDate();
  return CalendarAvailabilityRequest(
    id: 'availability-request',
    shareId: 'availability-share',
    requesterJid: 'me@example.com',
    ownerJid: 'alice@example.com',
    start: CalendarDateTime(value: start),
    end: CalendarDateTime(value: start.add(const Duration(hours: 1))),
    title: 'Launch review',
    description: 'Request a shared planning slot.',
  );
}

DateTime _storyDate() => DateTime(2026, 5, 18, 10);

void _ensureWidgetbookStorage() {
  try {
    HydratedBloc.storage;
  } on StorageNotFound {
    HydratedBloc.storage = _WidgetbookStorage();
  }
}

class _WidgetbookStorage implements Storage {
  final Map<String, dynamic> _store = {};

  @override
  dynamic read(String key) => _store[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> close() async {}
}
