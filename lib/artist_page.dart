import 'package:flutter/material.dart';

import 'album_page.dart';
import 'artwork.dart';
import 'library.dart';
import 'mini_player.dart';
import 'player_hub.dart';
import 'theme.dart';
import 'widgets.dart';

class ArtistPage extends StatelessWidget {
  final ArtistInfo artist;
  const ArtistPage({super.key, required this.artist});

  @override
  Widget build(BuildContext context) {
    final hub = PlayerHub.instance;
    final songCount = artist.songs.length;
    final albumCount = artist.albums.length;

    return Scaffold(
      appBar: AppBar(),
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
            child: PlayShuffleRow(songs: artist.songs),
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
              onTap: () => hub.playSongs(artist.songs, i),
            ),
        ],
      ),
    );
  }
}
