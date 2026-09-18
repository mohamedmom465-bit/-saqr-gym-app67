import 'dart:io';

/// Returns files under [root] whose paths are not present in [referencedPaths].
///
/// Callers should build referencedPaths from the current database before
/// deleting anything. This is intentionally a scanner only: it never deletes
/// user files automatically.
Future<List<File>> findUnreferencedFiles(
  Directory root,
  Set<String> referencedPaths,
) async {
  if (!await root.exists()) return <File>[];

  final result = <File>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File && !referencedPaths.contains(entity.path)) {
      result.add(entity);
    }
  }
  return result;
}
