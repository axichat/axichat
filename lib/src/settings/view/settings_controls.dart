// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/legal_urls.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/view/email_contact_import_tile.dart';
import 'package:axichat/src/email/view/email_forwarding_guide.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/localization/view/language_selector.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/profile/bloc/profile_export_cubit.dart';
import 'package:axichat/src/profile/utils/contact_exporter.dart';
import 'package:axichat/src/profile/view/contact_export_sheet.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/link.dart';

const double _compactTileHeight = 52.0;
const EdgeInsets _compactTilePadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 6,
);
const EdgeInsets _settingsSectionHeaderPadding = EdgeInsets.symmetric(
  horizontal: 16.0,
  vertical: 6.0,
);
const String _aboutLegalese = 'Copyright (C) 2025 Axichat LLC\n\n'
    'This program is free software: you can redistribute it and/or modify '
    'it under the terms of the GNU Affero General Public License as '
    'published by the Free Software Foundation, either version 3 of the '
    'License, or (at your option) any later version.\n\n'
    'This program is distributed in the hope that it will be useful, '
    'but WITHOUT ANY WARRANTY; without even the implied warranty of '
    'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the '
    'GNU Affero General Public License for more details.\n\n'
    'You should have received a copy of the GNU Affero General Public License '
    'along with this program. If not, see <https://www.gnu.org/licenses/>.';

class SettingsSectionAnchors {
  SettingsSectionAnchors({
    this.accountKey,
    this.dataKey,
    this.appearanceKey,
    this.chatPreferencesKey,
    this.emailPreferencesKey,
    this.aboutKey,
  });

  final GlobalKey? accountKey;
  final GlobalKey? dataKey;
  final GlobalKey? appearanceKey;
  final GlobalKey? chatPreferencesKey;
  final GlobalKey? emailPreferencesKey;
  final GlobalKey? aboutKey;
}

class SettingsControls extends StatelessWidget {
  const SettingsControls({
    super.key,
    this.showDivider = false,
    this.anchors,
    required this.locate,
    required this.onChangePassword,
    required this.onDeleteAccount,
    required this.applicationVersion,
  });

