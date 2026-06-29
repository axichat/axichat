// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/legal_urls.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/email/bloc/email_contact_import_cubit.dart';
import 'package:axichat/src/email/bloc/email_encryption_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/transport/email_delta_worker_runtime.dart';
import 'package:axichat/src/email/view/email_contact_import_tile.dart';
import 'package:axichat/src/email/view/email_forwarding_guide.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/localization/view/language_selector.dart';
import 'package:axichat/src/common/notification_privacy.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/bloc/profile_export_cubit.dart';
import 'package:axichat/src/profile/utils/contact_exporter.dart';
import 'package:axichat/src/profile/view/contact_export_sheet.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/link.dart';
import 'package:delta_ffi/delta_safe.dart';

class SettingsSectionAnchors {
  SettingsSectionAnchors({
    this.importantKey,
    this.accountKey,
    this.dataKey,
    this.appearanceKey,
    this.notificationsKey,
    this.securityKey,
    this.chatPreferencesKey,
    this.emailPreferencesKey,
    this.aboutKey,
  });

  final GlobalKey? importantKey;
  final GlobalKey? accountKey;
  final GlobalKey? dataKey;
  final GlobalKey? appearanceKey;
  final GlobalKey? notificationsKey;
  final GlobalKey? securityKey;
  final GlobalKey? chatPreferencesKey;
  final GlobalKey? emailPreferencesKey;
  final GlobalKey? aboutKey;
}

@visibleForTesting
const int profileExportPickerBytesMaxSize = 256 * 1024 * 1024;

class ProfileExportSaveFileTooLargeException implements Exception {
  const ProfileExportSaveFileTooLargeException({
    required this.byteCount,
    required this.maxBytes,
  });

  final int byteCount;
  final int maxBytes;
}

@visibleForTesting
bool profileExportSaveShouldWriteBytes(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => false,
  };
}

@visibleForTesting
Future<String?> saveProfileExportFileWithPicker({
  required File file,
  required String filename,
  required TargetPlatform platform,
  FilePicker? filePicker,
}) async {
  if (profileExportSaveShouldWriteBytes(platform)) {
    final byteCount = await file.length();
    if (byteCount > profileExportPickerBytesMaxSize) {
      throw ProfileExportSaveFileTooLargeException(
        byteCount: byteCount,
        maxBytes: profileExportPickerBytesMaxSize,
      );
    }
    final picker = filePicker ?? FilePicker.platform;
    return picker.saveFile(fileName: filename, bytes: await file.readAsBytes());
  }
  final picker = filePicker ?? FilePicker.platform;
  return picker.saveFile(fileName: filename);
}

class SettingsControls extends StatelessWidget {
  const SettingsControls({
    super.key,
    this.showDivider = false,
    this.fullWidthDividers = false,
    this.anchors,
    required this.locate,
    required this.onAccountRecovery,
    required this.onChangePassword,
    required this.onDeleteAccount,
    required this.applicationVersion,
  });

