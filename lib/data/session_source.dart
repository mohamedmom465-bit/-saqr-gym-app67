/// Identifies how a workout session was created.
/// Keeping this separate from user-editable notes avoids treating text as data.
enum SessionSource {
  manual,
  quickLog,
}

extension SessionSourceCodec on SessionSource {
  String get value => switch (this) {
        SessionSource.manual => 'manual',
        SessionSource.quickLog => 'quick_log',
      };

  static SessionSource fromValue(String? value) =>
      value == 'quick_log' ? SessionSource.quickLog : SessionSource.manual;
}