  final bool showDivider;
  final SettingsSectionAnchors? anchors;
  final T Function<T>() locate;
  final VoidCallback onChangePassword;
  final VoidCallback onDeleteAccount;
  final String? applicationVersion;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final exportState = context.watch<ProfileExportCubit>().state;
        final selectTextStyle = context.textTheme.small.copyWith(
          color: context.colorScheme.foreground,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            anchors?.accountKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionAccount,
                    showDivider: showDivider,
                  )
                : KeyedSubtree(
                    key: anchors?.accountKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionAccount,
                      showDivider: showDivider,
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
            const EmailForwardingGuideActionButton(),
            const EmailContactImportActionButton(),
            _SettingsActionButton(
              iconData: LucideIcons.image,
              label: context.l10n.draftAttachmentsLabel,
              onPressed: () => context.push(
                const AttachmentGalleryRoute().location,
                extra: locate,
              ),
            ),
            if (context.read<Capability>().canForegroundService)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: NotificationRequest(
                  notificationService: context.read<NotificationService>(),
                  capability: context.read<Capability>(),
                ),
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
                  )
                : KeyedSubtree(
                    key: anchors?.dataKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionData,
                    ),
                  ),
            _SettingsActionButton(
              iconData: LucideIcons.archive,
              label: context.l10n.profileArchives,
              onPressed: () => context.push(
                const ArchivesRoute().location,
                extra: locate,
              ),
            ),
            _SettingsActionButton(
              iconData: LucideIcons.messagesSquare,
              label: context.l10n.profileExportActionLabel(
                ProfileExportKind.xmppMessages.label(context.l10n),
              ),
              onPressed: exportState.isBusy
                  ? null
                  : () async => await _handleXmppMessageExport(context),
            ),
            _SettingsActionButton(
              iconData: LucideIcons.users,
              label: context.l10n.profileExportActionLabel(
                ProfileExportKind.xmppContacts.label(context.l10n),
              ),
              onPressed: exportState.isBusy
                  ? null
                  : () async => await _handleXmppContactsExport(context),
            ),
            _SettingsActionButton(
              iconData: LucideIcons.mail,
              label: context.l10n.profileExportActionLabel(
                ProfileExportKind.emailMessages.label(context.l10n),
              ),
              onPressed: exportState.isBusy
                  ? null
                  : () async => await _handleEmailMessageExport(context),
            ),
            _SettingsActionButton(
              iconData: LucideIcons.userRound,
              label: context.l10n.profileExportActionLabel(
                ProfileExportKind.emailContacts.label(context.l10n),
              ),
              onPressed: exportState.isBusy
                  ? null
                  : () async => await _handleEmailContactsExport(context),
            ),
            anchors?.appearanceKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionAppearance,
                  )
                : KeyedSubtree(
                    key: anchors?.appearanceKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionAppearance,
                    ),
                  ),
            ListItemPadding(
              child: AxiListTile(
                title: context.l10n.settingsLanguage,
                actions: const [LanguageSelector()],
                minTileHeight: _compactTileHeight,
                contentPadding: _compactTilePadding,
              ),
            ),
            ListItemPadding(
              child: AxiListTile(
                title: context.l10n.settingsThemeMode,
                actions: [
                  SizedBox(
                    width: 180,
                    child: AxiSelect<ThemeMode>(
                      initialValue: state.themeMode,
                      onChanged: (themeMode) => context
                          .read<SettingsCubit>()
                          .updateThemeMode(themeMode),
                      options: ThemeMode.values
                          .map(
                            (themeMode) => ShadOption<ThemeMode>(
                              value: themeMode,
                              child: Text(
                                themeMode.label(context.l10n),
                                style: selectTextStyle,
                              ),
                            ),
                          )
                          .toList(),
                      selectedOptionBuilder: (BuildContext context, mode) =>
                          Text(
                        mode.label(context.l10n),
                        style: selectTextStyle,
                      ),
                    ),
                  ),
                ],
                minTileHeight: _compactTileHeight,
                contentPadding: _compactTilePadding,
              ),
            ),
            ListItemPadding(
              child: AxiListTile(
                title: context.l10n.settingsColorScheme,
                actions: [
                  SizedBox(
                    width: 180,
                    child: AxiSelect<ShadColor>(
                      initialValue: state.shadColor,
                      onChanged: (colorScheme) => context
                          .read<SettingsCubit>()
                          .updateColorScheme(colorScheme),
                      options: ShadColor.values
                          .map(
                            (colorScheme) => ShadOption<ShadColor>(
                              value: colorScheme,
                              child: Text(
                                colorScheme.name,
                                style: selectTextStyle,
                              ),
                            ),
                          )
                          .toList(),
                      selectedOptionBuilder:
                          (BuildContext context, ShadColor value) =>
                              Text(value.name, style: selectTextStyle),
                    ),
                  ),
                ],
                minTileHeight: _compactTileHeight,
                contentPadding: _compactTilePadding,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsColorfulAvatars),
                sublabel: Text(context.l10n.settingsColorfulAvatarsDescription),
                value: state.colorfulAvatars,
                onChanged: (colorfulAvatars) => context
                    .read<SettingsCubit>()
                    .toggleColorfulAvatars(colorfulAvatars),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsLowMotion),
                sublabel: Text(context.l10n.settingsLowMotionDescription),
                value: state.lowMotion,
                onChanged: (lowMotion) =>
                    context.read<SettingsCubit>().toggleLowMotion(lowMotion),
              ),
            ),
            anchors?.chatPreferencesKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionChats,
                  )
                : KeyedSubtree(
                    key: anchors?.chatPreferencesKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionChats,
                    ),
                  ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: MessageStorageTile(state: state),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsMuteNotifications),
                sublabel:
                    Text(context.l10n.settingsMuteNotificationsDescription),
                value: state.mute,
                onChanged: (mute) =>
                    context.read<SettingsCubit>().toggleMute(mute),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsNotificationPreviews),
                sublabel:
                    Text(context.l10n.settingsNotificationPreviewsDescription),
                value: state.notificationPreviewsEnabled,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleNotificationPreviews(enabled),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsChatReadReceipts),
                sublabel:
                    Text(context.l10n.settingsChatReadReceiptsDescription),
                value: state.chatReadReceipts,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleChatReadReceipts(enabled),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsTypingIndicators),
                sublabel:
                    Text(context.l10n.settingsTypingIndicatorsDescription),
                value: state.indicateTyping,
                onChanged: (indicateTyping) => context
                    .read<SettingsCubit>()
                    .toggleIndicateTyping(indicateTyping),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsAutoDownloadImages),
                sublabel:
                    Text(context.l10n.settingsAutoDownloadImagesDescription),
                value: state.autoDownloadImages,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleAutoDownloadImages(enabled),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsAutoDownloadVideos),
                sublabel:
                    Text(context.l10n.settingsAutoDownloadVideosDescription),
                value: state.autoDownloadVideos,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleAutoDownloadVideos(enabled),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsAutoDownloadDocuments),
                sublabel:
                    Text(context.l10n.settingsAutoDownloadDocumentsDescription),
                value: state.autoDownloadDocuments,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleAutoDownloadDocuments(enabled),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsAutoDownloadArchives),
                sublabel:
                    Text(context.l10n.settingsAutoDownloadArchivesDescription),
                value: state.autoDownloadArchives,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleAutoDownloadArchives(enabled),
              ),
            ),
            anchors?.emailPreferencesKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionEmail,
                  )
                : KeyedSubtree(
                    key: anchors?.emailPreferencesKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionEmail,
                    ),
                  ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsEmailReadReceipts),
                sublabel:
                    Text(context.l10n.settingsEmailReadReceiptsDescription),
                value: state.emailReadReceipts,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleEmailReadReceipts(enabled),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsShareTokenFooter),
                sublabel:
                    Text(context.l10n.settingsShareTokenFooterDescription),
                value: state.shareTokenSignatureEnabled,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleShareTokenSignature(enabled),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(context.l10n.settingsAutoLoadEmailImages),
                sublabel:
                    Text(context.l10n.settingsAutoLoadEmailImagesDescription),
                value: state.autoLoadEmailImages,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleAutoLoadEmailImages(enabled),
              ),
            ),
            anchors?.aboutKey == null
                ? _SettingsSectionHeader(
                    label: context.l10n.settingsSectionAbout,
                  )
                : KeyedSubtree(
                    key: anchors?.aboutKey,
                    child: _SettingsSectionHeader(
                      label: context.l10n.settingsSectionAbout,
                    ),
                  ),
            _SettingsActionButton(
              iconData: LucideIcons.info,
              label: context.l10n.settingsAboutAxichat,
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: appDisplayName,
                applicationVersion: applicationVersion,
                applicationLegalese: _aboutLegalese,
              ),
            ),
            _SettingsLinkButton(
              label: context.l10n.settingsTermsLabel,
              link: termsUrl,
              iconData: LucideIcons.fileText,
            ),
            _SettingsLinkButton(
              label: context.l10n.settingsPrivacyLabel,
              link: privacyUrl,
              iconData: LucideIcons.shieldCheck,
            ),
            _SettingsLinkButton(
              label: context.l10n.settingsLicenseAgpl,
              link: licenseUrl,
              iconData: LucideIcons.fileText,
            ),
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
    final result =
        await context.read<ProfileExportCubit>().exportXmppMessages();
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
    final result =
        await context.read<ProfileExportCubit>().exportEmailMessages();
    if (!context.mounted) {
      return;
    }
    await _handleExportResult(context, result);
  }

  Future<void> _handleXmppContactsExport(BuildContext context) async {
    final ContactExportFormat? format = await showContactExportFormatSheet(
      context,
    );
    if (!context.mounted || format == null) {
      return;
    }
    final result = await context.read<ProfileExportCubit>().exportXmppContacts(
          format,
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
    final result = await context.read<ProfileExportCubit>().exportEmailContacts(
          format,
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
          message: context.l10n.profileExportFailedMessage(label),
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
    String? savePath;
    try {
      savePath = await FilePicker.platform.saveFile(fileName: exportFileName);
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
    showToast?.call(
      FeedbackToast.success(
        message: context.l10n.profileExportReadyMessage(label),
      ),
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.label,
    required this.onPressed,
    this.iconData,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? iconData;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    const ghostBackgroundOpacity = 0.6;
    final backgroundColor =
        colors.secondary.withValues(alpha: ghostBackgroundOpacity);
    final foregroundColor =
        destructive ? colors.destructive : colors.foreground;
    final verticalInset = _compactTilePadding.vertical / 2;
    final iconSpacing = _compactTilePadding.horizontal / 2;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _compactTilePadding.horizontal,
        vertical: verticalInset,
      ),
      child: ClipRRect(
        borderRadius: context.radius,
        child: ColoredBox(
          color: backgroundColor,
          child: SizedBox(
            width: double.infinity,
            child: ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: onPressed,
              child: IconTheme.merge(
                data: IconThemeData(color: foregroundColor),
                child: DefaultTextStyle.merge(
                  style: context.textTheme.small.copyWith(
                    color: foregroundColor,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          if (iconData != null) Icon(iconData),
                          if (iconData != null)
                            SizedBox(width: iconSpacing),
                          Expanded(child: Text(label)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ).withTapBounce(enabled: onPressed != null),
          ),
        ),
      ),
    );
  }
}

class _SettingsLinkButton extends StatelessWidget {
  const _SettingsLinkButton({
    required this.label,
    required this.link,
    this.iconData,
  });

  final String label;
  final String link;
  final IconData? iconData;

  @override
  Widget build(BuildContext context) {
    return Link(
      uri: Uri.parse(link),
      builder: (_, followLink) => _SettingsActionButton(
        label: label,
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
  });

  final String label;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: _settingsSectionHeaderPadding,
      child: Text(label, style: context.textTheme.muted),
    );
    if (!showDivider) {
      return header;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [const AxiListDivider(), header],
    );
  }
}

class MessageStorageTile extends StatelessWidget {
  const MessageStorageTile({super.key, required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final selectTextStyle = context.textTheme.small.copyWith(
      color: colors.foreground,
    );
    return AnimatedContainer(
      duration: baseAnimationDuration,
      decoration: ShapeDecoration(
        color: colors.card,
        shape: SquircleBorder(
          cornerRadius: 18,
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    l10n.settingsMessageStorageTitle,
                    style: context.textTheme.small.copyWith(
                      color: colors.foreground,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StreamBuilder<bool>(
                  stream: context.read<XmppService>().mamSupportStream,
                  initialData: context.read<XmppService>().mamSupported,
                  builder: (context, snapshot) {
                    final mamSupported = snapshot.data ?? false;
                    final options = mamSupported
                        ? MessageStorageMode.values
                        : const [MessageStorageMode.local];
                    final effectiveMode = mamSupported
                        ? state.messageStorageMode
                        : MessageStorageMode.local;
                    return AxiSelect<MessageStorageMode>(
                      initialValue: effectiveMode,
                      onChanged: (mode) {
                        if (mode == null) return;
                        if (mode.isServerOnly && !mamSupported) return;
                        context.read<SettingsCubit>().updateMessageStorageMode(
                              mode,
                            );
                      },
                      options: options
                          .map(
                            (mode) => ShadOption<MessageStorageMode>(
                              value: mode,
                              child: Text(
                                mode.isLocal
                                    ? l10n.settingsMessageStorageLocal
                                    : l10n.settingsMessageStorageServerOnly,
                                style: selectTextStyle,
                              ),
                            ),
                          )
                          .toList(),
                      selectedOptionBuilder: (context, mode) => Text(
                        mode.isLocal
                            ? l10n.settingsMessageStorageLocal
                            : l10n.settingsMessageStorageServerOnly,
                        style: selectTextStyle,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsMessageStorageSubtitle,
              style: context.textTheme.muted.copyWith(
                color: colors.mutedForeground,
                height: 1.2,
              ),
            ),
          ],
        ),
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

extension ProfileExportKindLabels on ProfileExportKind {
  String label(AppLocalizations l10n) => switch (this) {
        ProfileExportKind.xmppMessages => l10n.profileExportXmppMessagesLabel,
        ProfileExportKind.xmppContacts => l10n.profileExportXmppContactsLabel,
        ProfileExportKind.emailMessages => l10n.profileExportEmailMessagesLabel,
        ProfileExportKind.emailContacts => l10n.profileExportEmailContactsLabel,
      };
}