  final bool showDivider;
  final bool fullWidthDividers;
  final SettingsSectionAnchors? anchors;
  final T Function<T>() locate;
  final VoidCallback onAccountRecovery;
  final VoidCallback onChangePassword;
  final VoidCallback onDeleteAccount;
  final String? applicationVersion;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: _settingsSyncPublishFailed,
      listener: (context, state) {
        ShadToaster.maybeOf(context)?.show(
          FeedbackToast.error(message: context.l10n.settingsSyncFailureMessage),
        );
      },
      builder: (context, state) {
        final spacing = context.spacing;
        final sizing = context.sizing;
        final sectionHeaderPadding = EdgeInsets.symmetric(
          horizontal: spacing.m,
          vertical: spacing.s,
        );
        final compactTilePadding = EdgeInsets.symmetric(
          horizontal: spacing.m,
          vertical: spacing.s,
        );
        final switchPadding = EdgeInsets.symmetric(
          horizontal: spacing.m,
          vertical: spacing.m,
        );
        final exportState = context
            .select<ProfileExportCubit, ProfileExportState>(
              (cubit) => cubit.state,
            );
        final exportBusy = exportState.isBusy;
        String exportActionLabel(ProfileExportKind kind) {
          final label = context.l10n.profileExportActionLabel(
            kind.label(context.l10n),
          );
          if (exportState.activeKind == kind && exportState.totalItems > 0) {
            return '$label (${exportState.completedItems}/${exportState.totalItems})';
          }
          return label;
        }

        bool exportLoading(ProfileExportKind kind) =>
            exportBusy && exportState.activeKind == kind;

        final canBackgroundMessaging = context.select<SettingsCubit, bool>(
          (cubit) => cubit.canBackgroundMessaging,
        );
        final chatItems = context.select<ChatsCubit, List<Chat>>(
          (cubit) => cubit.state.items ?? const <Chat>[],
        );
        final emailEnabled = context
            .watch<SettingsCubit>()
            .state
            .endpointConfig
            .smtpEnabled;
        final xmppEnabled = state.endpointConfig.xmppEnabled;
        final profileJid = context.select<ProfileCubit, String>(
          (cubit) => cubit.state.jid,
        );
        final recoveryAvailable =
            state.endpointConfig.isAxiImDomain && isAxiJid(profileJid);
        final double dividerIndent = fullWidthDividers
            ? 0.0
            : sectionHeaderPadding.horizontal;
        final showImportantSection = canBackgroundMessaging;
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DonationRequestBanner(settingsState: state),
            if (showImportantSection)
              anchors?.importantKey == null
                  ? _SettingsSectionHeader(
                      label: context.l10n.settingsSectionImportant,
                      showDivider: showDivider,
                      dividerIndent: dividerIndent,
                      padding: sectionHeaderPadding,
                    )
                  : KeyedSubtree(
                      key: anchors?.importantKey,
                      child: _SettingsSectionHeader(
                        label: context.l10n.settingsSectionImportant,
                        showDivider: showDivider,
                        dividerIndent: dividerIndent,
                        padding: sectionHeaderPadding,
                      ),
                    ),
            if (showImportantSection)
              Padding(
                padding: switchPadding,
                child: const NotificationRequest(),
              ),
            anchors?.accountKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionAccount,
                    showDivider: showDivider,
                    dividerIndent: dividerIndent,
                    padding: sectionHeaderPadding,
                  )
                : KeyedSubtree(
                    key: anchors?.accountKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionAccount,
                      showDivider: showDivider,
                      dividerIndent: dividerIndent,
                      padding: sectionHeaderPadding,
                    ),
                  ),
            _SettingsActionButton(
              iconData: LucideIcons.user,
              label: context.l10n.profileEditAvatar,
              onPressed: () => context.push(
                const AvatarEditorRoute().location,
                extra: locate,
              ),
            ),
            _SettingsActionButton(
              iconData: LucideIcons.mail,
              label: context.l10n.emailForwardingGuideTitle,
              onPressed: emailEnabled
                  ? () async => await showEmailForwardingGuideDialog(context)
                  : null,
            ),
            if (recoveryAvailable)
              _SettingsActionButton(
                iconData: LucideIcons.shieldCheck,
                label: context.l10n.recoverySettingsTitle,
                onPressed: onAccountRecovery,
              ),
            _SettingsActionButton(
              iconData: LucideIcons.image,
              label: context.l10n.draftAttachmentsLabel,
              onPressed: () => context.push(
                const AttachmentGalleryRoute().location,
                extra: locate,
              ),
            ),
            _SettingsActionButton(
              iconData: LucideIcons.userX,
              label: context.l10n.profileBlocklistTitle,
              onPressed: () => context.push(const BlocklistRoute().location),
            ),
            _SettingsActionButton(
              iconData: LucideIcons.keyRound,
              label: context.l10n.profileChangePassword,
              onPressed: onChangePassword,
            ),
            _SettingsActionButton(
              iconData: LucideIcons.trash2,
              label: context.l10n.profileDeleteAccount,
              destructive: true,
              onPressed: onDeleteAccount,
            ),
            anchors?.dataKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionData,
                    dividerIndent: dividerIndent,
                    padding: sectionHeaderPadding,
                  )
                : KeyedSubtree(
                    key: anchors?.dataKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionData,
                      dividerIndent: dividerIndent,
                      padding: sectionHeaderPadding,
                    ),
                  ),
            _SettingsActionButton(
              iconData: LucideIcons.archive,
              label: context.l10n.profileArchives,
              onPressed: () =>
                  context.push(const ArchivesRoute().location, extra: locate),
            ),
            _SettingsActionButton(
              iconData: LucideIcons.userRoundPlus,
              label: context.l10n.emailContactsImportTitle,
              onPressed: emailEnabled
                  ? () async => await _showEmailContactImportDialog(context)
                  : null,
            ),
            BlocBuilder<ConnectivityCubit, ConnectivityState>(
              builder: (context, connectivityState) {
                final importBusy = connectivityState
                    .emailState
                    .historyImportPromptStatus
                    .isImporting;
                return _SettingsActionButton(
                  iconData: LucideIcons.inbox,
                  label: context.l10n.emailHistoryImportTitle,
                  loading: importBusy,
                  onPressed: emailEnabled && !importBusy
                      ? () async => await _handleEmailHistoryImport(context)
                      : null,
                );
              },
            ),
            _SettingsActionButton(
              iconData: LucideIcons.messagesSquare,
              label: exportActionLabel(ProfileExportKind.xmppMessages),
              loading: exportLoading(ProfileExportKind.xmppMessages),
              onPressed: exportBusy
                  ? null
                  : () async => await _handleXmppMessageExport(context),
            ),
            _SettingsActionButton(
              iconData: LucideIcons.users,
              label: exportActionLabel(ProfileExportKind.xmppContacts),
              loading: exportLoading(ProfileExportKind.xmppContacts),
              onPressed: exportBusy
                  ? null
                  : () async => await _handleXmppContactsExport(context),
            ),
            _SettingsActionButton(
              iconData: LucideIcons.mail,
              label: exportActionLabel(ProfileExportKind.emailMessages),
              loading: exportLoading(ProfileExportKind.emailMessages),
              onPressed: exportBusy || !emailEnabled
                  ? null
                  : () async => await _handleEmailMessageExport(context),
            ),
            _SettingsActionButton(
              iconData: LucideIcons.userRound,
              label: exportActionLabel(ProfileExportKind.emailContacts),
              loading: exportLoading(ProfileExportKind.emailContacts),
              onPressed: exportBusy || !emailEnabled
                  ? null
                  : () async => await _handleEmailContactsExport(context),
            ),
            anchors?.appearanceKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionAppearance,
                    dividerIndent: dividerIndent,
                    padding: sectionHeaderPadding,
                  )
                : KeyedSubtree(
                    key: anchors?.appearanceKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionAppearance,
                      dividerIndent: dividerIndent,
                      padding: sectionHeaderPadding,
                    ),
                  ),
            _SettingsControlRow(
              title: context.l10n.settingsMessageTextSize,
              state: state,
              settingId: GlobalSettingId.messageTextSize,
              chats: chatItems,
              minTileHeight: sizing.listButtonHeight,
              contentPadding: compactTilePadding,
              trailing: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
                child: AxiDropdown<MessageTextSize>(
                  value: state.messageTextSize,
                  maxWidth: sizing.menuMaxWidth,
                  enabled: !state.isGlobalSettingLoading(
                    GlobalSettingId.messageTextSize,
                  ),
                  onChanged: (messageTextSize) {
                    context.read<SettingsCubit>().updateMessageTextSize(
                      messageTextSize,
                    );
                  },
                  options: MessageTextSize.values
                      .map(
                        (messageTextSize) => AxiDropdownOption<MessageTextSize>(
                          value: messageTextSize,
                          label: messageTextSize.label(context.l10n),
                          child: _MessageTextSizeOptionLabel(
                            value: messageTextSize,
                          ),
                        ),
                      )
                      .toList(),
                  selectedBuilder:
                      (BuildContext context, MessageTextSize value) =>
                          _MessageTextSizeOptionLabel(value: value),
                ),
              ),
            ),
            _SettingsControlRow(
              title: context.l10n.settingsLanguage,
              state: state,
              settingId: GlobalSettingId.language,
              chats: chatItems,
              minTileHeight: sizing.listButtonHeight,
              contentPadding: compactTilePadding,
              trailing: const LanguageSelector(),
            ),
            _SettingsControlRow(
              title: context.l10n.settingsThemeMode,
              state: state,
              settingId: GlobalSettingId.themeMode,
              chats: chatItems,
              minTileHeight: sizing.listButtonHeight,
              contentPadding: compactTilePadding,
              trailing: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
                child: AxiDropdown<ThemeMode>(
                  value: state.themeMode,
                  maxWidth: sizing.menuMaxWidth,
                  enabled: !state.isGlobalSettingLoading(
                    GlobalSettingId.themeMode,
                  ),
                  onChanged: (themeMode) =>
                      context.read<SettingsCubit>().updateThemeMode(themeMode),
                  options: ThemeMode.values
                      .map(
                        (themeMode) => AxiDropdownOption<ThemeMode>(
                          value: themeMode,
                          label: themeMode.label(context.l10n),
                          child: Text(
                            themeMode.label(context.l10n),
                            style: context.textTheme.small,
                          ),
                        ),
                      )
                      .toList(),
                  selectedBuilder: (BuildContext context, mode) => Text(
                    mode.label(context.l10n),
                    style: context.textTheme.small,
                  ),
                ),
              ),
            ),
            _SettingsControlRow(
              title: context.l10n.settingsColorScheme,
              state: state,
              settingId: GlobalSettingId.colorScheme,
              chats: chatItems,
              minTileHeight: sizing.listButtonHeight,
              contentPadding: compactTilePadding,
              trailing: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: sizing.menuMaxWidth),
                child: AxiDropdown<ShadColor>(
                  value: state.shadColor,
                  maxWidth: sizing.menuMaxWidth,
                  enabled: !state.isGlobalSettingLoading(
                    GlobalSettingId.colorScheme,
                  ),
                  onChanged: (colorScheme) => context
                      .read<SettingsCubit>()
                      .updateColorScheme(colorScheme),
                  options: ShadColor.values
                      .map(
                        (colorScheme) => AxiDropdownOption<ShadColor>(
                          value: colorScheme,
                          label: colorScheme.name,
                          child: Text(
                            colorScheme.name,
                            style: context.textTheme.small,
                          ),
                        ),
                      )
                      .toList(),
                  selectedBuilder: (BuildContext context, ShadColor value) =>
                      Text(value.name, style: context.textTheme.small),
                ),
              ),
            ),
            _SettingsSwitchRow(
              title: context.l10n.settingsColorfulAvatars,
              subtitle: context.l10n.settingsColorfulAvatarsDescription,
              state: state,
              settingId: GlobalSettingId.colorfulAvatars,
              value: state.colorfulAvatars,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (colorfulAvatars) => context
                  .read<SettingsCubit>()
                  .toggleColorfulAvatars(colorfulAvatars),
            ),
            _SettingsSwitchRow(
              title: context.l10n.settingsLowMotion,
              subtitle: context.l10n.settingsLowMotionDescription,
              state: state,
              settingId: GlobalSettingId.lowMotion,
              value: state.lowMotion,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (lowMotion) =>
                  context.read<SettingsCubit>().toggleLowMotion(lowMotion),
            ),
            anchors?.notificationsKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionNotifications,
                    dividerIndent: dividerIndent,
                    padding: sectionHeaderPadding,
                  )
                : KeyedSubtree(
                    key: anchors?.notificationsKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionNotifications,
                      dividerIndent: dividerIndent,
                      padding: sectionHeaderPadding,
                    ),
                  ),
            _SettingsShortcutSwitchRow(
              title: context.l10n.settingsMuteAllNotifications,
              subtitle: context.l10n.settingsMuteAllNotificationsDescription,
              value: state.allNotificationsMuted,
              statusKind: _SettingsStatusKind.deviceOnly,
              contentPadding: switchPadding,
              onChanged: (muted) => context
                  .read<SettingsCubit>()
                  .toggleAllNotificationsMuted(muted),
            ),
            if (defaultTargetPlatform.supportsNotificationPreviewControls)
              _SettingsSwitchRow(
                title: context.l10n.settingsNotificationPreviews,
                subtitle: context.l10n.settingsNotificationPreviewsDescription,
                state: state,
                settingId: GlobalSettingId.notificationPreviews,
                value: state.notificationPreviewsEnabled,
                chats: chatItems,
                contentPadding: switchPadding,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleNotificationPreviews(enabled),
              ),
            anchors?.securityKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionSecurity,
                    dividerIndent: dividerIndent,
                    padding: sectionHeaderPadding,
                  )
                : KeyedSubtree(
                    key: anchors?.securityKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionSecurity,
                      dividerIndent: dividerIndent,
                      padding: sectionHeaderPadding,
                    ),
                  ),
            _EmailEncryptionBetaRow(
              settingsState: state,
              emailEnabled: emailEnabled,
              chats: chatItems,
              contentPadding: switchPadding,
            ),
            _SettingsSwitchRow(
              title: context.l10n.settingsAutoLoadEmailImages,
              subtitle: context.l10n.settingsAutoLoadEmailImagesDescription,
              state: state,
              settingId: GlobalSettingId.emailImageAutoload,
              value: state.autoLoadEmailImages,
              enabled: emailEnabled,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (enabled) => context
                  .read<SettingsCubit>()
                  .toggleAutoLoadEmailImages(enabled),
            ),
            anchors?.chatPreferencesKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionChats,
                    dividerIndent: dividerIndent,
                    padding: sectionHeaderPadding,
                  )
                : KeyedSubtree(
                    key: anchors?.chatPreferencesKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionChats,
                      dividerIndent: dividerIndent,
                      padding: sectionHeaderPadding,
                    ),
                  ),
            if (xmppEnabled) ...[
              _SettingsSwitchRow(
                title: context.l10n.settingsAutoDownloadImages,
                subtitle: context.l10n.settingsAutoDownloadImagesDescription,
                state: state,
                settingId: GlobalSettingId.attachmentAutoDownloadImages,
                value: state.autoDownloadImages,
                chats: chatItems,
                contentPadding: switchPadding,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .setAttachmentAutoDownloadSettings(
                      imagesEnabled: enabled,
                      videosEnabled: state.autoDownloadVideos,
                      documentsEnabled: state.autoDownloadDocuments,
                      archivesEnabled: state.autoDownloadArchives,
                    ),
              ),
              _SettingsSwitchRow(
                title: context.l10n.settingsAutoDownloadVideos,
                subtitle: context.l10n.settingsAutoDownloadVideosDescription,
                state: state,
                settingId: GlobalSettingId.attachmentAutoDownloadVideos,
                value: state.autoDownloadVideos,
                chats: chatItems,
                contentPadding: switchPadding,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .setAttachmentAutoDownloadSettings(
                      imagesEnabled: state.autoDownloadImages,
                      videosEnabled: enabled,
                      documentsEnabled: state.autoDownloadDocuments,
                      archivesEnabled: state.autoDownloadArchives,
                    ),
              ),
              _SettingsSwitchRow(
                title: context.l10n.settingsAutoDownloadDocuments,
                subtitle: context.l10n.settingsAutoDownloadDocumentsDescription,
                state: state,
                settingId: GlobalSettingId.attachmentAutoDownloadDocuments,
                value: state.autoDownloadDocuments,
                chats: chatItems,
                contentPadding: switchPadding,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .setAttachmentAutoDownloadSettings(
                      imagesEnabled: state.autoDownloadImages,
                      videosEnabled: state.autoDownloadVideos,
                      documentsEnabled: enabled,
                      archivesEnabled: state.autoDownloadArchives,
                    ),
              ),
              _SettingsSwitchRow(
                title: context.l10n.settingsAutoDownloadArchives,
                subtitle: context.l10n.settingsAutoDownloadArchivesDescription,
                state: state,
                settingId: GlobalSettingId.attachmentAutoDownloadArchives,
                value: state.autoDownloadArchives,
                chats: chatItems,
                contentPadding: switchPadding,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .setAttachmentAutoDownloadSettings(
                      imagesEnabled: state.autoDownloadImages,
                      videosEnabled: state.autoDownloadVideos,
                      documentsEnabled: state.autoDownloadDocuments,
                      archivesEnabled: enabled,
                    ),
              ),
            ],
            _SettingsSwitchRow(
              title: context.l10n.settingsMuteChatNotifications,
              subtitle: context.l10n.settingsMuteChatNotificationsDescription,
              state: state,
              settingId: GlobalSettingId.chatNotificationsMuted,
              value: state.chatNotificationsMuted,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (muted) => context
                  .read<SettingsCubit>()
                  .toggleChatNotificationsMuted(muted),
            ),
            _SettingsSwitchRow(
              title: context.l10n.settingsChatReadReceipts,
              subtitle: context.l10n.settingsChatReadReceiptsDescription,
              state: state,
              settingId: GlobalSettingId.chatReadReceipts,
              value: state.chatReadReceipts,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (enabled) =>
                  context.read<SettingsCubit>().toggleChatReadReceipts(enabled),
            ),
            _SettingsSwitchRow(
              title: context.l10n.settingsTypingIndicators,
              subtitle: context.l10n.settingsTypingIndicatorsDescription,
              state: state,
              settingId: GlobalSettingId.typingIndicators,
              value: state.indicateTyping,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (indicateTyping) => context
                  .read<SettingsCubit>()
                  .toggleIndicateTyping(indicateTyping),
            ),
            _SettingsSwitchRow(
              title: context.l10n.settingsChatSendOnEnter,
              subtitle: context.l10n.settingsChatSendOnEnterDescription,
              state: state,
              settingId: GlobalSettingId.chatSendOnEnter,
              value: state.chatSendOnEnter,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (enabled) =>
                  context.read<SettingsCubit>().toggleChatSendOnEnter(enabled),
            ),
            anchors?.emailPreferencesKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionEmail,
                    dividerIndent: dividerIndent,
                    padding: sectionHeaderPadding,
                  )
                : KeyedSubtree(
                    key: anchors?.emailPreferencesKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionEmail,
                      dividerIndent: dividerIndent,
                      padding: sectionHeaderPadding,
                    ),
                  ),
            _SettingsSwitchRow(
              title: context.l10n.settingsMuteEmailNotifications,
              subtitle: context.l10n.settingsMuteEmailNotificationsDescription,
              state: state,
              settingId: GlobalSettingId.emailNotificationsMuted,
              value: state.emailNotificationsMuted,
              enabled: emailEnabled,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (muted) => context
                  .read<SettingsCubit>()
                  .toggleEmailNotificationsMuted(muted),
            ),
            _SettingsSwitchRow(
              title: context.l10n.settingsEmailReadReceipts,
              subtitle: context.l10n.settingsEmailReadReceiptsDescription,
              state: state,
              settingId: GlobalSettingId.emailReadReceipts,
              value: state.emailReadReceipts,
              enabled: emailEnabled,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (enabled) => context
                  .read<SettingsCubit>()
                  .toggleEmailReadReceipts(enabled),
            ),
            _SettingsSwitchRow(
              title: context.l10n.settingsShareTokenFooter,
              subtitle: context.l10n.settingsShareTokenFooterDescription,
              state: state,
              settingId: GlobalSettingId.shareSignature,
              value: state.shareTokenSignatureEnabled,
              enabled: emailEnabled,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (enabled) => context
                  .read<SettingsCubit>()
                  .toggleShareTokenSignature(enabled),
            ),
            _SettingsSwitchRow(
              title: context.l10n.settingsEmailComposerWatermark,
              subtitle: context.l10n.settingsEmailComposerWatermarkDescription,
              state: state,
              settingId: GlobalSettingId.emailComposerWatermark,
              value: state.emailComposerWatermarkEnabled,
              enabled: emailEnabled,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (enabled) => context
                  .read<SettingsCubit>()
                  .toggleEmailComposerWatermark(enabled),
            ),
            _SettingsSwitchRow(
              title: context.l10n.settingsEmailSendOnEnter,
              subtitle: context.l10n.settingsEmailSendOnEnterDescription,
              state: state,
              settingId: GlobalSettingId.emailSendOnEnter,
              value: state.emailSendOnEnter,
              enabled: emailEnabled,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (enabled) =>
                  context.read<SettingsCubit>().toggleEmailSendOnEnter(enabled),
            ),
            _SettingsSwitchRow(
              title: context.l10n.settingsEmailSendConfirmation,
              subtitle: context.l10n.settingsEmailSendConfirmationDescription,
              state: state,
              settingId: GlobalSettingId.emailSendConfirmation,
              value: state.emailSendConfirmationEnabled,
              enabled: emailEnabled,
              chats: chatItems,
              contentPadding: switchPadding,
              onChanged: (enabled) => context
                  .read<SettingsCubit>()
                  .toggleEmailSendConfirmation(enabled),
            ),
            anchors?.aboutKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionAbout,
                    dividerIndent: dividerIndent,
                    padding: sectionHeaderPadding,
                  )
                : KeyedSubtree(
                    key: anchors?.aboutKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionAbout,
                      dividerIndent: dividerIndent,
                      padding: sectionHeaderPadding,
                    ),
                  ),
            _SettingsActionButton(
              iconData: LucideIcons.info,
              label: context.l10n.settingsAboutAxichat,
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: appDisplayName,
                applicationVersion: applicationVersion,
                applicationLegalese: context.l10n.settingsAboutLegalese,
              ),
            ),
            _SettingsLinkButton(
              label: context.l10n.settingsWebsiteLabel,
              link: websiteUrl,
              iconData: LucideIcons.link,
            ),
            _SettingsLinkButton(
              label: context.l10n.settingsTermsLabel,
              link: termsUrl,
              iconData: LucideIcons.link,
            ),
            _SettingsLinkButton(
              label: context.l10n.settingsPrivacyLabel,
              link: privacyUrl,
              iconData: LucideIcons.link,
            ),
            _SettingsLinkButton(
              label: context.l10n.settingsLicenseAgpl,
              link: licenseUrl,
              iconData: LucideIcons.link,
            ),
            _SettingsLinkButton(
              label: context.l10n.settingsGitlabLabel,
              link: gitlabUrl,
              faIconData: FontAwesomeIcons.gitlab,
            ),
            _SettingsLinkButton(
              label: context.l10n.settingsGithubLabel,
              link: githubUrl,
              faIconData: FontAwesomeIcons.github,
            ),
            _SettingsLinkButton(
              label: context.l10n.settingsMastodonLabel,
              link: mastodonUrl,
              faIconData: FontAwesomeIcons.mastodon,
            ),
            _SettingsLinkButton(
              label: context.l10n.settingsDonateLabel,
              link: donateUrl,
              faIconData: FontAwesomeIcons.heart,
            ),
            SizedBox(height: spacing.xxl),
          ],
        );
      },
    );
  }

  Future<void> _handleXmppMessageExport(BuildContext context) async {
    if (!await _confirmMessageExport(context)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final result = await context
        .read<ProfileExportCubit>()
        .exportXmppMessages();
    if (!context.mounted) {
      return;
    }
    await _handleExportResult(context, result);
  }

  Future<void> _handleEmailMessageExport(BuildContext context) async {
    if (!await _confirmMessageExport(context)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final result = await context
        .read<ProfileExportCubit>()
        .exportEmailMessages();
    if (!context.mounted) {
      return;
    }
    await _handleExportResult(context, result);
  }

  Future<void> _handleEmailHistoryImport(BuildContext context) async {
    try {
      await context.read<ConnectivityCubit>().importExistingEmailHistory(
        force: true,
      );
    } on EmailProvisioningException {
      if (!context.mounted) {
        return;
      }
      _showEmailHistoryImportFailed(context);
      return;
    } on EmailServiceException {
      if (!context.mounted) {
        return;
      }
      _showEmailHistoryImportFailed(context);
      return;
    } on EmailDeltaWorkerRuntimeException {
      if (!context.mounted) {
        return;
      }
      _showEmailHistoryImportFailed(context);
      return;
    } on DeltaSafeException {
      if (!context.mounted) {
        return;
      }
      _showEmailHistoryImportFailed(context);
      return;
    }
  }

  void _showEmailHistoryImportFailed(BuildContext context) {
    if (!context.mounted) {
      return;
    }
    ShadToaster.maybeOf(context)?.show(
      FeedbackToast.error(
        message: context.l10n.emailHistoryImportFailedMessage,
      ),
    );
  }

  Future<void> _handleXmppContactsExport(BuildContext context) async {
    final ContactExportFormat? format = await showContactExportFormatSheet(
      context,
    );
    if (!context.mounted || format == null) {
      return;
    }
    final labels = ContactExportLabels(
      csvHeaderName: context.l10n.profileExportCsvHeaderName,
      csvHeaderAddress: context.l10n.profileExportCsvHeaderAddress,
      fallbackLabel: context.l10n.profileExportContactsFilenameFallback,
    );
    final result = await context.read<ProfileExportCubit>().exportXmppContacts(
      format,
      labels,
    );
    if (!context.mounted) {
      return;
    }
    await _handleExportResult(context, result);
  }

  Future<void> _handleEmailContactsExport(BuildContext context) async {
    final ContactExportFormat? format = await showContactExportFormatSheet(
      context,
    );
    if (!context.mounted || format == null) {
      return;
    }
    final labels = ContactExportLabels(
      csvHeaderName: context.l10n.profileExportCsvHeaderName,
      csvHeaderAddress: context.l10n.profileExportCsvHeaderAddress,
      fallbackLabel: context.l10n.profileExportContactsFilenameFallback,
    );
    final result = await context.read<ProfileExportCubit>().exportEmailContacts(
      format,
      labels,
    );
    if (!context.mounted) {
      return;
    }
    await _handleExportResult(context, result);
  }

  Future<bool> _confirmMessageExport(BuildContext context) async {
    final bool? confirmed = await confirm(
      context,
      title: context.l10n.chatExportWarningTitle,
      message: context.l10n.chatExportWarningMessage,
      confirmLabel: context.l10n.commonContinue,
      cancelLabel: context.l10n.commonCancel,
      destructiveConfirm: false,
    );
    return confirmed == true;
  }

  Future<void> _handleExportResult(
    BuildContext context,
    ProfileExportResult result,
  ) async {
    final showToast = ShadToaster.maybeOf(context)?.show;
    final label = result.kind.label(context.l10n);
    if (result.outcome.isEmpty) {
      showToast?.call(
        FeedbackToast.info(
          message: context.l10n.profileExportEmptyMessage(label),
        ),
      );
      return;
    }
    if (result.outcome.isFailure || result.file == null) {
      showToast?.call(
        FeedbackToast.error(
          message: result.outcome.isIncomplete
              ? context.l10n.profileExportIncompleteMessage(label)
              : context.l10n.profileExportFailedMessage(label),
        ),
      );
      return;
    }
    final exportFile = result.file!;
    final exportFileName = p.basename(exportFile.path);
    if (!await exportFile.exists()) {
      if (!context.mounted) {
        return;
      }
      showToast?.call(
        FeedbackToast.error(
          message: context.l10n.profileExportFailedMessage(label),
        ),
      );
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) {
      return;
    }
    String? savePath;
    final pickerWritesBytes = profileExportSaveShouldWriteBytes(
      defaultTargetPlatform,
    );
    try {
      savePath = await saveProfileExportFileWithPicker(
        file: exportFile,
        filename: exportFileName,
        platform: defaultTargetPlatform,
      );
    } on ProfileExportSaveFileTooLargeException {
      if (!context.mounted) {
        return;
      }
      showToast?.call(
        FeedbackToast.error(
          message: context.l10n.profileExportTooLargeForDeviceMessage(label),
        ),
      );
      return;
    } on Exception {
      if (!context.mounted) {
        return;
      }
      showToast?.call(
        FeedbackToast.error(
          message: context.l10n.profileExportFailedMessage(label),
        ),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (savePath == null || savePath.trim().isEmpty) {
      return;
    }
    try {
      if (pickerWritesBytes) {
        try {
          await exportFile.delete();
        } on Exception {
          // Keep going even if temp cleanup fails.
        }
      } else {
        final destination = File(savePath);
        final samePath = p.equals(destination.path, exportFile.path);
        if (!samePath) {
          if (await destination.exists()) {
            await destination.delete();
          }
          await exportFile.copy(destination.path);
          try {
            await exportFile.delete();
          } on Exception {
            // Keep going even if temp cleanup fails.
          }
        }
      }
    } on Exception {
      if (!context.mounted) {
        return;
      }
      showToast?.call(
        FeedbackToast.error(
          message: context.l10n.profileExportFailedMessage(label),
        ),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (result.outcome.isIncomplete) {
      showToast?.call(
        FeedbackToast.warning(
          message: context.l10n.profileExportIncompleteMessage(label),
        ),
      );
    } else {
      showToast?.call(
        FeedbackToast.success(
          message: context.l10n.profileExportReadyMessage(label),
        ),
      );
    }
  }

  Future<void> _showEmailContactImportDialog(BuildContext context) async {
    context.read<EmailContactImportCubit>().reset();
    await showFadeScaleDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<EmailContactImportCubit>(),
        child: const EmailContactImportDialog(),
      ),
    );
  }
}

enum _EmailEncryptionActivationAction { importKey, createKey }

class _EmailEncryptionBetaRow extends StatefulWidget {
  const _EmailEncryptionBetaRow({
    required this.settingsState,
    required this.emailEnabled,
    required this.chats,
    this.contentPadding,
  });

  final SettingsState settingsState;
  final bool emailEnabled;
  final List<Chat> chats;
  final EdgeInsetsGeometry? contentPadding;

  @override
  State<_EmailEncryptionBetaRow> createState() =>
      _EmailEncryptionBetaRowState();
}

class _EmailEncryptionBetaRowState extends State<_EmailEncryptionBetaRow> {
  EmailEncryptionAccountInfo? _account;
  var _refreshed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _EmailEncryptionBetaRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emailEnabled != widget.emailEnabled) {
      _refreshed = false;
      if (!widget.emailEnabled) {
        _account = null;
        return;
      }
      _refreshIfNeeded();
    }
  }

  void _refreshIfNeeded() {
    if (_refreshed || !widget.emailEnabled) {
      return;
    }
    _refreshed = true;
    context.read<EmailEncryptionCubit>().refreshActiveAccount();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.emailEnabled) {
      return const SizedBox.shrink();
    }
    return BlocConsumer<EmailEncryptionCubit, EmailEncryptionState>(
      listener: _handleState,
      builder: (context, encryptionState) {
        final account = switch (encryptionState) {
          EmailEncryptionIdle(account: final activeAccount?) => activeAccount,
          _ => _account,
        };
        if (account == null) {
          return const SizedBox.shrink();
        }
        final enabled =
            widget.settingsState.emailEncryptionBetaEnabledByAddress[account
                .normalizedAddress] ==
            true;
        final busy = encryptionState.isBusy;
        return _SettingsControlRow(
          title: context.l10n.emailEncryptionBetaLabel,
          titleChipLabel: context.l10n.emailEncryptionBetaChip,
          titleChipTone: AxiStatusChipTone.info,
          subtitle: enabled
              ? context.l10n.emailEncryptionBetaEnabledStatus(
                  account.normalizedAddress,
                )
              : account.hasSelfKey
              ? context.l10n.emailEncryptionBetaDisabledExistingKeyStatus(
                  account.normalizedAddress,
                )
              : context.l10n.emailEncryptionBetaDisabledStatus(
                  account.normalizedAddress,
                ),
          state: widget.settingsState,
          settingId: GlobalSettingId.emailEncryptionBeta,
          chats: widget.chats,
          contentPadding: widget.contentPadding,
          trailing: ShadSwitch(
            value: enabled,
            onChanged: busy
                ? null
                : (value) {
                    _account = account;
                    if (value) {
                      _startActivation(context, account);
                      return;
                    }
                    context.read<EmailEncryptionCubit>().disable(
                      account.normalizedAddress,
                    );
                  },
          ),
        );
      },
    );
  }

  Future<void> _handleState(
    BuildContext context,
    EmailEncryptionState state,
  ) async {
    if (state is EmailEncryptionIdle) {
      if (_account != state.account && mounted) {
        setState(() {
          _account = state.account;
        });
      }
      return;
    }
    if (state is EmailEncryptionActivationReady) {
      await context.read<SettingsCubit>().setEmailEncryptionBetaEnabled(
        state.normalizedAddress,
        true,
      );
      if (!context.mounted) {
        return;
      }
      ShadToaster.maybeOf(context)?.show(
        FeedbackToast.success(
          message: context.l10n.emailEncryptionBetaActivationSuccess,
        ),
      );
      await context.read<EmailEncryptionCubit>().refreshActiveAccount();
      return;
    }
    if (state is EmailEncryptionDisableReady) {
      await context.read<SettingsCubit>().setEmailEncryptionBetaEnabled(
        state.normalizedAddress,
        false,
      );
      if (!context.mounted) {
        return;
      }
      ShadToaster.maybeOf(context)?.show(
        FeedbackToast.success(
          message: context.l10n.emailEncryptionBetaDisableSuccess,
        ),
      );
      await context.read<EmailEncryptionCubit>().refreshActiveAccount();
      return;
    }
    if (state is EmailEncryptionExportReady) {
      await _saveExport(context, state);
      return;
    }
    if (state is EmailEncryptionSelfKeyConfirmationRequired) {
      await _confirmSelfKeyIdentity(context, state);
      return;
    }
    if (state is EmailEncryptionFailure) {
      ShadToaster.maybeOf(context)?.show(
        FeedbackToast.error(message: _failureMessage(context, state.reason)),
      );
      await context.read<EmailEncryptionCubit>().refreshActiveAccount();
    }
  }

  Future<void> _startActivation(
    BuildContext context,
    EmailEncryptionAccountInfo account,
  ) async {
    final accepted = await confirm(
      context,
      title: context.l10n.emailEncryptionBetaWarningTitle,
      titleChipLabel: context.l10n.emailEncryptionBetaChip,
      titleChipTone: AxiStatusChipTone.info,
      message: account.hasSelfKey
          ? context.l10n.emailEncryptionBetaExistingKeyWarningBody
          : context.l10n.emailEncryptionBetaWarningBody,
      confirmLabel: context.l10n.commonContinue,
      cancelLabel: context.l10n.commonCancel,
      destructiveConfirm: false,
    );
    if (!context.mounted || accepted != true) {
      return;
    }
    if (account.hasSelfKey) {
      await context.read<EmailEncryptionCubit>().activateExistingKey();
      return;
    }
    final action = await _chooseActivationAction(context);
    if (!context.mounted || action == null) {
      return;
    }
    switch (action) {
      case _EmailEncryptionActivationAction.importKey:
        await _pickAndImportKey(context);
      case _EmailEncryptionActivationAction.createKey:
        await context.read<EmailEncryptionCubit>().createExport();
    }
  }

  Future<_EmailEncryptionActivationAction?> _chooseActivationAction(
    BuildContext context,
  ) {
    return showFadeScaleDialog<_EmailEncryptionActivationAction>(
      context: context,
      builder: (dialogContext) {
        final pop = Navigator.of(dialogContext).pop;
        return AxiDialog(
          constraints: BoxConstraints(
            maxWidth: dialogContext.sizing.dialogMaxWidth,
          ),
          title: Text(
            dialogContext.l10n.emailEncryptionBetaChooseActionTitle,
            style: dialogContext.modalHeaderTextStyle,
          ),
          actions: [
            AxiButton.outline(
              onPressed: () => pop(null),
              child: Text(dialogContext.l10n.commonCancel),
            ),
            AxiButton.outline(
              onPressed: () => pop(_EmailEncryptionActivationAction.importKey),
              child: Text(dialogContext.l10n.emailEncryptionBetaImportAction),
            ),
            AxiButton.primary(
              onPressed: () => pop(_EmailEncryptionActivationAction.createKey),
              child: Text(dialogContext.l10n.emailEncryptionBetaCreateAction),
            ),
          ],
          child: Text(
            dialogContext.l10n.emailEncryptionBetaChooseActionBody,
            style: dialogContext.textTheme.small,
          ),
        );
      },
    );
  }

  Future<void> _pickAndImportKey(BuildContext context) async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: const ['asc', 'pgp', 'gpg', 'zip'],
      );
    } on PlatformException {
      if (!context.mounted) {
        return;
      }
      ShadToaster.maybeOf(context)?.show(
        FeedbackToast.error(
          message: context.l10n.emailEncryptionBetaImportFailed,
        ),
      );
      return;
    }
    if (!context.mounted || result == null || result.files.isEmpty) {
      return;
    }
    final path = result.files.single.path;
    if (path == null || path.trim().isEmpty) {
      ShadToaster.maybeOf(context)?.show(
        FeedbackToast.error(
          message: context.l10n.emailEncryptionBetaImportFailed,
        ),
      );
      return;
    }
    await context.read<EmailEncryptionCubit>().importPrivateKey(File(path));
  }

  Future<void> _saveExport(
    BuildContext context,
    EmailEncryptionExportReady state,
  ) async {
    if (!context.mounted) {
      return;
    }
    final locate = context.read;
    final exportFilename = context.l10n.emailEncryptionBetaExportFilename;
    try {
      final exportBytes = await locate<EmailEncryptionCubit>()
          .exportBytesForSave(state);
      if (exportBytes == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      final savePath = await FilePicker.platform.saveFile(
        fileName: exportFilename,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        bytes: Platform.isAndroid || Platform.isIOS ? exportBytes : null,
      );
      if (!mounted) {
        return;
      }
      if (savePath == null || savePath.trim().isEmpty) {
        await locate<EmailEncryptionCubit>().cancelExport();
        return;
      }
      if (Platform.isAndroid || Platform.isIOS) {
        await locate<EmailEncryptionCubit>().completePlatformSavedExport(
          savePath,
        );
        return;
      }
      await locate<EmailEncryptionCubit>().saveExport(savePath);
    } on FileSystemException {
      if (!mounted) {
        return;
      }
      await locate<EmailEncryptionCubit>().failExportSave();
    } on PlatformException {
      if (!mounted) {
        return;
      }
      await locate<EmailEncryptionCubit>().failExportSave();
    }
  }

  Future<void> _confirmSelfKeyIdentity(
    BuildContext context,
    EmailEncryptionSelfKeyConfirmationRequired state,
  ) async {
    final identities = state.metadata.userIds.isEmpty
        ? context.l10n.emailEncryptionKeyIdentityNoIdentities
        : state.metadata.userIds.join(', ');
    final confirmed = await confirm(
      context,
      title: context.l10n.emailEncryptionKeyIdentityWarningTitle,
      message: context.l10n.emailEncryptionKeyIdentityWarningBody(
        state.metadata.fingerprint,
        identities,
      ),
      confirmLabel: context.l10n.commonContinue,
      cancelLabel: context.l10n.commonCancel,
      destructiveConfirm: false,
    );
    if (!context.mounted) {
      return;
    }
    if (confirmed == true) {
      await context.read<EmailEncryptionCubit>().confirmPrivateKeyImport();
      return;
    }
    await context.read<EmailEncryptionCubit>().cancelPrivateKeyImport();
  }

  String _failureMessage(
    BuildContext context,
    EmailEncryptionFailureReason reason,
  ) => switch (reason) {
    EmailEncryptionFailureReason.noActiveAccount =>
      context.l10n.emailEncryptionBetaNoActiveAccount,
    EmailEncryptionFailureReason.unsupportedKeyFormat =>
      context.l10n.emailEncryptionBetaUnsupportedFormat,
    EmailEncryptionFailureReason.noPrivateKeyFound =>
      context.l10n.emailEncryptionBetaNoPrivateKeyFound,
    EmailEncryptionFailureReason.ambiguousKeyArchive =>
      context.l10n.emailEncryptionBetaAmbiguousArchive,
    EmailEncryptionFailureReason.importFailed =>
      context.l10n.emailEncryptionBetaImportFailed,
    EmailEncryptionFailureReason.exportFailed =>
      context.l10n.emailEncryptionBetaExportFailed,
    EmailEncryptionFailureReason.saveFailed =>
      context.l10n.emailEncryptionBetaSaveFailed,
  };
}

