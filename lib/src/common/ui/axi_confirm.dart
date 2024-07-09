import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<bool?> confirm(BuildContext context) => showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Confirm'),
        content: const Text('Are you sure?'),
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
