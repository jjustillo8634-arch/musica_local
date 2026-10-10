import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'artwork.dart' show loadAlbumArt;
import 'default_cover.dart';

/// Guarda las portadas como archivos para que la notificación y la pantalla
/// de bloqueo de Android puedan mostrarlas.
class ArtCache {
  ArtCache._();

  static late Directory _dir;
  static bool _ready = false;
  static final Map<int, Future<void>> _inflight = {};

  static Future<void> init() async {
    if (_ready) return;
    try {
      final base = await getTemporaryDirectory();
      _dir = Directory('${base.path}/covers');
      if (!await _dir.exists()) await _dir.create(recursive: true);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static File _file(int? albumId) => File(
        '${_dir.path}/${albumId == null ? 'default' : 'art_$albumId'}.jpg',
      );

  /// URI del archivo de portada (aún puede no existir: usa [ensure]).
  static Uri? uriFor(int? albumId) => _ready ? _file(albumId).uri : null;

  /// Se asegura de que exista el archivo de portada del álbum.
  static Future<void> ensure(int? albumId) {
    if (!_ready) return Future.value();
    return _inflight[albumId ?? -1] ??= _write(albumId);
  }

  static Future<void> _write(int? albumId) async {
    try {
      final f = _file(albumId);
      if (await f.exists() && await f.length() > 0) return;
      Uint8List? bytes;
      if (albumId != null) {
        bytes = await loadAlbumArt(albumId, px: 512, cache: false);
      }
      if (bytes == null || bytes.isEmpty) bytes = kDefaultCoverBytes;
      await f.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  /// Prepara en segundo plano las portadas de muchos álbumes.
  static Future<void> warm(Iterable<int?> albumIds) async {
    final ids = albumIds.toSet().toList();
    for (var i = 0; i < ids.length; i += 6) {
      await Future.wait(ids.skip(i).take(6).map(ensure));
    }
  }
}
