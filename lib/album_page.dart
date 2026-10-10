import 'package:flutter/material.dart';

import 'artwork.dart';
import 'library.dart';
import 'mini_player.dart';
import 'nav.dart';
import 'player_hub.dart';
import 'theme.dart';
import 'widgets.dart';

class AlbumPage extends StatelessWidget {
  final AlbumInfo album;
  const AlbumPage({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    final hub = PlayerHub.instance;
    final minutes = (album.totalMs / 60000).round();
    final count = album.songs.length;

    return Scaffold(
      appBar: AppBar(),
      bottomNavigationBar: const MiniPlayer(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Artwork(albumId: album.id, px: 700, radius: 18, iconSize: 80),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              album.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => openArtistByName(context, album.artist),
            child: Text(
              album.artist,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, color: kRed),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count ${count == 1 ? 'canción' : 'canciones'} · $minutes min',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: PlayShuffleRow(songs: album.songs),
          ),
          for (var i = 0; i < album.songs.length; i++)
            SongTile(
              song: album.songs[i],
              number: i + 1,
              onTap: () => hub.playSongs(album.songs, i),
            ),
        ],
      ),
    );
  }
}
