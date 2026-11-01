import 'package:flutter/material.dart';

import 'album_page.dart';
import 'artwork.dart';
import 'library.dart';
import 'meta_store.dart';
import 'mini_player.dart';
import 'platform_bridge.dart';
import 'player_hub.dart';
import 'theme.dart';
import 'widgets.dart';

class ArtistPage extends StatelessWidget {
  final ArtistInfo artist;
  const ArtistPage({super.key, required this.artist});

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: artist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Renombrar artista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            const SizedBox(height: 10),
            const Text(
              'Se cambia en todas sus canciones. Si pones el nombre de otro artista, se fusionan.',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    MetaStore.instance.renameArtist(MusicLibrary.instance.songs, artist.name, name);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hub = PlayerHub.instance;
    final songCount = artist.songs.length;
    final albumCount = artist.albums.length;

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            color: kCardHi,
            onSelected: (v) async {
              if (v == 'photo') {
                final path = await PlatformBridge.pickImage();
                if (path != null) {
                  await MetaStore.instance.setArtistPhoto(artist.name, path);
                }
              } else if (v == 'clear') {
                MetaStore.instance.clearArtistPhoto(artist.name);
              } else if (v == 'rename') {
                await _rename(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'photo', child: Text('Cambiar foto del artista')),
              PopupMenuItem(value: 'clear', child: Text('Quitar foto personalizada')),
              PopupMenuItem(value: 'rename', child: Text('Renombrar artista')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Center(
            child: SizedBox(
              width: 190,
              height: 190,
              child: Artwork(
                albumId: artist.coverAlbumId,
                artistName: artist.name,
                circle: true,
                px: 600,
                iconSize: 80,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              artist.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$songCount ${songCount == 1 ? 'canción' : 'canciones'} · '
            '$albumCount ${albumCount == 1 ? 'álbum' : 'álbumes'}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: PlayShuffleRow(songs: artist.songs, source: artist.name),
          ),
          if (artist.albums.isNotEmpty) ...[
            const SectionTitle('Álbumes'),
            SizedBox(
              height: 215,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: artist.albums.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final album = artist.albums[i];
                  return AlbumCard(
                    album: album,
                    width: 150,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AlbumPage(album: album),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SectionTitle('Canciones'),
          for (var i = 0; i < artist.songs.length; i++)
            SongTile(
              song: artist.songs[i],
              onTap: () => hub.playSongs(artist.songs, i, source: artist.name),
            ),
        ],
      ),
    );
  }
}
