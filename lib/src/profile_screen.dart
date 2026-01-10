// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/authentication/bloc/authentication_cubit.dart';
import 'package:axichat/src/authentication/view/change_password_form.dart';
import 'package:axichat/src/authentication/view/unregister_form.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/legal_urls.dart';
import 'package:axichat/src/common/shorebird_push.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/connectivity/bloc/connectivity_cubit.dart';
import 'package:axichat/src/connectivity/view/connectivity_indicator.dart';
import 'package:axichat/src/email/bloc/email_contact_import_cubit.dart';
import 'package:axichat/src/email/bloc/email_sync_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/profile/bloc/profile_export_cubit.dart';
import 'package:axichat/src/profile/view/contact_export_sheet.dart';
import 'package:axichat/src/profile/view/profile_fingerprint.dart';
import 'package:axichat/src/profile/view/session_capability_indicators.dart';
import 'package:axichat/src/profile/utils/contact_exporter.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/settings/view/settings_controls.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/link.dart';

import 'authentication/view/logout_button.dart';

enum _ProfileRoute {
  main,
  changePassword,
  delete,
}

const double _profileActionSpacing = 8.0;
const double _profileHeaderSpacing = 12.0;
const double _profileHeaderTextSpacing = 4.0;
const double _profileHeaderWrapSpacing = 2.0;
const double _profileCardSectionSpacing = 10.0;
const double _profileStatusFieldPadding = 8.0;
const double _profileIndicatorSpacing = 8.0;
const double _profileWideHeaderSpacing = 12.0;
const double _profileWideHorizontalPadding = 32.0;
const double _profileWideColumnSpacing = 16.0;
const double _profileColumnMinWidth = 340.0;
const double _profileColumnMaxWidth = 460.0;
const double _profileSettingsMinWidth = 300.0;
const double _profileWideLayoutMinWidth = _profileColumnMinWidth +
    _profileSettingsMinWidth +
    _profileWideColumnSpacing +
    _profileWideHorizontalPadding * 2;
