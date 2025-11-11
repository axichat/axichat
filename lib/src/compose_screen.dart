import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/axi_icon_button.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_form.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ComposeScreen extends StatelessWidget {
  const ComposeScreen({
    super.key,
    this.id,
    this.jids = const [''],
    this.body = '',
    required this.locate,
  });

  final int? id;
  final List<String> jids;
  final String body;
  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: context.colorScheme.background,
            border: Border(
              bottom: BorderSide(color: context.colorScheme.border),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  AxiIconButton(
                    iconData: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Compose',
                    style: context.textTheme.h3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400.0),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: context.colorScheme.card,
                shape: ContinuousRectangleBorder(
                  borderRadius: context.radius,
                  side: BorderSide(color: context.colorScheme.border),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider.value(
                      value: locate<DraftCubit>(),
                    ),
                    BlocProvider.value(
                      value: locate<RosterCubit>(),
                    ),
                  ],
                  child: DraftForm(
                    id: id,
                    jids: jids,
                    body: body,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
