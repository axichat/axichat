import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/localization/view/language_selector.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/notifications/view/notification_request.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SettingsControls extends StatelessWidget {
  const SettingsControls({
    super.key,
    this.showDivider = false,
    this.showAppearanceDivider = true,
  });

  final bool showDivider;
  final bool showAppearanceDivider;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const double compactTileHeight = 52;
    const EdgeInsets compactTilePadding = EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 6,
    );
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (context.read<Capability>().canForegroundService) ...[
              if (showDivider) ...[
                const AxiListDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 6.0,
                  ),
                  child: Text(
                    l10n.settingsSectionImportant,
                    style: context.textTheme.muted,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: NotificationRequest(
                  notificationService: context.read<NotificationService>(),
                  capability: context.read<Capability>(),
                ),
              ),
            ],
            if (showAppearanceDivider) const AxiListDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 6.0,
              ),
              child: Text(
                l10n.settingsSectionAppearance,
                style: context.textTheme.muted,
              ),
            ),
            ListItemPadding(
              child: AxiListTile(
                title: l10n.settingsLanguage,
                actions: const [
                  LanguageSelector(),
                ],
                minTileHeight: compactTileHeight,
                contentPadding: compactTilePadding,
              ),
            ),
            ListItemPadding(
              child: AxiListTile(
                title: l10n.settingsThemeMode,
                actions: [
                  SizedBox(
                    width: 180,
                    child: ShadSelect<ThemeMode>(
                      initialValue: state.themeMode,
                      onChanged: (themeMode) => context
                          .read<SettingsCubit>()
                          .updateThemeMode(themeMode),
                      options: ThemeMode.values
                          .map(
                            (themeMode) => ShadOption<ThemeMode>(
                              value: themeMode,
                              child: Text(themeMode.label(l10n)),
                            ),
                          )
                          .toList(),
                      selectedOptionBuilder: (BuildContext context, mode) =>
                          Text(mode.label(l10n)),
                    ),
                  ),
                ],
                minTileHeight: compactTileHeight,
                contentPadding: compactTilePadding,
              ),
            ),
            ListItemPadding(
              child: AxiListTile(
                title: l10n.settingsColorScheme,
                actions: [
                  SizedBox(
                    width: 180,
                    child: ShadSelect<ShadColor>(
                      initialValue: state.shadColor,
                      onChanged: (colorScheme) => context
                          .read<SettingsCubit>()
                          .updateColorScheme(colorScheme),
                      options: ShadColor.values
                          .map(
                            (colorScheme) => ShadOption<ShadColor>(
                              value: colorScheme,
                              child: Text(colorScheme.name),
                            ),
                          )
                          .toList(),
                      selectedOptionBuilder:
                          (BuildContext context, ShadColor value) =>
                              Text(value.name),
                    ),
                  ),
                ],
                minTileHeight: compactTileHeight,
                contentPadding: compactTilePadding,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(l10n.settingsColorfulAvatars),
                sublabel: Text(l10n.settingsColorfulAvatarsDescription),
                value: state.colorfulAvatars,
                onChanged: (colorfulAvatars) => context
                    .read<SettingsCubit>()
                    .toggleColorfulAvatars(colorfulAvatars),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(l10n.settingsLowMotion),
                sublabel: Text(l10n.settingsLowMotionDescription),
                value: state.lowMotion,
                onChanged: (lowMotion) =>
                    context.read<SettingsCubit>().toggleLowMotion(lowMotion),
              ),
            ),
            const AxiListDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 6.0,
              ),
              child: Text(
                l10n.settingsSectionChats,
                style: context.textTheme.muted,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: MessageStorageTile(state: state),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(l10n.settingsMuteNotifications),
                sublabel: Text(l10n.settingsMuteNotificationsDescription),
                value: state.mute,
                onChanged: (mute) =>
                    context.read<SettingsCubit>().toggleMute(mute),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(l10n.settingsNotificationPreviews),
                sublabel: Text(l10n.settingsNotificationPreviewsDescription),
                value: state.notificationPreviewsEnabled,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleNotificationPreviews(enabled),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(l10n.settingsReadReceipts),
                value: state.readReceipts,
                onChanged: (readReceipts) => context
                    .read<SettingsCubit>()
                    .toggleReadReceipts(readReceipts),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(l10n.settingsTypingIndicators),
                sublabel: Text(l10n.settingsTypingIndicatorsDescription),
                value: state.indicateTyping,
                onChanged: (indicateTyping) => context
                    .read<SettingsCubit>()
                    .toggleIndicateTyping(indicateTyping),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(l10n.settingsShareTokenFooter),
                sublabel: Text(l10n.settingsShareTokenFooterDescription),
                value: state.shareTokenSignatureEnabled,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleShareTokenSignature(enabled),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ShadSwitch(
                label: Text(l10n.settingsAutoLoadEmailImages),
                sublabel: Text(l10n.settingsAutoLoadEmailImagesDescription),
                value: state.autoLoadEmailImages,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .toggleAutoLoadEmailImages(enabled),
              ),
            ),
            const AxiListDivider(),
          ],
        );
      },
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
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
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
                    return ShadSelect<MessageStorageMode>(
                      initialValue: effectiveMode,
                      onChanged: (mode) {
                        if (mode == null) return;
                        if (mode.isServerOnly && !mamSupported) return;
                        context
                            .read<SettingsCubit>()
                            .updateMessageStorageMode(mode);
                      },
                      options: options
                          .map(
                            (mode) => ShadOption<MessageStorageMode>(
                              value: mode,
                              child: Text(
                                mode.isLocal
                                    ? l10n.settingsMessageStorageLocal
                                    : l10n.settingsMessageStorageServerOnly,
                              ),
                            ),
                          )
                          .toList(),
                      selectedOptionBuilder: (context, mode) => Text(
                        mode.isLocal
                            ? l10n.settingsMessageStorageLocal
                            : l10n.settingsMessageStorageServerOnly,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsMessageStorageSubtitle,
              style: context.textTheme.muted
                  .copyWith(color: colors.mutedForeground, height: 1.2),
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
