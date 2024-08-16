import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<bool?> confirm(BuildContext context, {String text = 'Are you sure?'}) =>
    showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Confirm'),
        content: Text(text),
        actions: [
          ShadButton.outline(
            onPressed: () => context.pop(false),
            text: const Text('Cancel'),
          ),
          ShadButton.destructive(
            onPressed: () => context.pop(true),
            text: const Text('Continue'),
          )
        ],
      ),
    );
