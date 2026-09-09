import 'dart:io';

import 'package:cheatreader/src/reader_book.dart';
import 'package:cheatreader/src/reader_bookshelf_storage.dart';
import 'package:flutter_test/flutter_test.dart';

ReaderBookRecord book(String path, [int progress = 0]) => ReaderBookRecord(
  path: path,
  displayName: path,
  lastOpenedAt: DateTime.now(),
  lastReadLineIndex: progress,
  burnedLineCount: 0,
  burnModeEnabled: false,
);

void main() {
  late Directory directory;
  late ReaderBookshelfStorage storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reader-bookshelf-test-');
    storage = ReaderBookshelfStorage(() async => directory);
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'migrates legacy bookshelf once and never resurrects removed books',
    () async {
      final legacy = [book('old.txt', 17)];
      expect((await storage.load(legacy)).single.lastReadLineIndex, 17);
      await storage.update(legacy, removePath: 'old.txt');
      await storage.update(
        legacy,
        book: book('old.txt', 18),
        onlyIfPresent: true,
      );
      expect(await storage.load(legacy), isEmpty);
    },
  );

  test(
    'independent stores preserve each others entries and progress',
    () async {
      final other = ReaderBookshelfStorage(() async => directory);
      await Future.wait([
        storage.update([], book: book('first.txt', 12)),
        other.update([], book: book('second.txt', 34)),
      ]);
      await other.update([], book: book('second.txt', 56), onlyIfPresent: true);
      final books = {
        for (final item in await storage.load([])) item.path: item,
      };
      expect(books['first.txt']!.lastReadLineIndex, 12);
      expect(books['second.txt']!.lastReadLineIndex, 56);
    },
  );

  test('real competing processes retain all committed records', () async {
    final results = await Future.wait([
      Process.run('dart', [
        'test/fixtures/bookshelf_writer.dart',
        directory.path,
        'a',
      ]),
      Process.run('dart', [
        'test/fixtures/bookshelf_writer.dart',
        directory.path,
        'b',
      ]),
    ]);
    for (final result in results) {
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }
    expect((await storage.load([])).length, 40);
  });
}