bool _settingsSyncPublishFailed(SettingsState previous, SettingsState current) {
  for (final settingId in GlobalSettingId.syncedSettings) {
    if (previous.isGlobalSettingLoading(settingId) &&
        !current.isGlobalSettingLoading(settingId) &&
        current.isGlobalSettingNotSynced(settingId)) {
      return true;
    }
  }
  return false;
}

enum _SettingsStatusKind { notSynced, deviceOnly }

class _SettingsControlRow extends StatelessWidget {
  const _SettingsControlRow({
    required this.title,
    required this.state,
    required this.settingId,
    required this.trailing,
    required this.chats,
    this.titleChipLabel,
    this.titleChipTone = AxiStatusChipTone.neutral,
    this.subtitle,
    this.contentPadding,
    this.minTileHeight,
  });

  final String title;
  final SettingsState state;
  final GlobalSettingId settingId;
  final Widget trailing;
  final List<Chat> chats;
  final String? titleChipLabel;
  final AxiStatusChipTone titleChipTone;
  final String? subtitle;
  final EdgeInsetsGeometry? contentPadding;
  final double? minTileHeight;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final chatSettingId = _chatOverrideSettingFor(settingId);
    final overrideChats = chatSettingId == null
        ? const <Chat>[]
        : _chatOverridesFor(chatSettingId, chats);
    final statusKind = _settingsStatusKind(state, settingId);
    return ListItemPadding(
      child: AxiListTile(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _SettingsControlText(
                    title: title,
                    titleChipLabel: titleChipLabel,
                    titleChipTone: titleChipTone,
                    subtitle: subtitle,
                    statusKind: statusKind,
                  ),
                ),
                SizedBox(width: spacing.m),
                _SettingsTrailingControl(
                  loading: state.isGlobalSettingLoading(settingId),
                  child: trailing,
                ),
              ],
            ),
            if (overrideChats.isNotEmpty) ...[
              SizedBox(height: spacing.s),
              _SettingsOverrideSummary(
                chats: overrideChats,
                resetSettingId: chatSettingId,
              ),
            ],
          ],
        ),
        minTileHeight: minTileHeight ?? context.sizing.listButtonHeight,
        contentPadding: contentPadding,
      ),
    );
  }
}

