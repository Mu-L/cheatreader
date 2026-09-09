import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'reader_book.dart';

class ReaderBookshelfStorage {
  ReaderBookshelfStorage(this.resolveDirectory);

  final Future<Directory> Function() resolveDirectory;
  static final Map<String, Future<void>> _queues = {};

  Future<List<ReaderBookRecord>> load(List<ReaderBookRecord> legacyBooks) {
    return _transact(legacyBooks, (books) => books);
  }

  Future<List<ReaderBookRecord>> update(
    List<ReaderBookRecord> legacyBooks, {
    ReaderBookRecord? book,
    String? removePath,
    List<ReaderBookRecord>? replace,
    bool onlyIfPresent = false,
  }) {
    return _transact(legacyBooks, (books) {
      if (replace != null) return replace;
      final result = <String, ReaderBookRecord>{
        for (final item in books) item.path: item,
      };
      if (removePath != null) result.remove(removePath);
      if (book != null && (!onlyIfPresent || result.containsKey(book.path))) {
        result[book.path] = book;
      }
      return result.values.toList();
    });
  }

  Future<List<ReaderBookRecord>> _transact(
    List<ReaderBookRecord> legacyBooks,
    List<ReaderBookRecord> Function(List<ReaderBookRecord>) change,
  ) async {
    final directory = await resolveDirectory();
    await directory.create(recursive: true);
    final file = File('${directory.path}/bookshelf.json');
    final previous = _queues[file.absolute.path] ?? Future<void>.value();
    final operation = previous.then((_) async {
      final lock = await File('${file.path}.lock').open(mode: FileMode.append);
      File? temporary;
      try {
        // The file lock coordinates processes; the queue also covers callers
        // in the same process, where POSIX file locks are shared.
        await lock.lock(FileLock.blockingExclusive);
        final exists = await file.exists();
        final books = exists
            ? (jsonDecode(await file.readAsString()) as List<dynamic>)
                  .map(
                    (item) =>
                        ReaderBookRecord.fromJson(item as Map<String, dynamic>),
                  )
                  .toList()
            : legacyBooks;
        final updated = change(books);
        if (!exists || !identical(updated, books)) {
          temporary = File('${file.path}.$pid.tmp');
          await temporary.writeAsString(
            jsonEncode(updated.map((book) => book.toJson()).toList()),
            flush: true,
          );
          await temporary.rename(file.path);
        }
        return updated;
      } finally {
        try {
          if (temporary != null && await temporary.exists()) {
            await temporary.delete();
          }
        } finally {
          await lock.close();
        }
      }
    });
    final settled = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _queues[file.absolute.path] = settled;
    try {
      return await operation;
    } finally {
      if (identical(_queues[file.absolute.path], settled)) {
        _queues.remove(file.absolute.path);
      }
    }
  }
}
