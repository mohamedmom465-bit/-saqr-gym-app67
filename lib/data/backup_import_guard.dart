import 'dart:io';

/// Validates a backup envelope before it is allowed to replace application data.
class BackupImportGuard {
  static const int supportedFormat = 2;

  static void validateEnvelope(Map<String, dynamic> json) {
    final format = json['backupFormat'];
    if (format is! int || format != supportedFormat) {
      throw FormatException(
        'Unsupported backup version: ${format ?? 'missing'}',
      );
    }

    final createdAt = json['createdAt'];
    if (createdAt is! String || createdAt.isEmpty) {
      throw FormatException('Backup createdAt is missing or invalid.');
    }
  }

  /// Creates an isolated staging directory. Nothing in the live storage
  /// location is touched until the caller finishes validation.
  static Future<Directory> createStagingDirectory(Directory parent) async {
    await parent.create(recursive: true);
    return Directory(
      '${parent.path}${Platform.pathSeparator}.backup_import_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
  }

  static Future<void> cleanup(Directory staging) async {
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
  }
}
