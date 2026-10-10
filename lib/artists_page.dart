import 'package:flutter/material.dart';

import 'artwork.dart';
import 'library.dart';
import 'nav.dart';
import 'theme.dart';
import 'widgets.dart';

class ArtistsPage extends StatelessWidget {
  const ArtistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = MusicLibrary.instance;

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: lib,
        builder: (context, _) => Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: ScreenTitle('Artistas'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: lib.artists.length,
                itemBuilder: (context, i) {
                  final a = lib.artists[i];
                  final n = a.songs.length;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: SizedBox(
                      width: 52,
                      height: 52,
                      child: Artwork(
                        albumId: a.coverAlbumId,
                        circle: true,
                        px: 200,
                        iconSize: 26,
                      ),
                    ),
                    title: Text(
                      a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$n ${n == 1 ? 'canción' : 'canciones'}',
                      style: const TextStyle(color: kMuted),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: kMuted),
                    onTap: () => openArtistByName(context, a.name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
