import 'dart:collection';

import 'package:miserend/location_provider.dart';

/// A position without the phone's location service. Each call takes the next
/// answer; the last one repeats.
class FakeLocationProvider extends LocationProvider {
  FakeLocationProvider([
    List<PositionResult> answers = const [
      PositionUnavailable(PositionUnavailableReason.noFreshFix),
    ],
  ]) : _answers = Queue.of(answers);

  final Queue<PositionResult> _answers;
  int calls = 0;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  @override
  Future<PositionResult> currentPosition() async {
    calls++;
    return _answers.length > 1 ? _answers.removeFirst() : _answers.first;
  }

  @override
  Future<void> openAppSettings() async => appSettingsOpened++;

  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;
}
