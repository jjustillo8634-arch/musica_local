import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'album_page.dart';
import 'artist_page.dart';
import 'artwork.dart';
import 'library.dart';
import 'theme.dart';

void openArtistByName(BuildContext context, String name) {
  final artist = MusicLibrary.instance.artistByName(name);
  if (artist == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ArtistPage(artist: artist)),
  );
}

void openAlbum(BuildContext context, int? albumId) {
  final album = MusicLibrary.instance.albumById(albumId);
  if (album == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => AlbumPage(album: album)),
  );
}

/// Abre el artista de la canción. Si hay colaboradores, deja elegir uno.
Future<void> openArtistOfSong(BuildContext context, SongModel song) async {
  final names = splitArtists(song.artist);
  if (names.length == 1) {
    openArtistByName(context, names.first);
    return;
  }
  final picked = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Artistas de esta canción',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          for (final n in names)
            ListTile(
              leading: SizedBox(
                width: 44,
                height: 44,
                child: Artwork(
                  albumId: MusicLibrary.instance.artistByName(n)?.coverAlbumId,
                  circle: true,
                  px: 120,
                ),
              ),
              title: Text(n, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: kMuted),
              onTap: () => Navigator.pop(ctx, n),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (picked != null && context.mounted) openArtistByName(context, picked);
}
