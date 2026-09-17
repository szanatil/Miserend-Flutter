import 'package:miserend/widgets/feedback_mail.dart';

/// Records the mail each send would open instead of handing it to the device,
/// and opens it. The real [FeedbackLauncher.send] still builds the mail.
class FakeFeedbackLauncher extends FeedbackLauncher {
  factory FakeFeedbackLauncher() => FakeFeedbackLauncher._(<Uri>[]);

  FakeFeedbackLauncher._(this.launched)
    : super(
        launch: (uri) async {
          launched.add(uri);
          return true;
        },
      );

  final List<Uri> launched;
}
