import 'dart:io';

/// Creates a rollback copy of a live SQLite file before a restore/import.
/// The caller should delete the rollback file only after the new state has
/// been opened and validated successfully.
Future<File?> createRestoreRollback(File liveDb) async {
  if (!await liveDb.exists()) return null;

  final rollback = File(
    '${liveDb.path}.rollback_${DateTime.now().microsecondsSinceEpoch}',
  );
  await liveDb.copy(rollback.path);
  return rollback;
}

Future<void> deleteRestoreRollback(File? rollback) async {
  if (rollback != null && await rollback.exists()) {
    await rollback.delete();
  }
}