const double _profileLegalSeparatorSpacing = 6.0;
const Curve _profileFadeCurve = Curves.easeInOutCubic;
const String _profileMadeByPrefix = 'Made by ';
const String _profileMadeBySuffix = ' LLC';
const String _profileBrandLabel = 'Axichat';
const String _profileAgplLabel = 'AGPLv3';
const String _profileLegalSeparatorText = '•';
const double _profileSettingsCompactTileHeight = 52.0;
const EdgeInsets _profileSettingsCompactTilePadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 6,
);
const String _aboutLegalese = 'Copyright (C) 2025 Axichat LLC (Eliot Lew)\n\n'
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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: locate<Capability>(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: locate<ProfileCubit>(),
          ),
          BlocProvider.value(
            value: locate<ConnectivityCubit>(),
          ),
          BlocProvider.value(
            value: locate<EmailSyncCubit>(),
          ),
          BlocProvider(
            create: (context) => EmailContactImportCubit(
              emailService: locate<EmailService>(),
            ),
          ),
          BlocProvider.value(
            value: locate<SettingsCubit>(),
          ),
          BlocProvider.value(
            value: locate<AuthenticationCubit>(),
          ),
          BlocProvider(
            create: (context) => ProfileExportCubit(
              xmppService: locate<XmppService>(),
              emailService: locate<EmailService>(),
            ),
          ),
        ],
        child: _ProfileBody(locate: locate),
      ),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.locate});

  final T Function<T>() locate;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  String? _applicationVersion;

  var _profileRoute = _ProfileRoute.main;

  @override
  void initState() {
    super.initState();
    _getApplicationVersion();
  }

  Future<void> _getApplicationVersion() async {
    final result = (await PackageInfo.fromPlatform()).version;
    setState(() {
      _applicationVersion = result;
    });
  }

  ConnectionState _xmppStateFor(
    ConnectivityState state, {
    required bool demoOffline,
  }) {
    if (demoOffline) return ConnectionState.connected;
    return switch (state) {
      ConnectivityConnected() => ConnectionState.connected,
      ConnectivityConnecting() => ConnectionState.connecting,
      ConnectivityError() => ConnectionState.error,
      ConnectivityNotConnected() => ConnectionState.notConnected,
    };
  }

  void _setRoute(_ProfileRoute route) {
    setState(() {
      _profileRoute = route;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final demoOffline =
            context.read<XmppService?>()?.demoOfflineMode ?? false;
        final ConnectionState connectionState =
            _xmppStateFor(state, demoOffline: demoOffline);
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.profileTitle),
            backgroundColor: context.colorScheme.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leadingWidth: AxiIconButton.kDefaultSize + 24,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: AxiIconButton.kDefaultSize,
                  height: AxiIconButton.kDefaultSize,
                  child: AxiIconButton.ghost(
                    iconData: LucideIcons.arrowLeft,
                    tooltip: l10n.commonBack,
                    onPressed: () => _profileRoute == _ProfileRoute.main
                        ? context.pop()
                        : _setRoute(_ProfileRoute.main),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: context.colorScheme.border,
              ),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWideLayout =
                    constraints.maxWidth >= _profileWideLayoutMinWidth;
                final Duration animationDuration =
                    context.watch<SettingsCubit>().animationDuration;
                return AxiFadeIndexedStack(
                  index: _profileRoute.index,
                  duration: animationDuration,
                  curve: _profileFadeCurve,
                  children: [
                    _ProfileMainView(
                      isWideLayout: isWideLayout,
                      connectionState: connectionState,
                      demoOffline: demoOffline,
                      applicationVersion: _applicationVersion,
                      locate: widget.locate,
                      onNavigate: _setRoute,
                    ),
                    const _ProfileFormPage(child: ChangePasswordForm()),
                    const _ProfileFormPage(child: UnregisterForm()),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ProfileMainView extends StatelessWidget {
  const _ProfileMainView({
    required this.isWideLayout,
    required this.connectionState,
    required this.demoOffline,
    required this.applicationVersion,
    required this.locate,
    required this.onNavigate,
  });

  final bool isWideLayout;
  final ConnectionState connectionState;
  final bool demoOffline;
  final String? applicationVersion;
  final T Function<T>() locate;
  final ValueChanged<_ProfileRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    final card = _ProfileCardSection(
      connectionState: connectionState,
      demoOffline: demoOffline,
      isWideLayout: isWideLayout,
      locate: locate,
      onNavigate: onNavigate,
    );
    final settings = _SettingsPanel(
      showTopDivider: !isWideLayout,
      applicationVersion: applicationVersion,
    );
    if (!isWideLayout) {
      return SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _ProfileStatusHeader(),
                card,
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: ProfileFingerprint(),
                ),
                const SizedBox(height: 8),
                settings,
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(
        left: _profileWideHorizontalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ProfileStatusHeader(),
          const SizedBox(height: _profileWideHeaderSpacing),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _profileColumnMaxWidth,
                    minWidth: _profileColumnMinWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      card,
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: ProfileFingerprint(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _profileWideColumnSpacing),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      right: _profileWideHorizontalPadding,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: _profileSettingsMinWidth,
                      ),
                      child: settings,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCardSection extends StatelessWidget {
  const _ProfileCardSection({
    required this.connectionState,
    required this.demoOffline,
    required this.isWideLayout,
    required this.locate,
    required this.onNavigate,
  });

  final ConnectionState connectionState;
  final bool demoOffline;
  final bool isWideLayout;
  final T Function<T>() locate;
  final ValueChanged<_ProfileRoute> onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, profileState) {
          final exportState = context.watch<ProfileExportCubit>().state;
          final exportEnabled = !exportState.isBusy;
          final usernameStyle = context.textTheme.large.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colorScheme.foreground,
          );
          final subtitleStyle = context.textTheme.muted.copyWith(
            color: context.colorScheme.mutedForeground,
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final bool wideCard =
                  isWideLayout && constraints.maxWidth >= 360.0;
              final double statusFieldMaxWidth = wideCard ? 420.0 : 320.0;
              final actions = <AxiMenuAction>[
                AxiMenuAction(
                  label: l10n.profileEditAvatar,
                  icon: LucideIcons.user,
                  onPressed: () => context.push(
                    const AvatarEditorRoute().location,
                    extra: locate,
                  ),
                ),
                AxiMenuAction(
                  label: l10n.profileArchives,
                  icon: LucideIcons.archive,
                  onPressed: () => context.push(
                    const ArchivesRoute().location,
                    extra: locate,
                  ),
                ),
                AxiMenuAction(
                  label: l10n.profileExportActionLabel(
                    ProfileExportKind.xmppMessages.label(l10n),
                  ),
                  icon: LucideIcons.messagesSquare,
                  enabled: exportEnabled,
                  onPressed: exportEnabled
                      ? () => unawaited(_handleXmppMessageExport(context))
                      : null,
                ),
                AxiMenuAction(
                  label: l10n.profileExportActionLabel(
                    ProfileExportKind.xmppContacts.label(l10n),
                  ),
                  icon: LucideIcons.users,
                  enabled: exportEnabled,
                  onPressed: exportEnabled
                      ? () => unawaited(_handleXmppContactsExport(context))
                      : null,
                ),
                AxiMenuAction(
                  label: l10n.profileExportActionLabel(
                    ProfileExportKind.emailMessages.label(l10n),
                  ),
                  icon: LucideIcons.mail,
                  enabled: exportEnabled,
                  onPressed: exportEnabled
                      ? () => unawaited(_handleEmailMessageExport(context))
                      : null,
                ),
                AxiMenuAction(
                  label: l10n.profileExportActionLabel(
                    ProfileExportKind.emailContacts.label(l10n),
                  ),
                  icon: LucideIcons.userRound,
                  enabled: exportEnabled,
                  onPressed: exportEnabled
                      ? () => unawaited(_handleEmailContactsExport(context))
                      : null,
                ),
                AxiMenuAction(
                  label: l10n.profileChangePassword,
                  icon: LucideIcons.keyRound,
                  onPressed: () => onNavigate(_ProfileRoute.changePassword),
                ),
                AxiMenuAction(
                  label: l10n.profileDeleteAccount,
                  icon: LucideIcons.trash2,
                  destructive: true,
                  onPressed: () => onNavigate(_ProfileRoute.delete),
                ),
              ];
              final actionButtons = Wrap(
                alignment: WrapAlignment.center,
                spacing: _profileActionSpacing,
                runSpacing: _profileActionSpacing,
                children: [
                  const LogoutButton(),
                  AxiMore(actions: actions),
                ],
              );
              final header = Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: statusFieldMaxWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _EditableAvatarButton(
                        avatarPath: profileState.avatarPath,
                        jid: profileState.jid,
                        status: profileState.status,
                        onTap: () => context.push(
                          const AvatarEditorRoute().location,
                          extra: locate,
                        ),
                      ),
                      const SizedBox(width: _profileHeaderSpacing),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'title',
                              child: Material(
                                color: Colors.transparent,
                                child: Text(
                                  profileState.username,
                                  style: usernameStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(height: _profileHeaderTextSpacing),
                            SelectionArea(
                              child: Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 0,
                                runSpacing: _profileHeaderWrapSpacing,
                                children: [
                                  AxiTooltip(
                                    builder: (_) => ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 300.0,
                                      ),
                                      child: Text(
                                        l10n.profileJidDescription,
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                    child: Hero(
                                      tag: 'subtitle',
                                      child: Material(
                                        color: Colors.transparent,
                                        child: Text(
                                          profileState.jid,
                                          style: subtitleStyle,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (profileState.resource.isNotEmpty)
                                    AxiTooltip(
                                      builder: (_) => ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 300.0,
                                        ),
                                        child: Text(
                                          l10n.profileResourceDescription,
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                      child: Text(
                                        '/${profileState.resource}',
                                        style: subtitleStyle,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
              final Widget profileCard = ShadCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: _profileCardSectionSpacing,
                  children: [
                    header,
                    Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: statusFieldMaxWidth),
                        child: Padding(
                          padding: const EdgeInsets.all(
                            _profileStatusFieldPadding,
                          ),
                          child: AxiTextFormField(
                            placeholder: Text(l10n.profileStatusPlaceholder),
                            initialValue: profileState.status,
                            onSubmitted: (value) => context
                                .read<ProfileCubit?>()
                                ?.updatePresence(status: value),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: BlocBuilder<EmailSyncCubit, EmailSyncState>(
                        builder: (context, emailSyncState) {
                          final displayedEmailState = demoOffline
                              ? const EmailSyncState.ready()
                              : emailSyncState;
                          return SessionCapabilityIndicators(
                            xmppState: connectionState,
                            emailState: displayedEmailState,
                            emailEnabled: true,
                            compact: !wideCard,
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: actionButtons,
                    ),
                  ],
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: _profileCardSectionSpacing,
                children: [
                  profileCard,
                  const _ProfileLegalLinks(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleXmppMessageExport(BuildContext context) async {
    final bool confirmed = await _confirmMessageExport(context);
    if (!context.mounted || !confirmed) {
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
    final bool confirmed = await _confirmMessageExport(context);
    if (!context.mounted || !confirmed) {
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
    final result =
        await context.read<ProfileExportCubit>().exportXmppContacts(format);
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
    final result =
        await context.read<ProfileExportCubit>().exportEmailContacts(format);
    if (!context.mounted) {
      return;
    }
    await _handleExportResult(context, result);
  }

  Future<bool> _confirmMessageExport(BuildContext context) async {
    final l10n = context.l10n;
    final bool? confirmed = await confirm(
      context,
      title: l10n.chatExportWarningTitle,
      message: l10n.chatExportWarningMessage,
      confirmLabel: l10n.commonContinue,
      cancelLabel: l10n.commonCancel,
      destructiveConfirm: false,
    );
    return confirmed == true;
  }

  Future<void> _handleExportResult(
    BuildContext context,
    ProfileExportResult result,
  ) async {
    final showToast = ShadToaster.maybeOf(context)?.show;
    final l10n = context.l10n;
    final label = result.kind.label(l10n);
    if (result.outcome.isEmpty) {
      showToast?.call(
        FeedbackToast.info(
          message: l10n.profileExportEmptyMessage(label),
        ),
      );
      return;
    }
    if (result.outcome.isFailure || result.file == null) {
      showToast?.call(
        FeedbackToast.error(
          message: l10n.profileExportFailedMessage(label),
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
          message: l10n.profileExportFailedMessage(label),
        ),
      );
      return;
    }
    String? savePath;
    try {
      savePath = await FilePicker.platform.saveFile(
        fileName: exportFileName,
      );
    } on Exception {
      if (!context.mounted) {
        return;
      }
      showToast?.call(
        FeedbackToast.error(
          message: l10n.profileExportFailedMessage(label),
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
          message: l10n.profileExportFailedMessage(label),
        ),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    showToast?.call(
      FeedbackToast.success(
        message: l10n.profileExportReadyMessage(label),
      ),
    );
  }
}

class _ProfileStatusHeader extends StatelessWidget {
  const _ProfileStatusHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConnectivityIndicator(),
        SizedBox(height: _profileIndicatorSpacing),
        ShorebirdChecker(),
      ],
    );
  }
}

class _ProfileLegalLinks extends StatelessWidget {
  const _ProfileLegalLinks();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    final termsLabel = l10n.termsAgreementTerms.toUpperCase();
    final privacyLabel = l10n.termsAgreementPrivacy.toUpperCase();
    final Widget termsLink = _ProfileMutedLink(
      link: termsUrl,
      text: termsLabel,
      textStyle: textStyle,
    );
    final Widget privacyLink = _ProfileMutedLink(
      link: privacyUrl,
      text: privacyLabel,
      textStyle: textStyle,
    );
    final Widget agplLink = _ProfileMutedLink(
      link: licenseUrl,
      text: _profileAgplLabel,
      textStyle: textStyle,
    );
    final Widget separator = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _profileLegalSeparatorSpacing,
      ),
      child: Text(
        _profileLegalSeparatorText,
        style: textStyle,
      ),
    );
    final Widget trailingSeparator = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _profileLegalSeparatorSpacing,
      ),
      child: Text(
        _profileLegalSeparatorText,
        style: textStyle,
      ),
    );
    final Widget madeBy = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: _profileHeaderWrapSpacing,
      children: [
        Text(
          _profileMadeByPrefix,
          style: textStyle,
        ),
        _ProfileMutedLink(
          link: axichatHomeUrl,
          text: _profileBrandLabel,
          textStyle: textStyle,
        ),
        Text(
          _profileMadeBySuffix,
          style: textStyle,
        ),
      ],
    );
    return Align(
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: _profileHeaderTextSpacing,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: _profileHeaderWrapSpacing,
            children: [
              termsLink,
              separator,
              privacyLink,
              trailingSeparator,
              agplLink,
            ],
          ),
          madeBy,
        ],
      ),
    );
  }
}

class _ProfileMutedLink extends StatelessWidget {
  const _ProfileMutedLink({
    required this.text,
    required this.link,
    required this.textStyle,
  });

  final String text;
  final String link;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Link(
      uri: Uri.parse(link),
      builder: (_, followLink) => ShadGestureDetector(
        cursor: SystemMouseCursors.click,
        hoverStrategies: mobileHoverStrategies,
        onTap: followLink,
        child: Text(
          text,
          style: textStyle,
        ),
      ),
    );
  }
}

class _EditableAvatarButton extends StatefulWidget {
  const _EditableAvatarButton({
    required this.avatarPath,
    required this.jid,
    required this.status,
    required this.onTap,
  });

  final String? avatarPath;
  final String jid;
  final String? status;
  final VoidCallback onTap;

  @override
  State<_EditableAvatarButton> createState() => _EditableAvatarButtonState();
}

class _EditableAvatarButtonState extends State<_EditableAvatarButton> {
  bool _hovered = false;
  static const _size = 74.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final overlayVisible = _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hovered = true),
        onTapUp: (_) => setState(() => _hovered = false),
        onTapCancel: () => setState(() => _hovered = false),
        onTap: widget.onTap,
        child: Hero(
          tag: 'avatar',
          child: Stack(
            alignment: Alignment.center,
            children: [
              AxiAvatar(
                jid: widget.jid,
                subscription: Subscription.both,
                presence: null,
                status: widget.status,
                active: false,
                size: _size,
                avatarPath: widget.avatarPath,
              ),
              AnimatedOpacity(
                opacity: overlayVisible ? 0.9 : 0.0,
                duration: baseAnimationDuration,
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: colors.background.withAlpha((0.4 * 255).round()),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(
                    LucideIcons.pencil,
                    color: colors.foreground,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.showTopDivider,
    required this.applicationVersion,
  });

  final bool showTopDivider;
  final String? applicationVersion;

  @override
  Widget build(BuildContext context) {
    final aboutLabel =
        MaterialLocalizations.of(context).aboutListTileTitle(appDisplayName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsControls(
          showDivider: showTopDivider,
        ),
        ListItemPadding(
          child: AxiListTile(
            leading: const Icon(LucideIcons.info),
            title: aboutLabel,
            onTap: () => showAboutDialog(
              context: context,
              applicationName: appDisplayName,
              applicationVersion: applicationVersion,
              applicationLegalese: _aboutLegalese,
            ),
            minTileHeight: _profileSettingsCompactTileHeight,
            contentPadding: _profileSettingsCompactTilePadding,
          ),
        ),
      ],
    );
  }
}

class _ProfileFormPage extends StatelessWidget {
  const _ProfileFormPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720.0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );
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
