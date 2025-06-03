import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<bool?> confirm(BuildContext context, {String text = 'Are you sure?'}) =>
    showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Confirm'),
        actions: [
          ShadButton.outline(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          ShadButton.destructive(
            onPressed: () => context.pop(true),
            child: const Text('Continue'),
          )
        ],
        child: Text(
          text,
          style: context.textTheme.small,
        ),
      ),
    );