class _SettingsControlText extends StatelessWidget {
  const _SettingsControlText({
    required this.title,
    required this.statusKind,
    this.titleChipLabel,
    this.titleChipTone = AxiStatusChipTone.neutral,
    this.subtitle,
  });

  final String title;
  final String? titleChipLabel;
  final AxiStatusChipTone titleChipTone;
  final String? subtitle;
  final _SettingsStatusKind? statusKind;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final trimmedSubtitle = subtitle?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.small.strong,
              ),
            ),
            if (titleChipLabel != null) ...[
              SizedBox(width: spacing.s),
              AxiStatusChip(label: titleChipLabel!, tone: titleChipTone),
            ],
          ],
        ),
        if (trimmedSubtitle != null && trimmedSubtitle.isNotEmpty) ...[
          SizedBox(height: spacing.xs),
          Text(trimmedSubtitle, style: context.textTheme.muted),
        ],
        if (statusKind != null) ...[
          SizedBox(height: spacing.s),
          _SettingsStatusChip(kind: statusKind!),
        ],
      ],
    );
  }
}

class _SettingsOverrideSummary extends StatefulWidget {
  const _SettingsOverrideSummary({
    required this.chats,
    required this.resetSettingId,
  });

  final List<Chat> chats;
  final ChatSettingId? resetSettingId;

