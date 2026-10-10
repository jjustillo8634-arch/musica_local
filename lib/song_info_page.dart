import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'artwork.dart';
import 'library.dart';
import 'mini_player.dart';
import 'nav.dart';
import 'theme.dart';
import 'widgets.dart';

/// Pantalla extra con la foto, el nombre y los datos de la canción,
/// su(s) artista(s) y su álbum.
class SongInfoPage extends StatelessWidget {
  final SongModel song;
  const SongInfoPage({super.key, required this.song});

  String _format() {
    final dot = song.data.lastIndexOf('.');
    if (dot < 0 || dot == song.data.length - 1) return 'Desconocido';
    return song.data.substring(dot + 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final lib = MusicLibrary.instance;
    final artists = splitArtists(song.artist);
    final album = lib.albumById(song.albumId);
    final albumName = cleanText(song.album, 'Álbum desconocido');
    final sizeMb = (song.size / (1024 * 1024)).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(title: const Text('Información')),
      bottomNavigationBar: const MiniPlayer(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Artwork(albumId: song.albumId, px: 700, radius: 20, iconSize: 80),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              song.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              artists.join(', '),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, color: kMuted),
            ),
          ),

          // ---- Artistas ----
          SectionTitle(artists.length == 1 ? 'Artista' : 'Artistas'),
          for (final name in artists)
            Builder(
              builder: (context) {
                final info = lib.artistByName(name);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: SizedBox(
                    width: 56,
                    height: 56,
                    child: Artwork(
                      albumId: info?.coverAlbumId,
                      circle: true,
                      px: 200,
                      iconSize: 28,
                    ),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    info == null
                        ? ''
                        : '${info.songs.length} ${info.songs.length == 1 ? 'canción' : 'canciones'}',
                    style: const TextStyle(color: kMuted),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: kMuted),
                  onTap: () => openArtistByName(context, name),
                );
              },
            ),

          // ---- Álbum ----
          const SectionTitle('Álbum'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: SizedBox(
              width: 56,
              height: 56,
              child: Artwork(albumId: song.albumId, px: 200, radius: 8),
            ),
            title: Text(albumName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              album == null
                  ? ''
                  : '${album.songs.length} ${album.songs.length == 1 ? 'canción' : 'canciones'}',
              style: const TextStyle(color: kMuted),
            ),
            trailing: album == null
                ? null
                : const Icon(Icons.chevron_right, color: kMuted),
            onTap: album == null ? null : () => openAlbum(context, song.albumId),
          ),

          // ---- Detalles ----
          const SectionTitle('Detalles'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _InfoRow('Duración', fmtMs(song.duration)),
                  _InfoRow('Formato', _format()),
                  _InfoRow('Tamaño', '$sizeMb MB'),
                  _InfoRow('Ubicación', song.data),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: kMuted)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
