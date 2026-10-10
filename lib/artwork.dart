import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'default_cover.dart';
import 'theme.dart';

final OnAudioQuery _artQuery = OnAudioQuery();
final Map<String, Future<Uint8List?>> _artCache = {};

/// Carga la portada de un álbum. Con [cache] activo se guarda en memoria.
Future<Uint8List?> loadAlbumArt(int? albumId, {int px = 300, bool cache = true}) {
  if (albumId == null) return Future.value(null);
  final key = '$albumId-$px';
  if (cache) {
    final cached = _artCache[key];
    if (cached != null) return cached;
    if (_artCache.length > 400) _artCache.remove(_artCache.keys.first);
  }
  final future = _artQuery
      .queryArtwork(
        albumId,
        ArtworkType.ALBUM,
        format: ArtworkFormat.JPEG,
        size: px,
      )
      .catchError((_) => null);
  if (cache) _artCache[key] = future;
  return future;
}

/// Portada que se adapta al tamaño que le dé su contenedor.
/// Si no hay portada muestra la portada roja por defecto.
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
    final Widget placeholder = circle
        ? Container(
            color: kCardHi,
            alignment: Alignment.center,
            child: Icon(Icons.person, color: Colors.white24, size: iconSize),
          )
        : Image.memory(
            kDefaultCoverBytes,
            fit: BoxFit.cover,
            cacheWidth: 300,
            gaplessPlayback: true,
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
