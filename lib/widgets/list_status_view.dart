import 'package:flutter/material.dart';

/// Full-page spinner with a caption, shown while a list is still being built.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Betöltés...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(message),
          ),
        ],
      ),
    );
  }
}

/// Full-page message, shown when a list has nothing to display.
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
