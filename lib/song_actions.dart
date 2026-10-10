import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'artwork.dart';
import 'library.dart';
import 'nav.dart';
import 'player_hub.dart';
import 'playlist_widgets.dart';
import 'song_info_page.dart';
import 'theme.dart';

/// Menú de acciones de una canción (cola, playlists, favorita, ir a…).
void showSongActions(BuildContext context, SongModel song) {
  final hub = PlayerHub.instance;

  void toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: ListenableBuilder(
          listenable: hub,
          builder: (ctx, _) {
            final fav = hub.isFavorite(song.id);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  leading: SizedBox(
                    width: 52,
                    height: 52,
                    child: Artwork(albumId: song.albumId, px: 200, radius: 8),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    cleanText(song.artist, 'Artista desconocido'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kMuted),
                  ),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: const Text('Reproducir a continuación'),
                  onTap: () {
                    Navigator.pop(ctx);
                    hub.playNext(song);
                    toast('Se reproducirá a continuación');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: const Text('Añadir al final de la cola'),
                  onTap: () {
                    Navigator.pop(ctx);
                    hub.addToQueue(song);
                    toast('Añadida a la cola');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: const Text('Añadir a una playlist'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showAddToPlaylistSheet(context, [song.id]);
                  },
                ),
                ListTile(
                  leading: Icon(
                    fav ? Icons.favorite : Icons.favorite_border,
                    color: fav ? kRed : null,
                  ),
                  title: Text(fav ? 'Quitar de favoritas' : 'Añadir a favoritas'),
                  onTap: () {
                    hub.toggleFavorite(song.id);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Ir al artista'),
                  onTap: () {
                    Navigator.pop(ctx);
                    openArtistOfSong(context, song);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.album_outlined),
                  title: const Text('Ir al álbum'),
                  onTap: () {
                    Navigator.pop(ctx);
                    openAlbum(context, song.albumId);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Información de la canción'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SongInfoPage(song: song),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    ),
  );
}
