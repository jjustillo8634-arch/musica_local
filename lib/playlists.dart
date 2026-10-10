import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'library.dart';

class Playlist {
  final String id;
  String name;
  final List<int> songIds;

  Playlist({required this.id, required this.name, List<int>? songIds})
      : songIds = songIds ?? [];

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'songs': songIds};

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        songIds: (json['songs'] as List)
            .map((e) => (e as num).toInt())
            .toList(),
      );
}

/// Playlists creadas por el usuario (se guardan en el teléfono).
class PlaylistStore extends ChangeNotifier {
  PlaylistStore._();
  static final PlaylistStore instance = PlaylistStore._();

  final List<Playlist> playlists = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('playlists_v1');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        playlists
          ..clear()
          ..addAll(
            list.map((e) => Playlist.fromJson(Map<String, dynamic>.from(e as Map))),
          );
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'playlists_v1',
        jsonEncode(playlists.map((p) => p.toJson()).toList()),
      );
    } catch (_) {}
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  Playlist? byId(String id) {
    for (final p in playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  Playlist create(String name, {Iterable<int> songIds = const []}) {
    final clean = name.trim();
    final p = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: clean.isEmpty ? 'Mi playlist' : clean,
      songIds: songIds.toSet().toList(),
    );
    playlists.add(p);
    _changed();
    return p;
  }

  void rename(Playlist p, String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    p.name = clean;
    _changed();
  }

  void delete(Playlist p) {
    playlists.remove(p);
    _changed();
  }

  /// Añade canciones sin repetir las que ya están. Devuelve cuántas añadió.
  int addSongs(Playlist p, Iterable<int> ids) {
    var added = 0;
    for (final id in ids) {
      if (!p.songIds.contains(id)) {
        p.songIds.add(id);
        added++;
      }
    }
    if (added > 0) _changed();
    return added;
  }

  void removeSong(Playlist p, int id) {
    p.songIds.remove(id);
    _changed();
  }

  /// Reemplaza el orden de la playlist por [orderedIds].
  void setOrder(Playlist p, List<int> orderedIds) {
    p.songIds
      ..clear()
      ..addAll(orderedIds);
    _changed();
  }

  /// Canciones de la playlist que siguen existiendo en el teléfono.
  List<SongModel> songsOf(Playlist p) {
    final lib = MusicLibrary.instance;
    return [
      for (final id in p.songIds)
        if (lib.byId[id] != null) lib.byId[id]!,
    ];
  }
}
