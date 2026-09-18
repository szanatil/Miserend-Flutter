import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where feedback about the app goes (CONTEXT.md, „Visszajelzés"). The
/// miserend.hu API has no endpoint for it and the app has no server, so the
/// channel is mail; only this changes if an endpoint appears (spec 0009).
const String feedbackAddress = 'szentjozsefhackathon@jezsuita.hu';

const String _feedbackSubject = 'Miserend app – visszajelzés';

/// The prefilled feedback mail: room for the user's words above a separator,
/// then the version and the platform. Nothing that identifies the device or
/// the user goes in (spec 0009, „Visszajelzés: a levél").
///
/// The query is encoded by hand: `Uri(queryParameters:)` turns spaces into
/// `+`, which several mail apps show literally.
Uri feedbackMailUri({
  required String version,
  required String buildNumber,
  required String operatingSystem,
  required String operatingSystemVersion,
}) {
  final body =
      '\n\n---\n'
      'Miserend app $version ($buildNumber)\n'
      '$operatingSystem $operatingSystemVersion';
  return Uri.parse(
    'mailto:$feedbackAddress'
    '?subject=${Uri.encodeComponent(_feedbackSubject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
}

/// Opens the mail app with the feedback mail, from the Névjegy page
/// (spec 0009).
class FeedbackLauncher {
  /// [launch] is injected by tests; the real one hands the URI to the device.
  FeedbackLauncher({Future<bool> Function(Uri uri)? launch})
    : _launch = launch ?? _launchExternally;

  final Future<bool> Function(Uri uri) _launch;

  static Future<bool> _launchExternally(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Without a mail app the user still gets the address to write to.
  Future<void> send(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      final info = await PackageInfo.fromPlatform();
      final uri = feedbackMailUri(
        version: info.version,
        buildNumber: info.buildNumber,
        operatingSystem: Platform.operatingSystem,
        operatingSystemVersion: Platform.operatingSystemVersion,
      );
      opened = await _launch(uri);
    } catch (error) {
      // The user can still write from any mail app with the address shown
      // below, so a failed launch is not an error to raise.
      debugPrint('Feedback mail not opened: ${error.runtimeType}');
    }
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Nincs levelezőprogram a telefonon. Írj nekünk: $feedbackAddress',
          ),
        ),
      );
    }
  }
}
