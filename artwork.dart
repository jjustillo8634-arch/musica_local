import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'default_cover.dart';
import 'meta_store.dart';
import 'settings.dart';
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

/// Aplica la forma de portada elegida en Personalización
/// (redondeada, cuadrada o circular).
class CoverShaper extends StatelessWidget {
  final Widget child;
  final double radius;
  const CoverShaper({super.key, required this.child, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        switch (s.coverShape) {
          case CoverShape.circle:
            return ClipOval(child: child);
          case CoverShape.square:
            return ClipRect(child: child);
          case CoverShape.rounded:
            return ClipRRect(
              borderRadius: BorderRadius.circular(radius * s.roundness),
              child: child,
            );
        }
      },
    );
  }
}

/// Portada que se adapta al tamaño que le dé su contenedor.
/// Orden de búsqueda: foto personalizada → portada del álbum → portada roja.
class Artwork extends StatelessWidget {
  final int? albumId;
  final int? songId;
  final String? artistName;
  final int px;
  final double radius;
  final bool circle;
  final double iconSize;

  /// Si es false no aplica la forma global (para usar dentro de mosaicos).
  final bool shaped;

  const Artwork({
    super.key,
    required this.albumId,
    this.songId,
    this.artistName,
    this.px = 300,
    this.radius = 10,
    this.circle = false,
    this.iconSize = 28,
    this.shaped = true,
  });

  String? _customPath() {
    final meta = MetaStore.instance;
    if (artistName != null) return meta.artistPhoto(artistName!);
    if (songId != null) {
      final own = meta.songCover(songId!);
      if (own != null) return own;
    }
    final a = albumId;
    return a == null ? null : meta.albumCover(a);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MetaStore.instance,
      builder: (context, _) {
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

        Widget content;
        final custom = _customPath();
        if (custom != null) {
          content = Image.file(
            File(custom),
            fit: BoxFit.cover,
            cacheWidth: px,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => placeholder,
          );
        } else {
          content = FutureBuilder<Uint8List?>(
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
        }

        if (circle) return ClipOval(child: content);
        if (!shaped) {
          return radius <= 0
              ? content
              : ClipRRect(borderRadius: BorderRadius.circular(radius), child: content);
        }
        return CoverShaper(radius: radius, child: content);
      },
    );
  }
}
