import 'package:flutter/material.dart';

import 'artwork.dart';
import 'library.dart';
import 'playlists.dart';
import 'theme.dart';
import 'widgets.dart';

/// Elegir varias canciones para añadirlas a una playlist.
class SongPickerPage extends StatefulWidget {
  final String playlistId;
  const SongPickerPage({super.key, required this.playlistId});

  @override
  State<SongPickerPage> createState() => _SongPickerPageState();
}

class _SongPickerPageState extends State<SongPickerPage> {
  final Set<int> _selected = {};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = PlaylistStore.instance;
    final playlist = store.byId(widget.playlistId);
    if (playlist == null) return const Scaffold();

    final q = _query.trim().toLowerCase();
    final songs = MusicLibrary.instance.songs
        .where(
          (s) =>
              q.isEmpty ||
              s.title.toLowerCase().contains(q) ||
              (s.artist ?? '').toLowerCase().contains(q) ||
              (s.album ?? '').toLowerCase().contains(q),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selected.isEmpty ? 'Añadir canciones' : '${_selected.length} seleccionadas',
        ),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () {
                    store.addSongs(playlist, _selected);
                    Navigator.of(context).pop();
                  },
            child: Text(
              'Listo',
              style: TextStyle(
                color: _selected.isEmpty ? kMuted : kRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar canciones',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: kCard,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, i) {
                final s = songs[i];
                final already = playlist.songIds.contains(s.id);
                final checked = already || _selected.contains(s.id);
                return ListTile(
                  enabled: !already,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: SizedBox(
                    width: 48,
                    height: 48,
                    child: Artwork(albumId: s.albumId, px: 150, radius: 8),
                  ),
                  title: Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    cleanText(s.artist, 'Artista desconocido'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kMuted),
                  ),
                  trailing: Icon(
                    checked ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: already ? kMuted : (checked ? kRed : kMuted),
                  ),
                  onTap: already
                      ? null
                      : () => setState(() {
                            if (!_selected.remove(s.id)) _selected.add(s.id);
                          }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
