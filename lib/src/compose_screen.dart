import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/draft/bloc/draft_cubit.dart';
import 'package:axichat/src/draft/view/draft_form.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
      appBar: AppBar(
        backgroundColor: context.colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        shape: Border(
          bottom: BorderSide(color: context.colorScheme.border),
        ),
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: AxiIconButton(
                  iconData: LucideIcons.arrowLeft,
                  tooltip: 'Back',
                  color: context.colorScheme.foreground,
                  borderColor: context.colorScheme.border,
                  onPressed: () => Navigator.pop(context),
                ),
              )
            : null,
        title: const Text('Compose'),
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