  @override
  State<_SettingsOverrideSummary> createState() =>
      _SettingsOverrideSummaryState();
}

class _SettingsOverrideSummaryState extends State<_SettingsOverrideSummary> {
  bool _resetting = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final chatNames = widget.chats.map(_chatOverrideLabel).join(', ');
    return Wrap(
      spacing: spacing.s,
      runSpacing: spacing.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          context.l10n.settingsOverridesList(chatNames),
          style: context.textTheme.muted.copyWith(
            color: context.colorScheme.mutedForeground,
          ),
        ),
        if (widget.resetSettingId != null)
          AxiButton.outline(
            size: AxiButtonSize.sm,
            loading: _resetting,
            onPressed: _resetting ? null : _resetOverrides,
            child: Text(context.l10n.settingsOverridesResetAll),
          ),
      ],
    );
  }

  Future<void> _resetOverrides() async {
    final settingId = widget.resetSettingId;
    if (settingId == null) {
      return;
    }
    setState(() {
      _resetting = true;
    });
    try {
      final published = await context
          .read<ChatsCubit>()
          .resetChatSettingOverrides(
            settingId,
            chatJids: widget.chats.map((chat) => chat.jid),
          );
      if (!published && mounted) {
        ShadToaster.maybeOf(context)?.show(
          FeedbackToast.error(message: context.l10n.settingsSyncFailureMessage),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _resetting = false;
        });
      }
    }
  }
}

