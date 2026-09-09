import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'reader_import_service.dart';

class StoredReaderFile {
  const StoredReaderFile({required this.path});

  final String path;
}

abstract class ReaderLibraryStorage {
  Future<StoredReaderFile> saveImportedFile(
    ImportedTextFile file, {
    String? existingStoredPath,
  });

  Future<void> deleteStoredFile(String storedPath);
}

class PlatformReaderLibraryStorage implements ReaderLibraryStorage {
  PlatformReaderLibraryStorage({Directory? baseDirectory})
    : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;
  static const _libraryFolderName = 'library';

  @override
  Future<StoredReaderFile> saveImportedFile(
    ImportedTextFile file, {
    String? existingStoredPath,
  }) async {
    final baseDirectory = await resolveBaseDirectory();
    await baseDirectory.create(recursive: true);

    final targetPath =
        existingStoredPath ??
        path.join(
          baseDirectory.path,
          '${DateTime.now().microsecondsSinceEpoch}_${_slugify(file.displayName)}.txt',
        );
    final targetFile = File(targetPath);
    final temporaryFile = File(
      '$targetPath.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await temporaryFile.writeAsString(
        file.content,
        encoding: utf8,
        flush: true,
      );
      await temporaryFile.rename(targetPath);
    } finally {
      if (await temporaryFile.exists()) await temporaryFile.delete();
    }
    return StoredReaderFile(path: targetFile.path);
  }

  @override
  Future<void> deleteStoredFile(String storedPath) async {
    final file = File(storedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> resolveBaseDirectory() async {
    if (_baseDirectory case final directory?) return directory;
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) {
        throw StateError('HOME is unavailable');
      }
      return Directory(
        path.join(
          home,
          'Library',
          'Application Support',
          'CheatReader',
          _libraryFolderName,
        ),
      );
    }

    if (Platform.isLinux) {
      final dataHome = Platform.environment['XDG_DATA_HOME'];
      final home = Platform.environment['HOME'];
      final root = dataHome?.isNotEmpty == true
          ? dataHome!
          : path.join(home ?? Directory.current.path, '.local', 'share');
      return Directory(path.join(root, 'cheatreader', _libraryFolderName));
    }

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      final root = appData?.isNotEmpty == true
          ? appData!
          : Directory.current.path;
      return Directory(path.join(root, 'CheatReader', _libraryFolderName));
    }

    return Directory(
      path.join(Directory.systemTemp.path, 'cheatreader', _libraryFolderName),
    );
  }

  String _slugify(String value) {
    final normalized = value
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'reader' : normalized;
  }
}

class MemoryReaderLibraryStorage implements ReaderLibraryStorage {
  MemoryReaderLibraryStorage({Map<String, String>? initialFiles})
    : files = Map<String, String>.from(
        initialFiles ?? const <String, String>{},
      );

  final Map<String, String> files;
  var _counter = 0;

  @override
  Future<StoredReaderFile> saveImportedFile(
    ImportedTextFile file, {
    String? existingStoredPath,
  }) async {
    final storedPath =
        existingStoredPath ?? '/library/${_counter++}_${file.displayName}';
    files[storedPath] = file.content;
    return StoredReaderFile(path: storedPath);
  }

  @override
  Future<void> deleteStoredFile(String storedPath) async {
    files.remove(storedPath);
  }
}
