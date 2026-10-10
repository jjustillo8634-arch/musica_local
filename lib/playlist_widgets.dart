import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'artwork.dart';
import 'playlist_page.dart';
import 'playlists.dart';
import 'theme.dart';

/// Portada de una playlist: mosaico de hasta 4 portadas.
class PlaylistCover extends StatelessWidget {
  final List<SongModel> songs;
  final double radius;
  const PlaylistCover({super.key, required this.songs, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final ids = <int>[];
    for (final s in songs) {
      final id = s.albumId;
      if (id != null && !ids.contains(id)) ids.add(id);
      if (ids.length == 4) break;
    }

    Widget content;
    if (songs.isEmpty) {
      content = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF5E72), Color(0xFFFA233B)],
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.queue_music, color: Colors.white, size: 44),
      );
    } else if (ids.length < 4) {
      content = Artwork(albumId: ids.isEmpty ? null : ids.first, px: 400, radius: 0);
    } else {
      content = Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: Artwork(albumId: ids[0], px: 250, radius: 0)),
                Expanded(child: Artwork(albumId: ids[1], px: 250, radius: 0)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Artwork(albumId: ids[2], px: 250, radius: 0)),
                Expanded(child: Artwork(albumId: ids[3], px: 250, radius: 0)),
              ],
            ),
          ),
        ],
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: content);
  }
}

/// Tarjeta de playlist para la pantalla Escuchar.
class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  const PlaylistCard({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final songs = PlaylistStore.instance.songsOf(playlist);
    return SizedBox(
      width: 140,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openPlaylist(context, playlist),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 1, child: PlaylistCover(songs: songs)),
            const SizedBox(height: 8),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${songs.length} ${songs.length == 1 ? 'canción' : 'canciones'}',
              style: const TextStyle(color: kMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primera tarjeta de la fila: crear una playlist nueva.
class NewPlaylistCard extends StatelessWidget {
  const NewPlaylistCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => createPlaylistFlow(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kRed.withAlpha(120), width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, color: kRed, size: 44),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nueva playlist',
              style: TextStyle(fontWeight: FontWeight.w600, color: kRed),
            ),
            const Text(
              'Crea la tuya',
              style: TextStyle(color: kMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pide un nombre, crea la playlist y abre su página.
Future<void> createPlaylistFlow(
  BuildContext context, {
  List<int> initialIds = const [],
}) async {
  final p = await promptNewPlaylist(context, initialIds: initialIds);
  if (p != null && context.mounted) openPlaylist(context, p);
}

Future<Playlist?> promptNewPlaylist(
  BuildContext context, {
  List<int> initialIds = const [],
}) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kCard,
      title: const Text('Nueva playlist'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nombre de la playlist'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar', style: TextStyle(color: kMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Crear', style: TextStyle(color: kRed)),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null) return null;
  return PlaylistStore.instance.create(name, songIds: initialIds);
}

/// Hoja para añadir canciones a una playlist existente (o a una nueva).
void showAddToPlaylistSheet(BuildContext context, List<int> songIds) {
  final store = PlaylistStore.instance;
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
          listenable: store,
          builder: (ctx, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Añadir a una playlist',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: kRed,
                  child: Icon(Icons.add, color: Colors.white),
                ),
                title: const Text(
                  'Nueva playlist',
                  style: TextStyle(color: kRed, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  final p = await promptNewPlaylist(ctx, initialIds: songIds);
                  if (p != null && ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Añadida a "${p.name}"')),
                    );
                  }
                },
              ),
              for (final p in store.playlists)
                ListTile(
                  leading: SizedBox(
                    width: 48,
                    height: 48,
                    child: PlaylistCover(songs: store.songsOf(p), radius: 8),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${p.songIds.length} canciones',
                    style: const TextStyle(color: kMuted),
                  ),
                  onTap: () {
                    final added = store.addSongs(p, songIds);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          added == 0
                              ? 'Ya estaba en "${p.name}"'
                              : 'Añadida a "${p.name}"',
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}
