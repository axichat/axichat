// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/bloc/email_contact_import_cubit.dart';
import 'package:axichat/src/email/service/email_contact_import_models.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';

class EmailContactImportTile extends StatelessWidget {
  const EmailContactImportTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rootContext = context;
    return BlocSelector<EmailContactImportCubit, EmailContactImportState, bool>(
      selector: (state) => state is EmailContactImportInProgress,
      builder: (context, loading) {
        return ListItemPadding(
          child: AxiListTile(
            leading: const Icon(LucideIcons.userRoundPlus),
            title: l10n.emailContactsImportTitle,
            subtitle: l10n.emailContactsImportSubtitle,
            onTap: loading
                ? null
                : () {
                    showFadeScaleDialog(
                      context: rootContext,
                      builder: (dialogContext) => EmailContactImportDialog(
                        cubit: context.read<EmailContactImportCubit>()..reset(),
                      ),
                    );
                  },
          ),
        );
      },
    );
  }
}

class EmailContactImportActionButton extends StatelessWidget {
  const EmailContactImportActionButton({
    super.key,
    this.padding,
  });

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final rootContext = context;
    return BlocSelector<EmailContactImportCubit, EmailContactImportState, bool>(
      selector: (state) => state is EmailContactImportInProgress,
      builder: (context, loading) {
        return Padding(
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: spacing.l,
                vertical: spacing.xs,
              ),
          child: AxiListButton(
            leading: const Icon(LucideIcons.userRoundPlus),
            onPressed: loading
                ? null
                : () {
                    showFadeScaleDialog(
                      context: rootContext,
                      builder: (dialogContext) => EmailContactImportDialog(
                        cubit: context.read<EmailContactImportCubit>()..reset(),
                      ),
                    );
                  },
            child: Text(
              context.l10n.emailContactsImportTitle,
              style: context.textTheme.small,
            ),
          ),
        );
      },
    );
  }
}

class EmailContactImportDialog extends StatefulWidget {
  const EmailContactImportDialog({super.key, required this.cubit});

  final EmailContactImportCubit cubit;

  @override
  State<EmailContactImportDialog> createState() =>
      _EmailContactImportDialogState();
}

class _EmailContactImportDialogState extends State<EmailContactImportDialog> {
  EmailContactImportFormat _format = EmailContactImportFormat.gmail;
  File? _selectedFile;
  String? _selectedFileName;

