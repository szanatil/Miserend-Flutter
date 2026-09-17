import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands a URI to whatever application the device has for it.
///
/// Mirrors how the map buttons already fail on this page: a device with no mail
/// client or browser gets a snackbar rather than a silent dead tap.
///
/// [launch] is injected by tests; the real one hands the URI to the device.
Future<void> launchExternal(
  BuildContext context,
  Uri uri, {
  Future<bool> Function(Uri uri)? launch,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened =
        launch != null
            ? await launch(uri)
            : await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Nem sikerült megnyitni.')),
    );
  }
}
