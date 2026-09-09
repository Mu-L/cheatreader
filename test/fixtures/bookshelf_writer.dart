import 'dart:io';

import 'package:cheatreader/src/reader_book.dart';
import 'package:cheatreader/src/reader_bookshelf_storage.dart';

Future<void> main(List<String> args) async {
  final storage = ReaderBookshelfStorage(() async => Directory(args[0]));
  for (var index = 0; index < 20; index++) {
    await storage.update(
      [],
      book: ReaderBookRecord(
        path: '${args[1]}-$index.txt',
        displayName: '${args[1]}-$index',
        lastOpenedAt: DateTime.now(),
        lastReadLineIndex: index,
        burnedLineCount: 0,
        burnModeEnabled: false,
      ),
    );
  }
}
