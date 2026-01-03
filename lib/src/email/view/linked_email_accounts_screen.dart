// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/bloc/linked_email_accounts_cubit.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _pageMaxWidth = 720.0;
const EdgeInsets _pagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);
const double _sectionSpacing = 16.0;
const double _headerSpacing = 12.0;
const double _headerTextSpacing = 8.0;
const double _tileSpacing = 8.0;
const double _iconSize = 18.0;
const double _iconPadding = 10.0;
const double _iconRadius = 12.0;
const double _actionSpacing = 8.0;
const double _badgeHorizontalPadding = 8.0;
const double _badgeVerticalPadding = 4.0;
const double _progressIndicatorSize = 16.0;
const double _appBarLeadingPadding = 12.0;
const double _appBarLeadingWidthPadding = 24.0;
const double _supportNoteSpacing = 10.0;
const double _supportNoteIconSize = 18.0;
const double _supportNoteIconPadding = 6.0;
const double _supportNoteRadius = 12.0;
const double _supportNoteBorderWidth = 1.0;
const double _supportNoteBackgroundAlpha = 0.08;
const double _errorIconSize = 20.0;

class LinkedEmailAccountsScreen extends StatelessWidget {
  const LinkedEmailAccountsScreen({super.key, required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    final String jid = locate<ProfileCubit>().state.jid;
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: locate<ProfileCubit>()),
        BlocProvider(
          create: (_) => LinkedEmailAccountsCubit(
            emailService: locate<EmailService>(),
            jid: jid,
          ),
        ),
      ],
      child: const _LinkedEmailAccountsBody(),
    );
  }
}

class _LinkedEmailAccountsBody extends StatelessWidget {
  const _LinkedEmailAccountsBody();

