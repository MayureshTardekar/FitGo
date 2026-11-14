import 'package:flutter/material.dart';

/// Confirms a local write immediately, with an optional Undo action.
void showLogSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required String status,
  VoidCallback? onUndo,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$message · $status'),
        duration: const Duration(seconds: 5),
        action: onUndo == null
            ? null
            : SnackBarAction(label: 'Undo', onPressed: onUndo),
      ),
    );
}
