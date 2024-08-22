import 'package:chat/src/app.dart';
import 'package:chat/src/common/ui/ui.dart';
import 'package:chat/src/draft/bloc/draft_cubit.dart';
import 'package:chat/src/roster/bloc/roster_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DraftForm extends StatefulWidget {
  const DraftForm({
    super.key,
    this.id,
    this.jids = const [''],
    this.body = '',
  });

  final int? id;
  final List<String> jids;
  final String body;

  @override
  State<DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<DraftForm> {
  late TextEditingController _bodyTextController;
  late List<String> _jids;

  @override
  void initState() {
    super.initState();
    _bodyTextController = TextEditingController(text: widget.body);
    _bodyTextController.addListener(_bodyListener);
    _jids = widget.jids;
  }

  @override
  void dispose() {
    _bodyTextController.removeListener(_bodyListener);
    _bodyTextController.dispose();
    super.dispose();
  }

  void _bodyListener() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        child: BlocConsumer<DraftCubit, DraftState>(
          listener: (context, state) {
            if (state is DraftSaveComplete) {
              ShadToaster.maybeOf(context)?.show(const ShadToast(
                title: Text('Draft saved'),
                showCloseIconOnlyWhenHovered: false,
              ));
            }
          },
          builder: (context, state) {
            final enabled = state is! DraftSending;
            final contacts = List<String>.from(
                context.watch<RosterCubit>()['items'].map((e) => e.jid));
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < _jids.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: JidInput(
                          key: UniqueKey(),
                          enabled: enabled,
                          describe: i == 0,
                          initialValue: _jids[i],
                          jidOptions: contacts,
                          onChanged: (value) => _jids[i] = value,
                        ),
                      ),
                      if (i == 0)
                        ShadButton.ghost(
                          icon: const Icon(LucideIcons.plus),
                          onPressed: () => setState(() {
                            _jids.add('');
                          }),
                        )
                      else
                        ShadButton.ghost(
                          icon: const Icon(LucideIcons.minus),
                          onPressed: () => setState(() {
                            _jids.removeAt(i);
                          }),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                AxiTextFormField(
                  controller: _bodyTextController,
                  enabled: enabled,
                  minLines: 7,
                  maxLines: 7,
                  placeholder: const Text('Message'),
                ),
                const SizedBox(height: 12),
                if (state is DraftFailure)
                  Text(
                    state.message,
                    style: TextStyle(
                      color: context.colorScheme.destructive,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ShadButton.outline(
                      enabled: enabled &&
                          (_jids.any((e) => e.isNotEmpty) ||
                              _bodyTextController.text.isNotEmpty),
                      text: const Text('Save draft'),
                      onPressed: () => context.read<DraftCubit>().saveDraft(
                          id: widget.id,
                          jids: _jids,
                          body: _bodyTextController.text),
                    ),
                    ShadButton(
                      enabled: enabled &&
                          _jids.any((e) => e.isNotEmpty) &&
                          _bodyTextController.text.isNotEmpty,
                      text: const Text('Send'),
                      onPressed: () async {
                        if (!Form.of(context).validate()) return;
                        await context.read<DraftCubit>().sendDraft(
                            id: widget.id,
                            jids: _jids,
                            body: _bodyTextController.text);
                        if (!context.mounted) return;
                        context.pop();
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
