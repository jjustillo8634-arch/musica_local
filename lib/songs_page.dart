import 'package:flutter/material.dart';

import 'library.dart';
import 'player_hub.dart';
import 'theme.dart';
import 'widgets.dart';

class SongsPage extends StatefulWidget {
  const SongsPage({super.key});

  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lib = MusicLibrary.instance;

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: lib,
        builder: (context, _) {
          final q = _query.trim().toLowerCase();
          final list = q.isEmpty
              ? lib.songs
              : lib.songs
                  .where(
                    (s) =>
                        s.title.toLowerCase().contains(q) ||
                        (s.artist ?? '').toLowerCase().contains(q) ||
                        (s.album ?? '').toLowerCase().contains(q),
                  )
                  .toList();

          return Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: ScreenTitle('Canciones'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _controller,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar en tu biblioteca',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                          ),
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
              if (list.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: PlayShuffleRow(songs: list),
                ),
              Expanded(
                child: RefreshIndicator(
                  color: kRed,
                  onRefresh: lib.load,
                  child: list.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'Sin resultados',
                                style: TextStyle(color: kMuted),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, i) => SongTile(
                            song: list[i],
                            onTap: () => PlayerHub.instance.playSongs(list, i),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
