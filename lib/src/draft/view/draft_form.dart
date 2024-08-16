import 'package:chat/src/app.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/draft/bloc/draft_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> showDraft(
  BuildContext context, {
  required int? id,
  String jid = '',
  String body = '',
}) {
  final locate = context.read;
  return showShadDialog(
    context: context,
    builder: (context) {
      bool enabled = true;
      return BlocProvider.value(
        value: locate<DraftCubit>(),
        child: Form(
          child: StatefulBuilder(
            builder: (context, setState) {
              return BlocConsumer<DraftCubit, DraftState>(
                listener: (context, state) {
                  if (state is DraftSent) {
                    setState(() {
                      jid = '';
                      body = '';
                      enabled = true;
                    });
                    context.pop();
                  } else if (state is DraftSending) {
                    setState(() {
                      enabled = false;
                    });
                  }
                },
                builder: (context, state) => AxiInputDialog(
                  title: const Text('Compose message'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      JidInput(
                        enabled: enabled,
                        initialValue: jid,
                        onChanged: (value) {
                          setState(() => jid = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      AxiTextFormField(
                        enabled: enabled,
                        minLines: 5,
                        maxLines: 5,
                        initialValue: body,
                        placeholder: const Text('Message'),
                        onChanged: (value) {
                          setState(() => body = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (state is DraftFailure)
                        Text(
                          state.message,
                          style: TextStyle(
                            color: context.colorScheme.destructive,
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    ShadButton.outline(
                      onPressed: (jid.isEmpty && body.isEmpty) || !enabled
                          ? null
                          : () {
                              context
                                  .read<DraftCubit>()
                                  .saveDraft(id: id, jid: jid, body: body);
                              context.pop();
                            },
                      text: const Text('Save draft'),
                    ),
                  ],
                  callbackText: 'Send',
                  callback: jid.isEmpty || body.isEmpty || !enabled
                      ? null
                      : () {
                          if (!Form.of(context).validate()) return;
                          context
                              .read<DraftCubit>()
                              .sendDraft(id: id, jid: jid, body: body);
                        },
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
