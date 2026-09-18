import 'dart:io';

enum DatabaseHealthStatus {
  missing,
  present,
  unreadable,
}

class DatabaseHealth {
  const DatabaseHealth({
    required this.status,
    this.message,
  });

  final DatabaseHealthStatus status;
  final String? message;

  bool get isUsable => status == DatabaseHealthStatus.present;
}

/// Checks the database file without replacing it or silently creating defaults.
Future<DatabaseHealth> inspectDatabaseFile(File file) async {
  try {
    if (!await file.exists()) {
      return const DatabaseHealth(status: DatabaseHealthStatus.missing);
    }

    final length = await file.length();
    if (length <= 0) {
      return const DatabaseHealth(
        status: DatabaseHealthStatus.unreadable,
        message: 'Database file is empty.',
      );
    }

    return const DatabaseHealth(status: DatabaseHealthStatus.present);
  } catch (e) {
    return DatabaseHealth(
      status: DatabaseHealthStatus.unreadable,
      message: 'Database inspection failed: $e',
    );
  }
}
