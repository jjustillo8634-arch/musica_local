import 'package:flutter/material.dart';

import 'library.dart';
import 'nav.dart';
import 'widgets.dart';
import 'album_page.dart';

class AlbumsPage extends StatelessWidget {
  const AlbumsPage({super.key});

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
              child: ScreenTitle('Álbumes'),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                itemCount: lib.albums.length,
                itemBuilder: (context, i) {
                  final album = lib.albums[i];
                  return AlbumCard(
                    album: album,
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
        ),
      ),
    );
  }
}
