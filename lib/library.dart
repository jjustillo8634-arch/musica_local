import 'package:flutter/foundation.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

String cleanText(String? s, String fallback) {
  final t = s?.trim();
  if (t == null || t.isEmpty || t == '<unknown>') return fallback;
  return t;
}

/// Nombres que contienen separadores pero son UN solo artista.
const _keepTogether = <String>[
  'Simon & Garfunkel',
  'Earth, Wind & Fire',
  'Tyler, The Creator',
  'AC/DC',
  'Hall & Oates',
  'Brooks & Dunn',
  'Crosby, Stills, Nash & Young',
  'Crosby, Stills & Nash',
  'Sly & The Family Stone',
  'Mumford & Sons',
  'Years & Years',
  'Bob Marley & The Wailers',
  'Florence & The Machine',
  'Kool & The Gang',
  'Huey Lewis & The News',
  'Wisin & Yandel',
  'Jesse & Joy',
  'Chino & Nacho',
  'Zion & Lennox',
];

final RegExp _separators = RegExp(
  r'\s*(?:[,;&]|/|\s(?:feat\.?|ft\.?|featuring|con|with|x|vs\.?)\s)\s*',
  caseSensitive: false,
);

/// Separa "A feat. B", "A & B", "A, B"… en artistas individuales para que
/// una colaboración no cree una carpeta de artista aparte.
List<String> splitArtists(String? raw) {
  var text = cleanText(raw, '');
  if (text.isEmpty) return ['Artista desconocido'];

  final saved = <String>[];
  for (final name in _keepTogether) {
    final idx = text.toLowerCase().indexOf(name.toLowerCase());
    if (idx >= 0) {
      saved.add(text.substring(idx, idx + name.length));
      text = text.replaceRange(
        idx,
        idx + name.length,
        '\u0001${saved.length - 1}\u0001',
      );
    }
  }

  text = text.replaceAll(RegExp(r'[()\[\]]'), ' ');

  final seen = <String>{};
  final result = <String>[];
  for (var part in text.split(_separators)) {
    part = part.trim();
    if (part.isEmpty) continue;
    part = part.replaceAllMapped(
      RegExp('\u0001(\\d+)\u0001'),
      (m) => saved[int.parse(m.group(1)!)],
    );
    if (seen.add(part.toLowerCase())) result.add(part);
  }
  return result.isEmpty ? ['Artista desconocido'] : result;
}

class AlbumInfo {
  final int? id;
  final String name;
  final String artist;
  final List<SongModel> songs;

  AlbumInfo({
    required this.id,
    required this.name,
    required this.artist,
    required this.songs,
  });

  int get totalMs => songs.fold<int>(0, (a, s) => a + (s.duration ?? 0));
}

class ArtistInfo {
  final String name;
  final List<SongModel> songs;
  final List<AlbumInfo> albums;

  ArtistInfo({required this.name, required this.songs, required this.albums});

  int? get coverAlbumId => albums.isEmpty ? null : albums.first.id;
}

/// Biblioteca de música del teléfono (canciones, álbumes y artistas).
class MusicLibrary extends ChangeNotifier {
  MusicLibrary._();
  static final MusicLibrary instance = MusicLibrary._();

  final OnAudioQuery _query = OnAudioQuery();

  List<SongModel> songs = [];
  Map<int, SongModel> byId = {};
  List<AlbumInfo> albums = [];
  List<ArtistInfo> artists = [];
  Map<int, AlbumInfo> _albumById = {};

  bool loading = true;
  bool denied = false;

  AlbumInfo? albumById(int? id) => id == null ? null : _albumById[id];

  ArtistInfo? artistByName(String name) {
    final key = name.toLowerCase();
    for (final a in artists) {
      if (a.name.toLowerCase() == key) return a;
    }
    return null;
  }

  Future<void> load() async {
    loading = true;
    denied = false;
    notifyListeners();
    try {
      final ok = await _query.checkAndRequest(retryRequest: false);
      if (!ok) {
        denied = true;
        loading = false;
        notifyListeners();
        return;
      }
      final all = await _query.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      songs = all.where((s) => (s.isMusic ?? false) && s.uri != null).toList();
      _index();
    } catch (_) {
      songs = [];
      _index();
    }
    loading = false;
    notifyListeners();
  }

  void _index() {
    byId = {for (final s in songs) s.id: s};

    // ---- Álbumes ----
    final albumMap = <String, List<SongModel>>{};
    for (final s in songs) {
      final key = s.albumId != null
          ? 'id:${s.albumId}'
          : 'name:${cleanText(s.album, '').toLowerCase()}';
      (albumMap[key] ??= []).add(s);
    }
    final albumList = <AlbumInfo>[];
    for (final list in albumMap.values) {
      list.sort((a, b) => a.data.compareTo(b.data));
      final counts = <String, int>{};
      for (final s in list) {
        final first = splitArtists(s.artist).first;
        counts[first] = (counts[first] ?? 0) + 1;
      }
      final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
      albumList.add(
        AlbumInfo(
          id: list.first.albumId,
          name: cleanText(list.first.album, 'Álbum desconocido'),
          artist: top,
          songs: list,
        ),
      );
    }
    albumList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    albums = albumList;
    _albumById = {
      for (final a in albumList)
        if (a.id != null) a.id!: a,
    };

    // ---- Artistas (cada colaborador cuenta por separado) ----
    final artistSongs = <String, List<SongModel>>{};
    final display = <String, String>{};
    for (final s in songs) {
      for (final name in splitArtists(s.artist)) {
        final k = name.toLowerCase();
        display.putIfAbsent(k, () => name);
        (artistSongs[k] ??= []).add(s);
      }
    }
    final artistList = <ArtistInfo>[];
    artistSongs.forEach((k, list) {
      final seen = <AlbumInfo>{};
      final theirAlbums = <AlbumInfo>[];
      for (final s in list) {
        final a = albumById(s.albumId);
        if (a != null && seen.add(a)) theirAlbums.add(a);
      }
      artistList.add(
        ArtistInfo(name: display[k]!, songs: list, albums: theirAlbums),
      );
    });
    artistList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    artists = artistList;
  }
}
