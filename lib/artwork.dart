import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'theme.dart';

final OnAudioQuery _artQuery = OnAudioQuery();
final Map<String, Future<Uint8List?>> _artCache = {};

/// Carga (y guarda en caché) la portada de un álbum.
Future<Uint8List?> loadAlbumArt(int? albumId, {int px = 300}) {
  if (albumId == null) return Future.value(null);
  final key = '$albumId-$px';
  final cached = _artCache[key];
  if (cached != null) return cached;
  if (_artCache.length > 400) _artCache.remove(_artCache.keys.first);
  final future = _artQuery
      .queryArtwork(
        albumId,
        ArtworkType.ALBUM,
        format: ArtworkFormat.JPEG,
        size: px,
      )
      .catchError((_) => null);
  _artCache[key] = future;
  return future;
}

/// Portada que se adapta al tamaño que le dé su contenedor.
class Artwork extends StatelessWidget {
  final int? albumId;
  final int px;
  final double radius;
  final bool circle;
  final double iconSize;

  const Artwork({
    super.key,
    required this.albumId,
    this.px = 300,
    this.radius = 10,
    this.circle = false,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: kCardHi,
      alignment: Alignment.center,
      child: Icon(
        circle ? Icons.person : Icons.music_note,
        color: Colors.white24,
        size: iconSize,
      ),
    );

    final content = FutureBuilder<Uint8List?>(
      future: loadAlbumArt(albumId, px: px),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null || bytes.isEmpty) return placeholder;
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder,
        );
      },
    );

    return circle
        ? ClipOval(child: content)
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: content);
  }
}
