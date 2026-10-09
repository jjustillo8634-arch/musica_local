import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.musica_local.channel.audio',
    androidNotificationChannelName: 'Reproducción de música',
    androidNotificationOngoing: true,
  );
  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi música',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _query = OnAudioQuery();
  final _player = AudioPlayer();

  List<SongModel> _songs = [];
  bool _loading = true;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _denied = false;
    });

    final granted = await _query.checkAndRequest(retryRequest: false);
    if (!granted) {
      if (!mounted) return;
      setState(() {
        _denied = true;
        _loading = false;
      });
      return;
    }

    final all = await _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    final songs =
        all.where((s) => (s.isMusic ?? false) && s.uri != null).toList();

    if (songs.isNotEmpty) {
      final playlist = ConcatenatingAudioSource(
        children: songs
            .map(
              (s) => AudioSource.uri(
                Uri.parse(s.uri!),
                tag: MediaItem(
                  id: s.id.toString(),
                  title: s.title,
                  artist: s.artist ?? 'Desconocido',
                  album: s.album,
                ),
              ),
            )
            .toList(),
      );
      await _player.setAudioSource(playlist, preload: false);
    }

    if (!mounted) return;
    setState(() {
      _songs = songs;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi música')),
      body: _buildBody(),
      bottomNavigationBar: _songs.isEmpty ? null : _MiniPlayer(player: _player),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Necesito permiso para leer tu música.\n'
                'Concédelo en Ajustes del teléfono y vuelve a intentar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _init, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_songs.isEmpty) {
      return const Center(child: Text('No se encontraron canciones.'));
    }

    return StreamBuilder<int?>(
      stream: _player.currentIndexStream,
      builder: (context, snap) {
        final current = snap.data;
        return ListView.builder(
          itemCount: _songs.length,
          itemBuilder: (context, i) {
            final song = _songs[i];
            return ListTile(
              selected: i == current,
              leading: const CircleAvatar(child: Icon(Icons.music_note)),
              title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                song.artist ?? 'Desconocido',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                await _player.seek(Duration.zero, index: i);
                _player.play();
              },
            );
          },
        );
      },
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  final AudioPlayer player;
  const _MiniPlayer({required this.player});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<SequenceState?>(
              stream: player.sequenceStateStream,
              builder: (context, snap) {
                final tag = snap.data?.currentSource?.tag;
                final item = tag is MediaItem ? tag : null;
                return ListTile(
                  dense: true,
                  title: Text(
                    item?.title ?? 'Elige una canción',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item?.artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
            _SeekBar(player: player),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: player.seekToPrevious,
                ),
                StreamBuilder<PlayerState>(
                  stream: player.playerStateStream,
                  builder: (context, snap) {
                    final playing = snap.data?.playing ?? false;
                    final state = snap.data?.processingState;
                    if (state == ProcessingState.loading ||
                        state == ProcessingState.buffering) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return IconButton(
                      iconSize: 40,
                      icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                      onPressed: playing ? player.pause : player.play,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: player.seekToNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  final AudioPlayer player;
  const _SeekBar({required this.player});

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durSnap) {
        final total = durSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final max = total.inMilliseconds > 0
                ? total.inMilliseconds.toDouble()
                : 1.0;
            final value = pos.inMilliseconds.toDouble().clamp(0.0, max).toDouble();
            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(_fmt(pos)),
                ),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: max,
                    value: value,
                    onChanged: (v) =>
                        player.seek(Duration(milliseconds: v.round())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(_fmt(total)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
