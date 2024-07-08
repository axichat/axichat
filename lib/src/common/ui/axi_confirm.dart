import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<bool?> confirm(BuildContext context) => showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Continue'),
          )
        ],
      ),
    );
