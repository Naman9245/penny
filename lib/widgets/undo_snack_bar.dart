import 'package:flutter/material.dart';

/// Shows [message] with an Undo action.
///
/// Flutter keeps a snack bar with an action up until it's dismissed. An undo
/// offer should fade on its own, except for screen-reader users, who need
/// time to reach the button.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        persist: MediaQuery.accessibleNavigationOf(context),
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
      ),
    );
}
