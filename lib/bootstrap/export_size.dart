/// The SQLite export's size as the user reads it: megabytes to one decimal,
/// with a decimal comma, „21,8 MB" (spec 0015, „Méretformázás").
abstract final class ExportSize {
  /// Decimal megabytes, as the phones' own storage screens count them.
  static const int _bytesPerMegabyte = 1000 * 1000;

  /// Said when the size did not come back: the export was about this large
  /// when spec 0015 was written, and grows slowly.
  static const int _approximateMegabytes = 22;

  /// „21,8".
  static String megabytes(int bytes) =>
      (bytes / _bytesPerMegabyte).toStringAsFixed(1).replaceAll('.', ',');

  /// „21,8 MB", or „kb. 22 MB" when [bytes] is not known.
  static String label(int? bytes) =>
      bytes == null ? approximate : '${megabytes(bytes)} MB';

  /// What stands for the size while it is not known.
  static const String approximate = 'kb. $_approximateMegabytes MB';
}
