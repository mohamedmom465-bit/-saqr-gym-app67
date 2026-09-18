/// Central contract for persisted-data versions.
///
/// Keep these values in sync with Drift schema migrations and backupFormat.
/// This file is intentionally dependency-free so it can be checked during
/// startup/tests without opening the database.
class MigrationContract {
  static const int currentSchemaVersion = 1;
  static const int minimumSupportedBackupFormat = 2;
  static const int maximumSupportedBackupFormat = 2;

  static bool isSupportedBackupFormat(int value) =>
      value >= minimumSupportedBackupFormat &&
      value <= maximumSupportedBackupFormat;
}
