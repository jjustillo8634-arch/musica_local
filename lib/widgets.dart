import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'artwork.dart';
import 'library.dart';
import 'player_hub.dart';
import 'theme.dart';

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
}

String fmtMs(int? ms) =>
    (ms == null || ms <= 0) ? '0:00' : fmtDuration(Duration(milliseconds: ms));

class ScreenTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const ScreenTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Fila de canción con portada, título, artista y duración.
class SongTile extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;
  final int? number;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: PlayerHub.instance.currentId,
      builder: (context, current, _) {
        final active = current == song.id;
        return ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: SizedBox(
            width: 48,
            height: 48,
            child: number != null
                ? Center(
                    child: Text(
                      '$number',
                      style: TextStyle(
                        color: active ? kRed : kMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Artwork(albumId: song.albumId, px: 150, radius: 8),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: active ? kRed : null,
            ),
          ),
          subtitle: Text(
            cleanText(song.artist, 'Artista desconocido'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kMuted),
          ),
          trailing: Text(
            fmtMs(song.duration),
            style: const TextStyle(color: kMuted, fontSize: 13),
          ),
        );
      },
    );
  }
}

/// Tarjeta cuadrada de canción (para listas horizontales).
class SongCard extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;
  const SongCard({super.key, required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Artwork(albumId: song.albumId, px: 400, radius: 12),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              cleanText(song.artist, 'Artista desconocido'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class AlbumCard extends StatelessWidget {
  final AlbumInfo album;
  final VoidCallback onTap;
  final double? width;
  const AlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Artwork(albumId: album.id, px: 400, radius: 12, iconSize: 40),
          ),
          const SizedBox(height: 8),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            album.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kMuted, fontSize: 13),
          ),
        ],
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}

class ArtistBubble extends StatelessWidget {
  final ArtistInfo artist;
  final VoidCallback onTap;
  const ArtistBubble({super.key, required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: Artwork(
                albumId: artist.coverAlbumId,
                circle: true,
                px: 250,
                iconSize: 36,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botones rojos "Reproducir" y "Aleatorio".
class PlayShuffleRow extends StatelessWidget {
  final List<SongModel> songs;
  const PlayShuffleRow({super.key, required this.songs});

  @override
  Widget build(BuildContext context) {
    final hub = PlayerHub.instance;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const padding = EdgeInsets.symmetric(vertical: 14);
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => hub.playSongs(songs, 0, shuffle: false),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Reproducir'),
            style: FilledButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              shape: shape,
              padding: padding,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => hub.shuffleAll(songs),
            icon: const Icon(Icons.shuffle),
            label: const Text('Aleatorio'),
            style: FilledButton.styleFrom(
              backgroundColor: kCardHi,
              foregroundColor: kRed,
              shape: shape,
              padding: padding,
            ),
          ),
        ),
      ],
    );
  }
}
