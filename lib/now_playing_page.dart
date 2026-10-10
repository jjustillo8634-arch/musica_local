import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'artwork.dart';
import 'library.dart';
import 'nav.dart';
import 'player_hub.dart';
import 'sleep_timer_sheet.dart';
import 'song_info_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// Abre la pantalla de reproducción deslizándola desde abajo.
void openNowPlaying(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const NowPlayingPage(),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = PlayerHub.instance;
    final player = hub.player;

    return Scaffold(
      backgroundColor: kBg,
      body: StreamBuilder<SequenceState?>(
        stream: player.sequenceStateStream,
        builder: (context, snap) {
          final tag = snap.data?.currentSource?.tag;
          final item = tag is MediaItem ? tag : null;
          final song =
              item == null ? null : MusicLibrary.instance.byId[int.tryParse(item.id)];
          final title = item?.title ?? 'Selecciona una canción';
          final artist = cleanText(song?.artist ?? item?.artist, 'Artista desconocido');
          final album = cleanText(song?.album ?? item?.album, '');

          return Stack(
            fit: StackFit.expand,
            children: [
              _Backdrop(albumId: song?.albumId),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      // ---- Barra superior ----
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Spacer(),
                          _SpeedChip(player: player),
                          const SizedBox(width: 8),
                          const _SleepChip(),
                          IconButton(
                            icon: const Icon(Icons.queue_music),
                            tooltip: 'Cola de reproducción',
                            onPressed: () => showQueueSheet(context),
                          ),
                        ],
                      ),

                      // ---- Portada ----
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66000000),
                                      blurRadius: 30,
                                      offset: Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Artwork(
                                  albumId: song?.albumId,
                                  px: 800,
                                  radius: 24,
                                  iconSize: 96,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ---- Título, artista, info y favorito ----
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  onTap: song == null
                                      ? null
                                      : () => openArtistOfSong(context, song),
                                  child: Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                if (album.isNotEmpty)
                                  GestureDetector(
                                    onTap: song == null
                                        ? null
                                        : () => openAlbum(context, song.albumId),
                                    child: Text(
                                      album,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: kMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.info_outline),
                            tooltip: 'Información',
                            onPressed: song == null
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => SongInfoPage(song: song),
                                      ),
                                    ),
                          ),
                          ListenableBuilder(
                            listenable: hub,
                            builder: (context, _) {
                              final fav = song != null && hub.isFavorite(song.id);
                              return IconButton(
                                icon: Icon(
                                  fav ? Icons.favorite : Icons.favorite_border,
                                  color: fav ? kRed : null,
                                ),
                                onPressed:
                                    song == null ? null : () => hub.toggleFavorite(song.id),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      _SeekSection(player: player),
                      const SizedBox(height: 8),
                      _Controls(player: player),
                      const SizedBox(height: 20),
                    ],
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

// ----------------------------------------------------------------------
// Fondo con la portada difuminada
// ----------------------------------------------------------------------

class _Backdrop extends StatelessWidget {
  final int? albumId;
  const _Backdrop({required this.albumId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: loadAlbumArt(albumId, px: 200),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null || bytes.isEmpty) return const SizedBox.expand();
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
            ),
            const ColoredBox(color: Color(0x99000000)),
          ],
        );
      },
    );
  }
}

// ----------------------------------------------------------------------
// Chips superiores: velocidad y temporizador
// ----------------------------------------------------------------------