  @override
  Widget build(BuildContext context) {
    final void Function(ShadToast)? showToast =
        ShadToaster.maybeOf(context)?.show;
    return BlocConsumer<LinkedEmailAccountsCubit, LinkedEmailAccountsState>(
      listenWhen: (previous, current) =>
          previous.actionStatus != current.actionStatus ||
          previous.action != current.action ||
          previous.actionFailure != current.actionFailure,
      listener: (context, state) {
        if (state.action.isLink || state.action.isUpdatePassword) {
          return;
        }
        if (state.action.isNone || state.actionStatus.isNone) {
          return;
        }
        if (state.actionStatus.isFailure) {
          final String message = linkedEmailAccountsFailureMessage(
            l10n: context.l10n,
            action: state.action,
            failure: state.actionFailure,
            fallbackLimit: state.extraAccountLimit,
          );
          showToast?.call(FeedbackToast.error(message: message));
        }
        context.read<LinkedEmailAccountsCubit>().clearActionStatus();
      },
      builder: (context, state) {
        final colors = context.colorScheme;
        final l10n = context.l10n;
        final bool showLoading =
            state.status.isLoading && state.accounts.isEmpty;
        final bool showError = state.status.isFailure && state.accounts.isEmpty;
        final Widget content = showLoading
            ? Center(
                child: AxiProgressIndicator(
                  color: colors.foreground,
                ),
              )
            : showError
                ? _LinkedEmailAccountsErrorState(
                    onRetry: () =>
                        context.read<LinkedEmailAccountsCubit>().load(),
                  )
                : _LinkedEmailAccountsContent(state: state);
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.linkedEmailAccountsTitle),
            elevation: 0,
            backgroundColor: colors.background,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            shape: Border(
              bottom: BorderSide(
                color: colors.border,
              ),
            ),
            leadingWidth:
                AxiIconButton.kDefaultSize + _appBarLeadingWidthPadding,
            leading: Padding(
              padding: const EdgeInsets.only(left: _appBarLeadingPadding),
              child: AxiIconButton.ghost(
                iconData: LucideIcons.arrowLeft,
                tooltip: l10n.commonBack,
                onPressed: context.pop,
              ),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
                child: Padding(
                  padding: _pagePadding,
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LinkedEmailAccountsContent extends StatelessWidget {
  const _LinkedEmailAccountsContent({required this.state});

  final LinkedEmailAccountsState state;

  @override
  Widget build(BuildContext context) {
    final bool canAdd = state.canAddAccount && !state.actionStatus.isLoading;
    return ListView(
      children: [
        _LinkedEmailAccountsHeader(
          supportsMultipleAccounts: state.supportsMultipleAccounts,
          extraAccountLimit: state.extraAccountLimit,
          canAdd: canAdd,
          onAdd: () => _LinkedEmailAccountSheet.show(context),
        ),
        if (!state.supportsMultipleAccounts)
          const SizedBox(height: _sectionSpacing),
        if (!state.supportsMultipleAccounts)
          const _LinkedEmailAccountsSupportNote(),
        if (state.accounts.isEmpty) ...[
          const SizedBox(height: _sectionSpacing),
          const _LinkedEmailAccountsEmptyState(),
        ] else ...[
          const SizedBox(height: _sectionSpacing),
          for (final EmailAccountProfile account in state.accounts) ...[
            _LinkedEmailAccountTile(
              account: account,
              canRemove: !state.actionStatus.isLoading,
              isBusy: state.actionStatus.isLoading &&
                  state.actionAccountId == account.id,
            ),
            const SizedBox(height: _tileSpacing),
          ],
        ],
      ],
    );
  }
}

class _LinkedEmailAccountsHeader extends StatelessWidget {
  const _LinkedEmailAccountsHeader({
    required this.supportsMultipleAccounts,
    required this.extraAccountLimit,
    required this.canAdd,
    required this.onAdd,
  });

  final bool supportsMultipleAccounts;
  final int extraAccountLimit;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final TextStyle descriptionStyle = context.textTheme.p.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    final TextStyle hintStyle = context.textTheme.muted.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    final String limitHint =
        l10n.linkedEmailAccountsLimitHint(extraAccountLimit);
    final Widget textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.linkedEmailAccountsDescription),
        const SizedBox(height: _headerTextSpacing),
        Text(
          l10n.linkedEmailAccountsDefaultHint,
          style: hintStyle,
        ),
        if (supportsMultipleAccounts) ...[
          const SizedBox(height: _headerTextSpacing),
          Text(
            limitHint,
            style: hintStyle,
          ),
        ],
      ],
    );
    final Widget addButton = ShadButton(
      enabled: canAdd,
      onPressed: canAdd ? onAdd : null,
      child: Text(l10n.linkedEmailAccountsLinkAction),
    ).withTapBounce(enabled: canAdd);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: _sectionSpacing,
          runSpacing: _headerSpacing,
          alignment: WrapAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
              child: DefaultTextStyle.merge(
                style: descriptionStyle,
                child: textBlock,
              ),
            ),
            addButton,
          ],
        ),
      ],
    );
  }
}

class _LinkedEmailAccountsSupportNote extends StatelessWidget {
  const _LinkedEmailAccountsSupportNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final Color background =
        colors.muted.withValues(alpha: _supportNoteBackgroundAlpha);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_supportNoteRadius),
        border: Border.all(
          color: colors.border,
          width: _supportNoteBorderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_supportNoteSpacing),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: _supportNoteIconPadding),
              child: Icon(
                LucideIcons.info,
                size: _supportNoteIconSize,
                color: colors.foreground,
              ),
            ),
            const SizedBox(width: _supportNoteSpacing),
            Expanded(
              child: Text(
                l10n.linkedEmailAccountsUnsupportedHint,
                style: context.textTheme.muted.copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedEmailAccountsEmptyState extends StatelessWidget {
  const _LinkedEmailAccountsEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ShadCard(
      padding: const EdgeInsets.all(_sectionSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.linkedEmailAccountsEmptyTitle,
            style: context.textTheme.h4,
          ),
          const SizedBox(height: _headerTextSpacing),
          Text(
            l10n.linkedEmailAccountsEmptyDescription,
            style: context.textTheme.muted,
          ),
        ],
      ),
    );
  }
}

