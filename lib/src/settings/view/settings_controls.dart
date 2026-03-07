// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/legal_urls.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/bloc/email_contact_import_cubit.dart';
import 'package:axichat/src/email/view/email_contact_import_tile.dart';
import 'package:axichat/src/email/view/email_forwarding_guide.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/localization/view/language_selector.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/bloc/profile_export_cubit.dart';
import 'package:axichat/src/profile/utils/contact_exporter.dart';
import 'package:axichat/src/profile/view/contact_export_sheet.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/link.dart';

class SettingsSectionAnchors {
  SettingsSectionAnchors({
    this.importantKey,
    this.accountKey,
    this.dataKey,
    this.appearanceKey,
    this.securityKey,
    this.chatPreferencesKey,
    this.emailPreferencesKey,
    this.aboutKey,
  });

  final GlobalKey? importantKey;
  final GlobalKey? accountKey;
  final GlobalKey? dataKey;
  final GlobalKey? appearanceKey;
  final GlobalKey? securityKey;
  final GlobalKey? chatPreferencesKey;
  final GlobalKey? emailPreferencesKey;
  final GlobalKey? aboutKey;
}

class SettingsControls extends StatelessWidget {
  const SettingsControls({
    super.key,
    this.showDivider = false,
    this.fullWidthDividers = false,
    this.anchors,
    required this.locate,
    required this.onChangePassword,
    required this.onDeleteAccount,
    required this.applicationVersion,
  });

