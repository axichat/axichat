import 'package:chat/src/app.dart';
import 'package:chat/src/profile/bloc/profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ProfileFingerprint extends StatelessWidget {
  const ProfileFingerprint({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        const blockSize = 4;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300.0),
          child: ShadCard(
            title: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'OMEMO:2 Fingerprint',
                  style: context.textTheme.table,
                ),
              ),
            ),
            description: Column(
              children: [
                for (var i = 0; i < blockSize; i++)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var j = i; j < i + blockSize; j++)
                        () {
                          final start = j * blockSize;
                          final block = state.fingerprint
                              .substring(start, start + blockSize);
                          return Text(block);
                        }(),
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
