import 'package:chat/src/draft/bloc/draft_cubit.dart';
import 'package:chat/src/draft/view/draft_form.dart';
import 'package:chat/src/roster/bloc/roster_cubit.dart';
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
      appBar: AppBar(
        title: const Text('Compose'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400.0),
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
    );
  }
}