class _LinkedEmailAccountsErrorState extends StatelessWidget {
  const _LinkedEmailAccountsErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: _errorIconSize,
            color: colors.destructive,
          ),
          const SizedBox(height: _headerTextSpacing),
          Text(
            l10n.linkedEmailAccountsLoadFailure,
            style: context.textTheme.muted.copyWith(
              color: colors.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _headerSpacing),
          ShadButton.outline(
            onPressed: onRetry,
            child: Text(l10n.commonRetry),
          ).withTapBounce(),
        ],
      ),
    );
  }
}

class _LinkedEmailAccountTile extends StatelessWidget {
  const _LinkedEmailAccountTile({
    required this.account,
    required this.isBusy,
    required this.canRemove,
  });

  final EmailAccountProfile account;
  final bool isBusy;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final bool showSubtitle = account.displayName != account.address;
    final String title = showSubtitle ? account.displayName : account.address;
    final String? subtitle = showSubtitle ? account.address : null;
    final Color iconBackground =
        colors.muted.withValues(alpha: _supportNoteBackgroundAlpha);
    final List<AxiMenuAction> actions = <AxiMenuAction>[
      if (!account.isPrimary)
        AxiMenuAction(
          label: l10n.linkedEmailAccountsMakeDefaultAction,
          icon: LucideIcons.star,
          onPressed: () => context
              .read<LinkedEmailAccountsCubit>()
              .setPrimaryAccount(accountId: account.id),
        ),
      AxiMenuAction(
        label: l10n.linkedEmailAccountsUpdatePasswordAction,
        icon: LucideIcons.keyRound,
        enabled: canRemove,
        onPressed: canRemove
            ? () => _LinkedEmailAccountPasswordSheet.show(
                  context,
                  account: account,
                )
            : null,
      ),
      AxiMenuAction(
        label: l10n.commonRemove,
        icon: LucideIcons.trash2,
        destructive: true,
        enabled: canRemove,
        onPressed: canRemove
            ? () async {
                final bool? confirmed = await confirm(
                  context,
                  title: l10n.linkedEmailAccountsRemoveTitle,
                  message: l10n.linkedEmailAccountsRemoveDescription,
                  confirmLabel: l10n.commonRemove,
                  cancelLabel: l10n.commonCancel,
                  destructiveConfirm: true,
                );
                if (confirmed == true && context.mounted) {
                  context
                      .read<LinkedEmailAccountsCubit>()
                      .unlinkAccount(accountId: account.id);
                }
              }
            : null,
      ),
    ];
    final bool hasEnabledAction =
        actions.any((AxiMenuAction action) => action.enabled);
    final List<Widget> trailing = <Widget>[
      if (account.isPrimary)
        ShadBadge.secondary(
          padding: const EdgeInsets.symmetric(
            horizontal: _badgeHorizontalPadding,
            vertical: _badgeVerticalPadding,
          ),
          child: Text(l10n.linkedEmailAccountsDefaultBadge),
        ),
      if (isBusy)
        AxiProgressIndicator(
          dimension: _progressIndicatorSize,
          color: colors.foreground,
        )
      else
        AxiMore(
          actions: actions,
          tooltip: l10n.commonActions,
          enabled: hasEnabledAction,
        ),
    ];
    final List<Widget> paddedActions = <Widget>[];
    for (final Widget action in trailing) {
      if (paddedActions.isNotEmpty) {
        paddedActions.add(const SizedBox(width: _actionSpacing));
      }
      paddedActions.add(action);
    }
    return ListItemPadding(
      child: AxiListTile(
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(_iconRadius),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_iconPadding),
            child: Icon(
              LucideIcons.mail,
              size: _iconSize,
              color: colors.foreground,
            ),
          ),
        ),
        title: title,
        subtitle: subtitle,
        actions: paddedActions,
      ),
    );
  }
}

class _LinkedEmailAccountSheet extends StatefulWidget {
  const _LinkedEmailAccountSheet({required this.compact});

  final bool compact;