class _SettingsTrailingControl extends StatelessWidget {
  const _SettingsTrailingControl({required this.loading, required this.child});

  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return child;
    }
    return SizedBox.square(
      dimension: context.sizing.iconButtonSize,
      child: Center(
        child: AxiProgressIndicator(
          semanticsLabel: context.l10n.settingsSyncStatusSyncing,
        ),
      ),
    );
  }
}

class _SettingsStatusChip extends StatelessWidget {
  const _SettingsStatusChip({required this.kind});

  final _SettingsStatusKind kind;

  @override
  Widget build(BuildContext context) {
    return AxiStatusChip(
      label: switch (kind) {
        _SettingsStatusKind.notSynced =>
          context.l10n.settingsSyncStatusNotSynced,
        _SettingsStatusKind.deviceOnly =>
          context.l10n.settingsSyncStatusDeviceOnly,
      },
      tone: switch (kind) {
        _SettingsStatusKind.notSynced => AxiStatusChipTone.warning,
        _SettingsStatusKind.deviceOnly => AxiStatusChipTone.neutral,
      },
    );
  }
}

class _SettingsShortcutSwitchRow extends StatelessWidget {
  const _SettingsShortcutSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.statusKind,
    this.contentPadding,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;
  final _SettingsStatusKind? statusKind;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return ListItemPadding(
      child: AxiListTile(
        titleWidget: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _SettingsControlText(
                title: title,
                subtitle: subtitle,
                statusKind: statusKind,
              ),
            ),
            SizedBox(width: context.spacing.m),
            ShadSwitch(value: value, onChanged: onChanged),
          ],
        ),
        minTileHeight: context.sizing.listButtonHeight,
        contentPadding: contentPadding,
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.title,
    required this.state,
    required this.settingId,
    required this.value,
    required this.onChanged,
    required this.chats,
    this.subtitle,
    this.enabled = true,
    this.contentPadding,
  });

  final String title;
  final SettingsState state;
  final GlobalSettingId settingId;
  final bool value;
  final ValueChanged<bool> onChanged;
  final List<Chat> chats;
  final String? subtitle;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final loading = state.isGlobalSettingLoading(settingId);
    return _SettingsControlRow(
      title: title,
      subtitle: subtitle,
      state: state,
      settingId: settingId,
      chats: chats,
      contentPadding: contentPadding,
      trailing: ShadSwitch(
        value: value,
        onChanged: enabled && !loading ? onChanged : null,
      ),
    );
  }
}

