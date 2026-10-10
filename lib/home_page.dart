import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'library.dart';
import 'nav.dart';
import 'player_hub.dart';
import 'playlist_widgets.dart';
import 'playlists.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = MusicLibrary.instance;
    final hub = PlayerHub.instance;
    final playlists = PlaylistStore.instance;

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([lib, hub, playlists]),
        builder: (context, _) {
          final recents = [
            for (final id in hub.recentIds)
              if (lib.byId[id] != null) lib.byId[id]!,
          ];
          final favorites = [
            for (final id in hub.favorites)
              if (lib.byId[id] != null) lib.byId[id]!,
          ];
          final topArtists = ([...lib.artists]
                ..sort((a, b) => b.songs.length.compareTo(a.songs.length)))
              .take(12)
              .toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ScreenTitle(
                'Escuchar',
                trailing: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Ajustes',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                  ),
                ),
              ),
              if (topArtists.isNotEmpty) ...[
                const SectionTitle('Artistas'),
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: topArtists.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) => ArtistBubble(
                      artist: topArtists[i],
                      onTap: () => openArtistByName(context, topArtists[i].name),
                    ),
                  ),
                ),
              ],
              SectionTitle(
                'Playlists',
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: kRed),
                  tooltip: 'Nueva playlist',
                  onPressed: () => createPlaylistFlow(context),
                ),
              ),
              SizedBox(
                height: 215,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: playlists.playlists.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => i == 0
                      ? const NewPlaylistCard()
                      : PlaylistCard(playlist: playlists.playlists[i - 1]),
                ),
              ),
              const SectionTitle('Escuchadas recientemente'),
              if (recents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Aquí aparecerá lo último que reproduzcas.',
                    style: TextStyle(color: kMuted),
                  ),
                )
              else
                _SongRow(songs: recents),
              if (favorites.isNotEmpty) ...[
                const SectionTitle('Favoritas'),
                _SongRow(songs: favorites),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  final List<SongModel> songs;
  const _SongRow({required this.songs});

  @override
  Widget build(BuildContext context) {
    final hub = PlayerHub.instance;
    return SizedBox(
      height: 215,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) => SongCard(
          song: songs[i],
          onTap: () => hub.playSongs(songs, i),
        ),
      ),
    );
  }
}