  static Future<void> show(BuildContext context) {
    final CommandSurface commandSurface = resolveCommandSurface(context);
    final bool compact = commandSurface == CommandSurface.sheet;
    return showAdaptiveBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: compact,
      dialogMaxWidth: compact ? _sheetMaxWidthCompact : _sheetMaxWidthWide,
      surfacePadding: EdgeInsets.zero,
      builder: (_) => _LinkedEmailAccountSheet(compact: compact),
    );
  }

  @override
  State<_LinkedEmailAccountSheet> createState() =>
      _LinkedEmailAccountSheetState();
}

class _LinkedEmailAccountSheetState extends State<_LinkedEmailAccountSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  late final TextEditingController _passwordController;
  late final FocusNode _passwordFocusNode;
  bool _setPrimary = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController()..addListener(_clearError);
    _passwordController = TextEditingController()..addListener(_clearError);
    _passwordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorText == null) {
      return;
    }
    setState(() => _errorText = null);
  }

  void _submit(BuildContext context) {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    _clearError();
    context.read<LinkedEmailAccountsCubit>().linkAccount(
          address: _addressController.text.trim(),
          password: _passwordController.text,
          setPrimary: _setPrimary,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final TextStyle placeholderStyle = context.textTheme.muted.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    final EdgeInsets sheetPadding = EdgeInsets.symmetric(
      horizontal: widget.compact ? _sheetCompactPadding : _sheetWidePadding,
    );
    return BlocListener<LinkedEmailAccountsCubit, LinkedEmailAccountsState>(
      listenWhen: (previous, current) =>
          previous.actionStatus != current.actionStatus ||
          previous.action != current.action ||
          previous.actionFailure != current.actionFailure,
      listener: (context, state) {
        if (!state.action.isLink) {
          return;
        }
        if (state.actionStatus.isSuccess) {
          Navigator.of(context).maybePop();
          context.read<LinkedEmailAccountsCubit>().clearActionStatus();
          return;
        }
        if (state.actionStatus.isFailure) {
          final String message = linkedEmailAccountsFailureMessage(
            l10n: context.l10n,
            action: state.action,
            failure: state.actionFailure,
            fallbackLimit: state.extraAccountLimit,
          );
          setState(() => _errorText = message);
          context.read<LinkedEmailAccountsCubit>().clearActionStatus();
        }
      },
      child: AxiSheetScaffold.scroll(
        header: AxiSheetHeader(
          title: Text(l10n.linkedEmailAccountsSheetTitle),
          subtitle: Text(l10n.linkedEmailAccountsSheetSubtitle),
          onClose: () => Navigator.of(context).maybePop(),
          padding: sheetPadding.copyWith(
            top: _sheetHeaderTopPadding,
            bottom: _sheetHeaderBottomPadding,
          ),
        ),
        bodyPadding: sheetPadding.copyWith(bottom: _sheetBottomPadding),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AxiTextFormField(
                  controller: _addressController,
                  autocorrect: false,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  placeholder: Text(
                    l10n.linkedEmailAccountsAddressPlaceholder,
                    style: placeholderStyle,
                  ),
                  placeholderStyle: placeholderStyle,
                  onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  validator: (String value) {
                    final String trimmed = value.trim();
                    if (trimmed.isEmpty) {
                      return l10n.linkedEmailAccountsAddressRequired;
                    }
                    if (!trimmed.isValidEmailAddress) {
                      return l10n.linkedEmailAccountsAddressInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: _sheetFieldSpacing),
                PasswordInput(
                  controller: _passwordController,
                  placeholder: l10n.linkedEmailAccountsPasswordPlaceholder,
                  semanticsLabel: l10n.linkedEmailAccountsPasswordLabel,
                  enabled: true,
                  validator: (String? text) {
                    final String trimmed = text?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return l10n.authPasswordRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: _sheetFieldSpacing),
                ShadSwitch(
                  label: Text(l10n.linkedEmailAccountsSetDefaultLabel),
                  sublabel: Text(l10n.linkedEmailAccountsSetDefaultDescription),
                  value: _setPrimary,
                  onChanged: (value) => setState(() {
                    _setPrimary = value;
                  }),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: _sheetFieldSpacing),
                  Text(
                    _errorText!,
                    style: TextStyle(color: context.colorScheme.destructive),
                  ),
                ],
                const SizedBox(height: _sheetFieldSpacing),
                BlocBuilder<LinkedEmailAccountsCubit, LinkedEmailAccountsState>(
                  builder: (context, state) {
                    final bool loading =
                        state.actionStatus.isLoading && state.action.isLink;
                    final bool enabled = !loading;
                    return ShadButton(
                      enabled: enabled,
                      onPressed: enabled ? () => _submit(context) : null,
                      leading: AnimatedCrossFade(
                        crossFadeState: loading
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration:
                            context.watch<SettingsCubit>().animationDuration,
                        firstChild: const SizedBox(),
                        secondChild: AxiProgressIndicator(
                          color: context.colorScheme.primaryForeground,
                          semanticsLabel: l10n.commonContinue,
                        ),
                      ),
                      child: Text(l10n.linkedEmailAccountsLinkAction),
                    ).withTapBounce(enabled: enabled);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedEmailAccountPasswordSheet extends StatefulWidget {
  const _LinkedEmailAccountPasswordSheet({
    required this.compact,
    required this.account,
  });

  final bool compact;
  final EmailAccountProfile account;

  static Future<void> show(
    BuildContext context, {
    required EmailAccountProfile account,
  }) {
    final CommandSurface commandSurface = resolveCommandSurface(context);
    final bool compact = commandSurface == CommandSurface.sheet;
    return showAdaptiveBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: compact,
      dialogMaxWidth: compact ? _sheetMaxWidthCompact : _sheetMaxWidthWide,
      surfacePadding: EdgeInsets.zero,
      builder: (_) => _LinkedEmailAccountPasswordSheet(
        compact: compact,
        account: account,
      ),
    );
  }

  @override
  State<_LinkedEmailAccountPasswordSheet> createState() =>
      _LinkedEmailAccountPasswordSheetState();
}

class _LinkedEmailAccountPasswordSheetState
    extends State<_LinkedEmailAccountPasswordSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _passwordController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController()..addListener(_clearError);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorText == null) {
      return;
    }
    setState(() => _errorText = null);
  }

  void _submit(BuildContext context) {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    _clearError();
    context.read<LinkedEmailAccountsCubit>().updatePassword(
          accountId: widget.account.id,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final TextStyle labelStyle = context.textTheme.muted.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    final EdgeInsets sheetPadding = EdgeInsets.symmetric(
      horizontal: widget.compact ? _sheetCompactPadding : _sheetWidePadding,
    );
    return BlocListener<LinkedEmailAccountsCubit, LinkedEmailAccountsState>(
      listenWhen: (previous, current) =>
          previous.actionStatus != current.actionStatus ||
          previous.action != current.action ||
          previous.actionFailure != current.actionFailure ||
          previous.actionAccountId != current.actionAccountId,
      listener: (context, state) {
        if (!state.action.isUpdatePassword ||
            state.actionAccountId != widget.account.id) {
          return;
        }
        if (state.actionStatus.isSuccess) {
          Navigator.of(context).maybePop();
          context.read<LinkedEmailAccountsCubit>().clearActionStatus();
          return;
        }
        if (state.actionStatus.isFailure) {
          final String message = linkedEmailAccountsFailureMessage(
            l10n: context.l10n,
            action: state.action,
            failure: state.actionFailure,
            fallbackLimit: state.extraAccountLimit,
          );
          setState(() => _errorText = message);
          context.read<LinkedEmailAccountsCubit>().clearActionStatus();
        }
      },
      child: AxiSheetScaffold.scroll(
        header: AxiSheetHeader(
          title: Text(l10n.linkedEmailAccountsUpdateTitle),
          subtitle: Text(l10n.linkedEmailAccountsSheetSubtitle),
          onClose: () => Navigator.of(context).maybePop(),
          padding: sheetPadding.copyWith(
            top: _sheetHeaderTopPadding,
            bottom: _sheetHeaderBottomPadding,
          ),
        ),
        bodyPadding: sheetPadding.copyWith(bottom: _sheetBottomPadding),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.linkedEmailAccountsAccountLabel,
                  style: labelStyle,
                ),
                const SizedBox(height: _sheetLabelSpacing),
                Text(widget.account.address),
                const SizedBox(height: _sheetFieldSpacing),
                PasswordInput(
                  controller: _passwordController,
                  placeholder: l10n.linkedEmailAccountsPasswordPlaceholder,
                  semanticsLabel: l10n.linkedEmailAccountsPasswordLabel,
                  enabled: true,
                  validator: (String? text) {
                    final String trimmed = text?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return l10n.authPasswordRequired;
                    }
                    return null;
                  },
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: _sheetFieldSpacing),
                  Text(
                    _errorText!,
                    style: TextStyle(color: context.colorScheme.destructive),
                  ),
                ],
                const SizedBox(height: _sheetFieldSpacing),
                BlocBuilder<LinkedEmailAccountsCubit, LinkedEmailAccountsState>(
                  builder: (context, state) {
                    final bool loading = state.actionStatus.isLoading &&
                        state.action.isUpdatePassword &&
                        state.actionAccountId == widget.account.id;
                    final bool enabled = !loading;
                    return ShadButton(
                      enabled: enabled,
                      onPressed: enabled ? () => _submit(context) : null,
                      leading: AnimatedCrossFade(
                        crossFadeState: loading
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration:
                            context.watch<SettingsCubit>().animationDuration,
                        firstChild: const SizedBox(),
                        secondChild: AxiProgressIndicator(
                          color: context.colorScheme.primaryForeground,
                          semanticsLabel: l10n.commonSave,
                        ),
                      ),
                      child: Text(l10n.commonSave),
                    ).withTapBounce(enabled: enabled);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String linkedEmailAccountsFailureMessage({
  required AppLocalizations l10n,
  required LinkedEmailAccountsAction action,
  required LinkedEmailAccountsActionFailure? failure,
  required int fallbackLimit,
}) {
  final LinkedEmailAccountsActionFailure resolvedFailure = failure ??
      const LinkedEmailAccountsActionFailure(
        type: LinkedEmailAccountsFailureType.generic,
      );
  final String? customMessage = resolvedFailure.message;
  if (customMessage != null && customMessage.trim().isNotEmpty) {
    return customMessage;
  }
  switch (resolvedFailure.type) {
    case LinkedEmailAccountsFailureType.limitReached:
      final int limit = resolvedFailure.limit ?? fallbackLimit;
      return l10n.linkedEmailAccountsLimitReached(limit);
    case LinkedEmailAccountsFailureType.unsupported:
      return l10n.linkedEmailAccountsUnsupportedError;
    case LinkedEmailAccountsFailureType.generic:
      return switch (action) {
        LinkedEmailAccountsAction.link => l10n.linkedEmailAccountsLinkFailure,
        LinkedEmailAccountsAction.unlink =>
          l10n.linkedEmailAccountsUnlinkFailure,
        LinkedEmailAccountsAction.setPrimary =>
          l10n.linkedEmailAccountsDefaultFailure,
        LinkedEmailAccountsAction.updatePassword =>
          l10n.linkedEmailAccountsUpdateFailure,
        LinkedEmailAccountsAction.none => l10n.linkedEmailAccountsLinkFailure,
      };
  }
}

const double _sheetMaxWidthCompact = 560.0;
const double _sheetMaxWidthWide = 720.0;
const double _sheetCompactPadding = 12.0;
const double _sheetWidePadding = 24.0;
const double _sheetBottomPadding = 16.0;
const double _sheetHeaderTopPadding = 16.0;
const double _sheetHeaderBottomPadding = 12.0;
const double _sheetFieldSpacing = 12.0;
const double _sheetLabelSpacing = 6.0;
