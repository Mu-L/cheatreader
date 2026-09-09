import 'dart:io';

import 'package:cheatreader/src/reader_import_service.dart';
import 'package:cheatreader/src/reader_library_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late PlatformReaderLibraryStorage storage;
  const imported = ImportedTextFile(
    path: '/original.txt',
    displayName: 'book',
    content: 'replacement text',
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reader-library-test-');
    storage = PlatformReaderLibraryStorage(baseDirectory: directory);
  });
  tearDown(() => directory.delete(recursive: true));

  test('replaces existing contents and leaves no temporary files', () async {
    final file = File('${directory.path}/stored.txt');
    await file.writeAsString('old contents');
    await storage.saveImportedFile(imported, existingStoredPath: file.path);
    expect(await file.readAsString(), imported.content);
    expect(await directory.list().length, 1);
  });

  test(
    'failed replacement preserves target and cleans up temporary file',
    () async {
      final target = await Directory('${directory.path}/stored.txt').create();
      final sentinel = File('${target.path}/sentinel');
      await sentinel.writeAsString('keep');
      await expectLater(
        storage.saveImportedFile(imported, existingStoredPath: target.path),
        throwsA(isA<FileSystemException>()),
      );
      expect(await sentinel.readAsString(), 'keep');
      expect(await directory.list().length, 1);
    },
  );
}