  final bool showDivider;
  final bool fullWidthDividers;
  final SettingsSectionAnchors? anchors;
  final T Function<T>() locate;
  final VoidCallback onChangePassword;
  final VoidCallback onDeleteAccount;
  final String? applicationVersion;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
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
        final exportBusy = context.select<ProfileExportCubit, bool>(
          (cubit) => cubit.state.isBusy,
        );
        final canForegroundService = context.select<SettingsCubit, bool>(
          (cubit) => cubit.canForegroundService,
        );
        final emailEnabled = context
            .watch<SettingsCubit>()
            .state
            .endpointConfig
            .smtpEnabled;
        final double dividerIndent = fullWidthDividers
            ? 0.0
            : sectionHeaderPadding.horizontal;
        return ValueListenableBuilder<bool>(
          valueListenable: foregroundServiceActive,
          builder: (context, foregroundActive, child) {
            final showImportantSection =
                canForegroundService && !foregroundActive;
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
                      ? () async =>
                            await showEmailForwardingGuideDialog(context)
                      : null,
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
                  onPressed: () => context.push(
                    const ArchivesRoute().location,
                    extra: locate,
                  ),
                ),
                _SettingsActionButton(
                  iconData: LucideIcons.userRoundPlus,
                  label: context.l10n.emailContactsImportTitle,
                  onPressed: emailEnabled
                      ? () async => await _showEmailContactImportDialog(context)
                      : null,
                ),
                _SettingsActionButton(
                  iconData: LucideIcons.messagesSquare,
                  label: context.l10n.profileExportActionLabel(
                    ProfileExportKind.xmppMessages.label(context.l10n),
                  ),
                  onPressed: exportBusy
                      ? null
                      : () async => await _handleXmppMessageExport(context),
                ),
                _SettingsActionButton(
                  iconData: LucideIcons.users,
                  label: context.l10n.profileExportActionLabel(
                    ProfileExportKind.xmppContacts.label(context.l10n),
                  ),
                  onPressed: exportBusy
                      ? null
                      : () async => await _handleXmppContactsExport(context),
                ),
                _SettingsActionButton(
                  iconData: LucideIcons.mail,
                  label: context.l10n.profileExportActionLabel(
                    ProfileExportKind.emailMessages.label(context.l10n),
                  ),
                  onPressed: exportBusy || !emailEnabled
                      ? null
                      : () async => await _handleEmailMessageExport(context),
                ),
                _SettingsActionButton(
                  iconData: LucideIcons.userRound,
                  label: context.l10n.profileExportActionLabel(
                    ProfileExportKind.emailContacts.label(context.l10n),
                  ),
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
                ListItemPadding(
                  child: AxiListTile(
                    title: context.l10n.settingsLanguage,
                    actions: const [LanguageSelector()],
                    minTileHeight: sizing.listButtonHeight,
                    contentPadding: compactTilePadding,
                  ),
                ),
                ListItemPadding(
                  child: AxiListTile(
                    title: context.l10n.settingsThemeMode,
                    actions: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: sizing.menuMaxWidth,
                        ),
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
                                    style: context.textTheme.small,
                                  ),
                                ),
                              )
                              .toList(),
                          selectedOptionBuilder: (BuildContext context, mode) =>
                              Text(
                                mode.label(context.l10n),
                                style: context.textTheme.small,
                              ),
                        ),
                      ),
                    ],
                    minTileHeight: sizing.listButtonHeight,
                    contentPadding: compactTilePadding,
                  ),
                ),
                ListItemPadding(
                  child: AxiListTile(
                    title: context.l10n.settingsColorScheme,
                    actions: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: sizing.menuMaxWidth,
                        ),
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
                                    style: context.textTheme.small,
                                  ),
                                ),
                              )
                              .toList(),
                          selectedOptionBuilder:
                              (BuildContext context, ShadColor value) => Text(
                                value.name,
                                style: context.textTheme.small,
                              ),
                        ),
                      ),
                    ],
                    minTileHeight: sizing.listButtonHeight,
                    contentPadding: compactTilePadding,
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsColorfulAvatars),
                    sublabel: Text(
                      context.l10n.settingsColorfulAvatarsDescription,
                    ),
                    value: state.colorfulAvatars,
                    onChanged: (colorfulAvatars) => context
                        .read<SettingsCubit>()
                        .toggleColorfulAvatars(colorfulAvatars),
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsLowMotion),
                    sublabel: Text(context.l10n.settingsLowMotionDescription),
                    value: state.lowMotion,
                    onChanged: (lowMotion) => context
                        .read<SettingsCubit>()
                        .toggleLowMotion(lowMotion),
                  ),
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
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsNotificationPreviews),
                    sublabel: Text(
                      context.l10n.settingsNotificationPreviewsDescription,
                    ),
                    value: state.notificationPreviewsEnabled,
                    onChanged: (enabled) => context
                        .read<SettingsCubit>()
                        .toggleNotificationPreviews(enabled),
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsAutoLoadEmailImages),
                    sublabel: Text(
                      context.l10n.settingsAutoLoadEmailImagesDescription,
                    ),
                    value: state.autoLoadEmailImages,
                    onChanged: emailEnabled
                        ? (enabled) => context
                              .read<SettingsCubit>()
                              .toggleAutoLoadEmailImages(enabled)
                        : null,
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsAutoDownloadImages),
                    sublabel: Text(
                      context.l10n.settingsAutoDownloadImagesDescription,
                    ),
                    value: state.autoDownloadImages,
                    onChanged: (enabled) => context
                        .read<SettingsCubit>()
                        .setAttachmentAutoDownloadSettings(
                          imagesEnabled: enabled,
                          videosEnabled: state.autoDownloadVideos,
                          documentsEnabled: state.autoDownloadDocuments,
                          archivesEnabled: state.autoDownloadArchives,
                        ),
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsAutoDownloadVideos),
                    sublabel: Text(
                      context.l10n.settingsAutoDownloadVideosDescription,
                    ),
                    value: state.autoDownloadVideos,
                    onChanged: (enabled) => context
                        .read<SettingsCubit>()
                        .setAttachmentAutoDownloadSettings(
                          imagesEnabled: state.autoDownloadImages,
                          videosEnabled: enabled,
                          documentsEnabled: state.autoDownloadDocuments,
                          archivesEnabled: state.autoDownloadArchives,
                        ),
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsAutoDownloadDocuments),
                    sublabel: Text(
                      context.l10n.settingsAutoDownloadDocumentsDescription,
                    ),
                    value: state.autoDownloadDocuments,
                    onChanged: (enabled) => context
                        .read<SettingsCubit>()
                        .setAttachmentAutoDownloadSettings(
                          imagesEnabled: state.autoDownloadImages,
                          videosEnabled: state.autoDownloadVideos,
                          documentsEnabled: enabled,
                          archivesEnabled: state.autoDownloadArchives,
                        ),
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsAutoDownloadArchives),
                    sublabel: Text(
                      context.l10n.settingsAutoDownloadArchivesDescription,
                    ),
                    value: state.autoDownloadArchives,
                    onChanged: (enabled) => context
                        .read<SettingsCubit>()
                        .setAttachmentAutoDownloadSettings(
                          imagesEnabled: state.autoDownloadImages,
                          videosEnabled: state.autoDownloadVideos,
                          documentsEnabled: state.autoDownloadDocuments,
                          archivesEnabled: enabled,
                        ),
                  ),
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
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsMuteNotifications),
                    sublabel: Text(
                      context.l10n.settingsMuteNotificationsDescription,
                    ),
                    value: state.chatNotificationsMuted,
                    onChanged: (muted) => context
                        .read<SettingsCubit>()
                        .toggleChatNotificationsMuted(muted),
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsChatReadReceipts),
                    value: state.chatReadReceipts,
                    onChanged: (enabled) => context
                        .read<SettingsCubit>()
                        .toggleChatReadReceipts(enabled),
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsTypingIndicators),
                    sublabel: Text(
                      context.l10n.settingsTypingIndicatorsDescription,
                    ),
                    value: state.indicateTyping,
                    onChanged: (indicateTyping) => context
                        .read<SettingsCubit>()
                        .toggleIndicateTyping(indicateTyping),
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsChatSendOnEnter),
                    sublabel: Text(
                      context.l10n.settingsChatSendOnEnterDescription,
                    ),
                    value: state.chatSendOnEnter,
                    onChanged: (enabled) => context
                        .read<SettingsCubit>()
                        .toggleChatSendOnEnter(enabled),
                  ),
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
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsMuteNotifications),
                    sublabel: Text(
                      context.l10n.settingsMuteNotificationsDescription,
                    ),
                    value: state.emailNotificationsMuted,
                    onChanged: emailEnabled
                        ? (muted) => context
                              .read<SettingsCubit>()
                              .toggleEmailNotificationsMuted(muted)
                        : null,
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsEmailReadReceipts),
                    value: state.emailReadReceipts,
                    onChanged: emailEnabled
                        ? (enabled) => context
                              .read<SettingsCubit>()
                              .toggleEmailReadReceipts(enabled)
                        : null,
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsShareTokenFooter),
                    sublabel: Text(
                      context.l10n.settingsShareTokenFooterDescription,
                    ),
                    value: state.shareTokenSignatureEnabled,
                    onChanged: emailEnabled
                        ? (enabled) => context
                              .read<SettingsCubit>()
                              .toggleShareTokenSignature(enabled)
                        : null,
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsEmailComposerWatermark),
                    sublabel: Text(
                      context.l10n.settingsEmailComposerWatermarkDescription,
                    ),
                    value: state.emailComposerWatermarkEnabled,
                    onChanged: emailEnabled
                        ? (enabled) => context
                              .read<SettingsCubit>()
                              .toggleEmailComposerWatermark(enabled)
                        : null,
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsEmailSendOnEnter),
                    sublabel: Text(
                      context.l10n.settingsEmailSendOnEnterDescription,
                    ),
                    value: state.emailSendOnEnter,
                    onChanged: emailEnabled
                        ? (enabled) => context
                              .read<SettingsCubit>()
                              .toggleEmailSendOnEnter(enabled)
                        : null,
                  ),
                ),
                Padding(
                  padding: switchPadding,
                  child: ShadSwitch(
                    label: Text(context.l10n.settingsEmailSendConfirmation),
                    sublabel: Text(
                      context.l10n.settingsEmailSendConfirmationDescription,
                    ),
                    value: state.emailSendConfirmationEnabled,
                    onChanged: emailEnabled
                        ? (enabled) => context
                              .read<SettingsCubit>()
                              .toggleEmailSendConfirmation(enabled)
                        : null,
                  ),
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
                  iconData: FontAwesomeIcons.gitlab,
                ),
                _SettingsLinkButton(
                  label: context.l10n.settingsGithubLabel,
                  link: githubUrl,
                  iconData: FontAwesomeIcons.github,
                ),
                _SettingsLinkButton(
                  label: context.l10n.settingsMastodonLabel,
                  link: mastodonUrl,
                  iconData: FontAwesomeIcons.mastodon,
                ),
                _SettingsLinkButton(
                  label: context.l10n.settingsDonateLabel,
                  link: donateUrl,
                  iconData: FontAwesomeIcons.heart,
                ),
                SizedBox(height: spacing.xxl),
              ],
            );
          },
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
    final labels = EmailMessageLineLabels(
      subjectLabel: context.l10n.chatMessageSubjectLabel,
    );
    final result = await context.read<ProfileExportCubit>().exportEmailMessages(
      labels,
    );
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

class _DonationRequestBanner extends StatelessWidget {
  const _DonationRequestBanner({required this.settingsState});

  final SettingsState settingsState;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        if (!settingsState.showsDonationPrompt(
          profileState.storedConversationMessageCount,
        )) {
          return const SizedBox.shrink();
        }
        final l10n = context.l10n;
        final spacing = context.spacing;
        final sizing = context.sizing;
        final colors = context.colorScheme;
        final displayName = profileState.username.trim().isEmpty
            ? profileState.jid
            : profileState.username;
        return Padding(
          padding: EdgeInsets.fromLTRB(spacing.m, spacing.m, spacing.m, 0),
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
                  l10n.profileDonationPromptMessage(displayName),
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
    this.iconData,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? iconData;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final Widget? leading = iconData == null
        ? null
        : Icon(iconData, size: sizing.menuItemIconSize);
    final button = destructive
        ? AxiListButton.destructiveGhost(
            leading: leading,
            onPressed: onPressed,
            child: Text(label),
          )
        : AxiListButton(
            leading: leading,
            onPressed: onPressed,
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
    required this.dividerIndent,
    required this.padding,
  });

  final String label;
  final bool showDivider;
  final double dividerIndent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
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