_SettingsStatusKind? _settingsStatusKind(
  SettingsState state,
  GlobalSettingId settingId,
) {
  if (state.isGlobalSettingLoading(settingId)) {
    return null;
  }
  if (settingId.isDeviceOnly) {
    return _SettingsStatusKind.deviceOnly;
  }
  if (state.isGlobalSettingNotSynced(settingId)) {
    return _SettingsStatusKind.notSynced;
  }
  return null;
}

ChatSettingId? _chatOverrideSettingFor(GlobalSettingId settingId) {
  return switch (settingId) {
    GlobalSettingId.chatReadReceipts => ChatSettingId.readReceipts,
    GlobalSettingId.typingIndicators => ChatSettingId.typingIndicators,
    GlobalSettingId.emailImageAutoload => ChatSettingId.emailImageAutoload,
    GlobalSettingId.emailReadReceipts => ChatSettingId.emailReadReceipts,
    GlobalSettingId.emailSendConfirmation =>
      ChatSettingId.emailSendConfirmation,
    GlobalSettingId.emailComposerWatermark =>
      ChatSettingId.emailComposerWatermark,
    GlobalSettingId.shareSignature => ChatSettingId.shareSignature,
    GlobalSettingId.attachmentAutoDownloadImages ||
    GlobalSettingId.attachmentAutoDownloadVideos ||
    GlobalSettingId.attachmentAutoDownloadDocuments ||
    GlobalSettingId.attachmentAutoDownloadArchives =>
      ChatSettingId.attachmentAutoDownload,
    GlobalSettingId.notificationPreviews => ChatSettingId.notificationPreview,
    GlobalSettingId.chatNotificationsMuted ||
    GlobalSettingId.emailNotificationsMuted =>
      ChatSettingId.notificationBehavior,
    _ => null,
  };
}

