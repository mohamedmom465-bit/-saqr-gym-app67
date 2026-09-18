import 'dart:io';

/// Writes a file through a temporary sibling and replaces the destination only
/// after the complete payload has been flushed to disk.
Future<void> atomicWriteBytes(File destination, List<int> bytes) async {
  final parent = destination.parent;
  await parent.create(recursive: true);

  final tmp = File('${destination.path}.tmp');
  await tmp.writeAsBytes(bytes, flush: true);

  if (await destination.exists()) {
    await destination.delete();
  }
  await tmp.rename(destination.path);
}

/// Removes a temporary atomic-write file left by an interrupted operation.
Future<void> cleanupAtomicTemp(File destination) async {
  final tmp = File('${destination.path}.tmp');
  if (await tmp.exists()) {
    await tmp.delete();
  }
}
