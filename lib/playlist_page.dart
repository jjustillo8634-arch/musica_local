import 'package:flutter/material.dart';

import 'library.dart';
import 'mini_player.dart';
import 'player_hub.dart';
import 'playlist_widgets.dart';
import 'playlists.dart';
import 'song_picker_page.dart';
import 'theme.dart';
import 'widgets.dart';

void openPlaylist(BuildContext context, Playlist playlist) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PlaylistPage(playlistId: playlist.id)),
  );
}

class PlaylistPage extends StatelessWidget {
  final String playlistId;
  const PlaylistPage({super.key, required this.playlistId});

  Future<void> _rename(BuildContext context, Playlist p) async {
    final controller = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Renombrar playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
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
    if (name != null) PlaylistStore.instance.rename(p, name);
  }

  Future<void> _delete(BuildContext context, Playlist p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Eliminar playlist'),
        content: Text('¿Eliminar "${p.name}"? Tus canciones no se borran.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      PlaylistStore.instance.delete(p);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PlaylistStore.instance;
    final hub = PlayerHub.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([store, MusicLibrary.instance]),
      builder: (context, _) {
        final p = store.byId(playlistId);
        if (p == null) {
          return const Scaffold(body: Center(child: Text('Playlist eliminada')));
        }
        final songs = store.songsOf(p);
        final totalMin =
            (songs.fold<int>(0, (a, s) => a + (s.duration ?? 0)) / 60000).round();

        final header = Column(
          children: [
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: DecoratedBox(
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
                  child: PlaylistCover(songs: songs, radius: 18),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                p.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${songs.length} ${songs.length == 1 ? 'canción' : 'canciones'} · $totalMin min',
              style: const TextStyle(color: kMuted),
            ),
            if (songs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: PlayShuffleRow(songs: songs),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SongPickerPage(playlistId: p.id),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir canciones'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kRed,
                    side: const BorderSide(color: kRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            if (songs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Esta playlist está vacía.\nAñade las canciones que quieras.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mantén pulsado y arrastra para reordenar · desliza para quitar',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                ),
              ),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            actions: [
              PopupMenuButton<String>(
                color: kCardHi,
                onSelected: (v) {
                  if (v == 'rename') _rename(context, p);
                  if (v == 'delete') _delete(context, p);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar playlist', style: TextStyle(color: kRed)),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: const MiniPlayer(),
          body: ReorderableListView.builder(
            header: header,
            padding: const EdgeInsets.only(bottom: 24),
            buildDefaultDragHandles: false,
            itemCount: songs.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              final ids = songs.map((s) => s.id).toList();
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              store.setOrder(p, ids);
            },
            itemBuilder: (context, i) {
              final song = songs[i];
              return Dismissible(
                key: ValueKey('pl_${p.id}_${song.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: kRed,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => store.removeSong(p, song.id),
                child: SongTile(
                  song: song,
                  showMenu: false,
                  onTap: () => hub.playSongs(songs, i),
                  trailingExtra: ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle, color: kMuted),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