  Future<void> _pickFile() async {
    final pickerResult = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: _format.allowedExtensions,
    );
    if (!mounted || pickerResult == null || pickerResult.files.isEmpty) {
      return;
    }
    final path = pickerResult.files.single.path;
    if (path == null) {
      _showFileAccessError();
      return;
    }
    setState(() {
      _selectedFile = File(path);
      _selectedFileName = p.basename(path);
    });
  }

  void _showFileAccessError() {
    final showToast = ShadToaster.maybeOf(context)?.show;
    if (showToast == null) {
      return;
    }
    showToast(
      FeedbackToast.error(
        message: context.l10n.emailContactsImportFileAccessError,
      ),
    );
  }

  void _startImport() {
    final file = _selectedFile;
    if (file == null) {
      return;
    }
    widget.cubit.importContacts(file: file, format: _format);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    return BlocConsumer<EmailContactImportCubit, EmailContactImportState>(
      bloc: widget.cubit,
      listener: (context, state) {
        final showToast = ShadToaster.maybeOf(context)?.show;
        if (showToast == null) {
          return;
        }
        if (state is EmailContactImportFailure) {
          final tone = _toneForFailure(state.reason);
          showToast(
            FeedbackToast(
              tone: tone,
              message: _failureMessage(l10n, state.reason),
            ),
          );
          return;
        }
        if (state is EmailContactImportSuccess) {
          final summary = state.summary;
          if (summary.hasImported) {
            showToast(
              FeedbackToast.success(message: _successMessage(l10n, summary)),
            );
            if (context.canPop()) {
              context.pop();
            }
            return;
          }
          showToast(
            FeedbackToast.info(
              message: l10n.emailContactsImportNoValidContacts,
            ),
          );
        }
      },
      builder: (context, state) {
        final bool loading = state is EmailContactImportInProgress;
        final bool importEnabled = _selectedFile != null && !loading;
        final String fileLabel =
            _selectedFileName ?? l10n.emailContactsImportNoFile;
        final TextStyle fileStyle = _selectedFileName == null
            ? context.textTheme.muted
            : context.textTheme.small;
        final TextStyle selectTextStyle = context.textTheme.small.copyWith(
          color: context.colorScheme.foreground,
        );
        final EmailContactImportFailureReason? failureReason =
            state is EmailContactImportFailure ? state.reason : null;
        return AxiInputDialog(
          title: Text(l10n.emailContactsImportTitle),
          loading: loading,
          callbackText: l10n.emailContactsImportAction,
          callback: importEnabled ? _startImport : null,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.emailContactsImportSubtitle,
                style: context.textTheme.muted,
              ),
              SizedBox(height: spacing.m),
              Text(
                l10n.emailContactsImportFormatLabel,
                style: context.textTheme.small,
              ),
              SizedBox(height: spacing.s),
              AxiSelect<EmailContactImportFormat>(
                initialValue: _format,
                onChanged: loading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _format = value;
                          _selectedFile = null;
                          _selectedFileName = null;
                        });
                      },
                options: EmailContactImportFormat.values
                    .map(
                      (format) => ShadOption<EmailContactImportFormat>(
                        value: format,
                        child: Text(
                          format.label(l10n),
                          style: selectTextStyle,
                        ),
                      ),
                    )
                    .toList(),
                selectedOptionBuilder: (context, format) =>
                    Text(format.label(l10n), style: selectTextStyle),
              ),
              SizedBox(height: spacing.m),
              Text(
                l10n.emailContactsImportFileLabel,
                style: context.textTheme.small,
              ),
              SizedBox(height: spacing.s),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fileLabel,
                      style: fileStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AxiButton.outline(
                    onPressed: loading ? null : _pickFile,
                    child: Text(l10n.emailContactsImportChooseFile),
                  ),
                ],
              ),
              if (failureReason != null) ...[
                SizedBox(height: spacing.m),
                Text(
                  _failureMessage(l10n, failureReason),
                  style: context.textTheme.small.copyWith(
                    color: context.colorScheme.destructive,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

extension EmailContactImportFormatLabel on EmailContactImportFormat {
  String label(AppLocalizations l10n) {
    switch (this) {
      case EmailContactImportFormat.gmail:
        return l10n.emailContactsImportFormatGmail;
      case EmailContactImportFormat.outlook:
        return l10n.emailContactsImportFormatOutlook;
      case EmailContactImportFormat.yahoo:
        return l10n.emailContactsImportFormatYahoo;
      case EmailContactImportFormat.genericCsv:
        return l10n.emailContactsImportFormatGenericCsv;
      case EmailContactImportFormat.vcard:
        return l10n.emailContactsImportFormatVcard;
    }
  }
}

FeedbackTone _toneForFailure(EmailContactImportFailureReason reason) {
  switch (reason) {
    case EmailContactImportFailureReason.emptyFile:
    case EmailContactImportFailureReason.noContacts:
      return FeedbackTone.info;
    case EmailContactImportFailureReason.fileTooLarge:
    case EmailContactImportFailureReason.tooManyContacts:
    case EmailContactImportFailureReason.unsupportedFileType:
      return FeedbackTone.warning;
    case EmailContactImportFailureReason.noEmailAccount:
    case EmailContactImportFailureReason.readFailure:
    case EmailContactImportFailureReason.importFailed:
      return FeedbackTone.error;
  }
}

String _failureMessage(
  AppLocalizations l10n,
  EmailContactImportFailureReason reason,
) {
  switch (reason) {
    case EmailContactImportFailureReason.noEmailAccount:
      return l10n.emailContactsImportAccountRequired;
    case EmailContactImportFailureReason.emptyFile:
      return l10n.emailContactsImportEmptyFile;
    case EmailContactImportFailureReason.readFailure:
      return l10n.emailContactsImportReadFailure;
    case EmailContactImportFailureReason.fileTooLarge:
      return l10n.emailContactsImportFileTooLarge;
    case EmailContactImportFailureReason.unsupportedFileType:
      return l10n.emailContactsImportUnsupportedFile;
    case EmailContactImportFailureReason.noContacts:
      return l10n.emailContactsImportNoContacts;
    case EmailContactImportFailureReason.tooManyContacts:
      return l10n.emailContactsImportTooManyContacts;
    case EmailContactImportFailureReason.importFailed:
      return l10n.emailContactsImportFailed;
  }
}

String _successMessage(
  AppLocalizations l10n,
  EmailContactImportSummary summary,
) {
  return l10n.emailContactsImportSuccess(
    summary.imported,
    summary.duplicates,
    summary.invalid,
    summary.failed,
  );
}