class _Pill extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _Pill({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: child,
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final AudioPlayer player;
  const _SpeedChip({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.speedStream,
      initialData: player.speed,
      builder: (context, snap) {
        final speed = snap.data ?? 1.0;
        return _Pill(
          onTap: () {
            final i = PlayerHub.speeds.indexWhere((v) => (v - speed).abs() < 0.01);
            player.setSpeed(PlayerHub.speeds[(i + 1) % PlayerHub.speeds.length]);
          },
          child: Text(
            '${speed}x',
            style: const TextStyle(color: kRed, fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}

class _SleepChip extends StatelessWidget {
  const _SleepChip();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: PlayerHub.instance.sleepLabel,
      builder: (context, label, _) {
        final active = label != null;
        return _Pill(
          onTap: () => showSleepTimerSheet(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bedtime_outlined, size: 16, color: active ? kRed : kMuted),
              const SizedBox(width: 6),
              Text(
                label ?? 'Off',
                style: TextStyle(
                  color: active ? kRed : kMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------------
// Barra de progreso
// ----------------------------------------------------------------------

class _SeekSection extends StatefulWidget {
  final AudioPlayer player;
  const _SeekSection({required this.player});

  @override
  State<_SeekSection> createState() => _SeekSectionState();
}

class _SeekSectionState extends State<_SeekSection> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      initialData: player.duration,
      builder: (context, durSnap) {
        final total = durSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final max = total.inMilliseconds > 0
                ? total.inMilliseconds.toDouble()
                : 1.0;
            final current = _drag ?? pos.inMilliseconds.toDouble();
            final value = current.clamp(0.0, max).toDouble();
            return Column(
              children: [
                Slider(
                  min: 0,
                  max: max,
                  value: value,
                  onChanged: (v) => setState(() => _drag = v),
                  onChangeEnd: (v) {
                    player.seek(Duration(milliseconds: v.round()));
                    setState(() => _drag = null);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        fmtDuration(Duration(milliseconds: value.round())),
                        style: const TextStyle(color: kMuted, fontSize: 12),
                      ),
                      Text(
                        fmtDuration(total),
                        style: const TextStyle(color: kMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ----------------------------------------------------------------------
// Controles
// ----------------------------------------------------------------------

class _Controls extends StatelessWidget {
  final AudioPlayer player;
  const _Controls({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        StreamBuilder<bool>(
          stream: player.shuffleModeEnabledStream,
          initialData: player.shuffleModeEnabled,
          builder: (context, snap) {
            final on = snap.data ?? false;
            return IconButton(
              iconSize: 26,
              icon: Icon(Icons.shuffle, color: on ? kRed : Colors.white70),
              onPressed: () async {
                await player.setShuffleModeEnabled(!on);
                if (!on) await player.shuffle();
              },
            );
          },
        ),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_previous),
          onPressed: player.seekToPrevious,
        ),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snap) {
            final playing = snap.data?.playing ?? false;
            final state = snap.data?.processingState;
            final loading =
                state == ProcessingState.loading || state == ProcessingState.buffering;
            return Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : IconButton(
                      iconSize: 40,
                      color: Colors.white,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      onPressed: playing ? player.pause : player.play,
                    ),
            );
          },
        ),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_next),
          onPressed: player.seekToNext,
        ),
        StreamBuilder<LoopMode>(
          stream: player.loopModeStream,
          initialData: player.loopMode,
          builder: (context, snap) {
            final mode = snap.data ?? LoopMode.off;
            return IconButton(
              iconSize: 26,
              icon: Icon(
                mode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                color: mode == LoopMode.off ? Colors.white70 : kRed,
              ),
              onPressed: () {
                final next = switch (mode) {
                  LoopMode.off => LoopMode.all,
                  LoopMode.all => LoopMode.one,
                  LoopMode.one => LoopMode.off,
                };
                player.setLoopMode(next);
              },
            );
          },
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// Cola de reproducción
// ----------------------------------------------------------------------

void showQueueSheet(BuildContext context) {
  final player = PlayerHub.instance.player;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => StreamBuilder<SequenceState?>(
        stream: player.sequenceStateStream,
        builder: (ctx, snap) {
          final state = snap.data;
          if (state == null) return const SizedBox.shrink();
          final order = state.effectiveSequence;
          final current = state.currentSource;
          var start = current == null ? 0 : order.indexOf(current);
          if (start < 0) start = 0;
          final upcoming = order.sublist(start);

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'A continuación',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: upcoming.length,
                  itemBuilder: (ctx, i) {
                    final src = upcoming[i];
                    final tag = src.tag;
                    if (tag is! MediaItem) return const SizedBox.shrink();
                    final song = MusicLibrary.instance.byId[int.tryParse(tag.id)];
                    final isCurrent = i == 0;
                    return ListTile(
                      leading: SizedBox(
                        width: 44,
                        height: 44,
                        child: Artwork(albumId: song?.albumId, px: 120, radius: 6),
                      ),
                      title: Text(
                        tag.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? kRed : null,
                        ),
                      ),
                      subtitle: Text(
                        tag.artist ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kMuted),
                      ),
                      onTap: () {
                        final idx = state.sequence.indexOf(src);
                        if (idx >= 0) {
                          player.seek(Duration.zero, index: idx);
                          player.play();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