List<Chat> _chatOverridesFor(ChatSettingId settingId, List<Chat> chats) {
  final overrides = chats
      .where((chat) {
        if (settingId == ChatSettingId.notificationBehavior) {
          return chat.effectiveNotificationBehavior != null;
        }
        return settingId.syncValueFrom(chat) != null;
      })
      .toList(growable: false);
  return overrides;
}

String _chatOverrideLabel(Chat chat) {
  final displayName = chat.displayName.trim();
  if (displayName.isNotEmpty) {
    return displayName;
  }
  return chat.jid;
}

class _DonationRequestBanner extends StatelessWidget {
  const _DonationRequestBanner({required this.settingsState});

  final SettingsState settingsState;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        if (!settingsState.showsDonationPrompt(
          accountJid: profileState.jid,
          storedConversationMessageCount:
              profileState.storedConversationMessageCount,
        )) {
          return const SizedBox.shrink();
        }
        final l10n = context.l10n;
        final spacing = context.spacing;
        final sizing = context.sizing;
        final colors = context.colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.m,
            spacing.m,
            spacing.m,
            spacing.s,
          ),
          child: AxiModalSurface(
            padding: EdgeInsets.all(spacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: FaIcon(
                    FontAwesomeIcons.solidHeart,
                    color: colors.destructive,
                    size: sizing.iconButtonSize,
                  ),
                ),
                SizedBox(height: spacing.m),
                Text(
                  l10n.profileDonationPromptMessage,
                  style: context.textTheme.muted,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.m),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: spacing.s,
                  runSpacing: spacing.s,
                  children: [
                    Link(
                      uri: Uri.parse(donateUrl),
                      builder: (_, followLink) => AxiButton.primary(
                        size: AxiButtonSize.lg,
                        onPressed: followLink,
                        child: Text(l10n.settingsDonateLabel),
                      ),
                    ),
                    AxiButton.outline(
                      size: AxiButtonSize.lg,
                      onPressed: () =>
                          context.read<SettingsCubit>().hideDonationPrompt(
                            accountJid: profileState.jid,
                            storedConversationMessageCount:
                                profileState.storedConversationMessageCount,
                          ),
                      child: Text(l10n.commonHide),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.label,
    required this.onPressed,
    this.leading,
    this.iconData,
    this.destructive = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final IconData? iconData;
  final bool destructive;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final Widget? resolvedLeading =
        leading ??
        (iconData == null
            ? null
            : Icon(iconData, size: sizing.menuItemIconSize));
    final button = destructive
        ? AxiListButton.destructiveGhost(
            leading: resolvedLeading,
            onPressed: onPressed,
            loading: loading,
            child: Text(label),
          )
        : AxiListButton(
            leading: resolvedLeading,
            onPressed: onPressed,
            loading: loading,
            child: Text(label),
          );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: button,
    );
  }
}

class _SettingsLinkButton extends StatelessWidget {
  const _SettingsLinkButton({
    required this.label,
    required this.link,
    this.iconData,
    this.faIconData,
  });

  final String label;
  final String link;
  final IconData? iconData;
  final FaIconData? faIconData;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    return Link(
      uri: Uri.parse(link),
      builder: (_, followLink) => _SettingsActionButton(
        label: label,
        leading: faIconData == null
            ? null
            : FaIcon(faIconData, size: sizing.menuItemIconSize),
        iconData: iconData,
        onPressed: followLink,
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({
    required this.label,
    this.showDivider = true,
    required this.dividerIndent,
    required this.padding,
  });

  final String label;
  final bool showDivider;
  final double dividerIndent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final header = Padding(
      padding: padding,
      child: Text(label.toUpperCase(), style: context.textTheme.sectionLabelM),
    );
    if (!showDivider) {
      return header;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: spacing.m),
        ShadSeparator.horizontal(
          color: context.borderSide.color,
          thickness: context.borderSide.width,
          margin: EdgeInsetsDirectional.only(
            start: dividerIndent,
            end: dividerIndent,
          ),
        ),
        header,
      ],
    );
  }
}

class _MessageTextSizeOptionLabel extends StatelessWidget {
  const _MessageTextSizeOptionLabel({required this.value});

  final MessageTextSize value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value.label(context.l10n),
      style: context.textTheme.small.copyWith(
        fontSize: value.fontSize,
        height: 1.0,
      ),
    );
  }
}

extension ThemeModeLocalization on ThemeMode {
  String label(AppLocalizations l10n) {
    switch (this) {
      case ThemeMode.system:
        return l10n.settingsThemeModeSystem;
      case ThemeMode.light:
        return l10n.settingsThemeModeLight;
      case ThemeMode.dark:
        return l10n.settingsThemeModeDark;
    }
  }
}

extension MessageTextSizeLocalization on MessageTextSize {
  String label(AppLocalizations l10n) =>
      l10n.settingsMessageTextSizeOption(pixels);
}

extension ProfileExportKindLabels on ProfileExportKind {
  String label(AppLocalizations l10n) => switch (this) {
    ProfileExportKind.xmppMessages => l10n.profileExportXmppMessagesLabel,
    ProfileExportKind.xmppContacts => l10n.profileExportXmppContactsLabel,
    ProfileExportKind.emailMessages => l10n.profileExportEmailMessagesLabel,
    ProfileExportKind.emailContacts => l10n.profileExportEmailContactsLabel,
  };
}
