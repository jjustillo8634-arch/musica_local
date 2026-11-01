import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'library.dart';

/// Cambios hechos por el usuario sobre una canción.
/// Se guardan dentro de la app: el archivo de audio no se modifica.
class SongOverride {
  String? title;
  String? artist;
  String? album;
  String? coverPath;

  SongOverride({this.title, this.artist, this.album, this.coverPath});

  bool get isEmpty =>
      title == null && artist == null && album == null && coverPath == null;

  Map<String, dynamic> toJson() => {
        if (title != null) 't': title,
        if (artist != null) 'a': artist,
        if (album != null) 'al': album,
        if (coverPath != null) 'c': coverPath,
      };

  factory SongOverride.fromJson(Map<String, dynamic> j) => SongOverride(
        title: j['t'] as String?,
        artist: j['a'] as String?,
        album: j['al'] as String?,
        coverPath: j['c'] as String?,
      );
}

class MetaStore extends ChangeNotifier {
  MetaStore._();
  static final MetaStore instance = MetaStore._();

  final Map<int, SongOverride> _songs = {};
  final Map<int, String> _albumCovers = {};
  final Map<String, String> _artistPhotos = {};
  Directory? _dir;

  Future<Directory> _imagesDir() async {
    final existing = _dir;
    if (existing != null) return existing;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/custom_covers');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('meta_v1');
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        (json['songs'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
          final id = int.tryParse(k);
          if (id != null) {
            _songs[id] = SongOverride.fromJson(Map<String, dynamic>.from(v as Map));
          }
        });
        (json['albums'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
          final id = int.tryParse(k);
          if (id != null) _albumCovers[id] = v as String;
        });
        (json['artists'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
          _artistPhotos[k] = v as String;
        });
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'meta_v1',
        jsonEncode({
          'songs': {for (final e in _songs.entries) '${e.key}': e.value.toJson()},
          'albums': {for (final e in _albumCovers.entries) '${e.key}': e.value},
          'artists': _artistPhotos,
        }),
      );
    } catch (_) {}
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ---------------- Lectura ----------------

  SongOverride? overrideOf(int songId) => _songs[songId];

  String titleOf(SongModel s) => _songs[s.id]?.title ?? s.title;
  String? artistOf(SongModel s) => _songs[s.id]?.artist ?? s.artist;
  String? albumOf(SongModel s) => _songs[s.id]?.album ?? s.album;

  String? _existing(String? path) =>
      (path != null && File(path).existsSync()) ? path : null;

  String? songCover(int songId) => _existing(_songs[songId]?.coverPath);
  String? albumCover(int albumId) => _existing(_albumCovers[albumId]);
  String? artistPhoto(String name) => _existing(_artistPhotos[name.toLowerCase()]);

  /// Portada personalizada de la canción (propia o de su álbum).
  String? coverPathFor(SongModel s) {
    final own = songCover(s.id);
    if (own != null) return own;
    final albumId = s.albumId;
    return albumId == null ? null : albumCover(albumId);
  }

  // ---------------- Imágenes ----------------

  /// Reduce la imagen elegida (máx. 900 px) y la guarda en la app.
  Future<String?> saveImage(String tempPath) async {
    try {
      final bytes = await File(tempPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 900);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      final dir = await _imagesDir();
      final file = File('${dir.path}/c_${DateTime.now().microsecondsSinceEpoch}.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      try {
        await File(tempPath).delete();
      } catch (_) {}
      return file.path;
    } catch (_) {
      return null;
    }
  }

  // ---------------- Escritura ----------------

  String? _clean(String? v, String? original) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (t == (original ?? '').trim()) return null;
    return t;
  }

  Future<void> saveSongEdits(
    SongModel song, {
    required String title,
    required String artist,
    required String album,
    String? newCoverTempPath,
    bool removeCover = false,
    bool applyCoverToAlbum = false,
  }) async {
    final o = _songs[song.id] ?? SongOverride();
    o.title = _clean(title, song.title);
    o.artist = _clean(artist, song.artist);
    o.album = _clean(album, song.album);

    if (removeCover) {
      o.coverPath = null;
      final albumId = song.albumId;
      if (applyCoverToAlbum && albumId != null) _albumCovers.remove(albumId);
    }
    if (newCoverTempPath != null) {
      final saved = await saveImage(newCoverTempPath);
      if (saved != null) {
        final albumId = song.albumId;
        if (applyCoverToAlbum && albumId != null) {
          _albumCovers[albumId] = saved;
          o.coverPath = null;
        } else {
          o.coverPath = saved;
        }
      }
    }

    if (o.isEmpty) {
      _songs.remove(song.id);
    } else {
      _songs[song.id] = o;
    }
    _changed();
  }

  void resetSong(int songId) {
    _songs.remove(songId);
    _changed();
  }

  Future<void> setArtistPhoto(String artistName, String tempPath) async {
    final saved = await saveImage(tempPath);
    if (saved == null) return;
    _artistPhotos[artistName.toLowerCase()] = saved;
    _changed();
  }

  void clearArtistPhoto(String artistName) {
    _artistPhotos.remove(artistName.toLowerCase());
    _changed();
  }

  /// Cambia el nombre de un artista en todas sus canciones. Si el nuevo
  /// nombre ya existe, los dos artistas se fusionan.
  void renameArtist(List<SongModel> songs, String oldName, String newName) {
    final clean = newName.trim();
    if (clean.isEmpty) return;
    final key = oldName.toLowerCase();

    for (final s in songs) {
      final parts = splitArtists(artistOf(s));
      if (!parts.any((p) => p.toLowerCase() == key)) continue;
      final updated = <String>[];
      for (final p in parts) {
        final name = p.toLowerCase() == key ? clean : p;
        if (!updated.any((u) => u.toLowerCase() == name.toLowerCase())) {
          updated.add(name);
        }
      }
      final o = _songs[s.id] ?? SongOverride();
      o.artist = updated.join(', ');
      _songs[s.id] = o;
    }

    final photo = _artistPhotos.remove(key);
    if (photo != null) _artistPhotos[clean.toLowerCase()] = photo;
    _changed();
  }
}

/// Nombres "visibles" de una canción (con los cambios del usuario aplicados).
extension SongMeta on SongModel {
  String get shownTitle => MetaStore.instance.titleOf(this);
  String? get rawArtist => MetaStore.instance.artistOf(this);
  String? get rawAlbum => MetaStore.instance.albumOf(this);
  String get shownArtist => cleanText(rawArtist, 'Artista desconocido');
  String get shownAlbum => cleanText(rawAlbum, '');
  String? get customCover => MetaStore.instance.coverPathFor(this);
}
