import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;
import 'package:on_audio_query_forked/on_audio_query.dart' show SongModel;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'artwork.dart';
import 'glass.dart';
import 'library.dart';
import 'meta_store.dart';
import 'nav.dart';
import 'player_hub.dart';
import 'playing_bars.dart';
import 'queue_sheet.dart';
import 'settings.dart';
import 'sleep_timer_sheet.dart';
import 'song_actions.dart';
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

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final hub = PlayerHub.instance;

  /// 1 = avanzar (la portada nueva entra por la derecha), -1 = retroceder.
  int _dir = 1;

  void _go(int dir) {
    _dir = dir;
    Haptics.tap();
    if (dir > 0) {
      hub.next();
    } else {
      hub.previous();
    }
  }

  void _onSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -250) {
      _go(1);
    } else if (v > 250) {
      _go(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          final title = song?.shownTitle ?? item?.title ?? 'Selecciona una canción';
          final artist = song?.shownArtist ?? item?.artist ?? 'Artista desconocido';
          final coverKey = song?.id ?? -1;

          final lower = Column(
            children: [
              // ---- Título, artista y favorito ----
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
                            style: const TextStyle(fontSize: 17, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: hub,
                    builder: (context, _) {
                      final fav = song != null && hub.isFavorite(song.id);
                      return IconButton(
                        iconSize: 28,
                        icon: Icon(
                          fav ? Icons.favorite : Icons.favorite_border,
                          color: fav ? kRed : null,
                        ),
                        onPressed: song == null
                            ? null
                            : () {
                                Haptics.tap();
                                hub.toggleFavorite(song.id);
                              },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _SeekSection(player: player),
              const SizedBox(height: 6),
              _Controls(
                hub: hub,
                onPrev: () => _go(-1),
                onNext: () => _go(1),
              ),
              const SizedBox(height: 14),
              // ---- Fila inferior estilo Spotify ----
              Row(
                children: [
                  _SpeedButton(player: player),
                  const Spacer(),
                  const _SleepButton(),
                  IconButton(
                    icon: const Icon(Icons.queue_music, size: 26),
                    tooltip: 'Cola de reproducción',
                    onPressed: () => showQueueSheet(context),
                  ),
                ],
              ),
            ],
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              ListenableBuilder(
                listenable: AppSettings.instance,
                builder: (context, _) => AppSettings.instance.blurBackdrop
                    ? _Backdrop(song: song)
                    : const SizedBox.expand(),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // ---- Barra superior ----
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'REPRODUCIENDO DESDE',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    letterSpacing: 1.1,
                                    color: kMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                ValueListenableBuilder<String>(
                                  valueListenable: hub.sourceLabel,
                                  builder: (context, label, _) => Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            tooltip: 'Más opciones',
                            onPressed: song == null
                                ? null
                                : () => showSongActions(context, song),
                          ),
                        ],
                      ),

                      // ---- Portada (desliza para cambiar de canción) ----
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragEnd: _onSwipe,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 280),
                                  transitionBuilder: (child, animation) {
                                    final incoming = child.key == ValueKey<int>(coverKey);
                                    final begin = Offset(
                                      incoming ? _dir.toDouble() : -_dir.toDouble(),
                                      0,
                                    );
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: begin,
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: KeyedSubtree(
                                    key: ValueKey<int>(coverKey),
                                    child: _CoverCard(song: song, item: item),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ---- Zona inferior (cristal si está activado) ----
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GlassBox(
                          radius: 28,
                          transparentWhenOff: true,
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
                          child: lower,
                        ),
                      ),
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
// Portada con sombra, forma elegida y giro de vinilo
// ----------------------------------------------------------------------

class _CoverCard extends StatelessWidget {
  final SongModel? song;
  final MediaItem? item;
  const _CoverCard({required this.song, required this.item});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        final isCircle = s.coverShape == CoverShape.circle;
        final radius = s.coverShape == CoverShape.square
            ? 0.0
            : 28.0 * s.roundness;

        Widget cover = DecoratedBox(
          decoration: BoxDecoration(
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : BorderRadius.circular(radius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x73000000),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: SizedBox.expand(
            child: Artwork(
              albumId: song?.albumId,
              songId: song?.id,
              px: 800,
              radius: 28,
              iconSize: 96,
            ),
          ),
        );

        if (isCircle && s.vinylSpin) {
          cover = StreamBuilder<bool>(
            stream: PlayerHub.instance.player.playingStream,
            initialData: PlayerHub.instance.player.playing,
            builder: (context, snap) =>
                SpinningCover(spinning: snap.data ?? false, child: cover),
          );
        }
        return cover;
      },
    );
  }
}

// ----------------------------------------------------------------------
// Fondo con la portada difuminada
// ----------------------------------------------------------------------

class _Backdrop extends StatelessWidget {
  final SongModel? song;
  const _Backdrop({required this.song});

  @override
  Widget build(BuildContext context) {
    final custom = song?.customCover;
    final Widget image = custom != null
        ? Image.file(File(custom), fit: BoxFit.cover, cacheWidth: 300)
        : const SizedBox.shrink();

    if (custom != null) return _blurred(image);

    return FutureBuilder<Uint8List?>(
      future: loadAlbumArt(song?.albumId, px: 200),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null || bytes.isEmpty) return const SizedBox.expand();
        return _blurred(Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true));
      },
    );
  }

  Widget _blurred(Widget image) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: SizedBox.expand(child: image),
        ),
        const ColoredBox(color: Color(0x99000000)),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// Fila inferior: velocidad y temporizador
// ----------------------------------------------------------------------

class _SpeedButton extends StatelessWidget {
  final AudioPlayer player;
  const _SpeedButton({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.speedStream,
      initialData: player.speed,
      builder: (context, snap) {
        final speed = snap.data ?? 1.0;
        final active = (speed - 1.0).abs() > 0.01;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Haptics.tap();
            final i = PlayerHub.speeds.indexWhere((v) => (v - speed).abs() < 0.01);
            player.setSpeed(PlayerHub.speeds[(i + 1) % PlayerHub.speeds.length]);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed, size: 22, color: active ? kRed : Colors.white70),
                const SizedBox(width: 6),
                Text(
                  '${speed}x',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: active ? kRed : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SleepButton extends StatelessWidget {
  const _SleepButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: PlayerHub.instance.sleepLabel,
      builder: (context, label, _) {
        final active = label != null;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showSleepTimerSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.bedtime : Icons.bedtime_outlined,
                  size: 22,
                  color: active ? kRed : Colors.white70,
                ),
                if (active) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(color: kRed, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
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
  final PlayerHub hub;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _Controls({required this.hub, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final player = hub.player;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: hub.shuffleOn,
          builder: (context, on, _) => IconButton(
            iconSize: 26,
            icon: Icon(Icons.shuffle, color: on ? kRed : Colors.white70),
            tooltip: on ? 'Aleatorio activado' : 'Aleatorio',
            onPressed: () {
              Haptics.tap();
              hub.toggleShuffle();
            },
          ),
        ),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_previous),
          onPressed: onPrev,
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
              decoration: BoxDecoration(
                color: kRed,
                borderRadius: BorderRadius.circular(26),
              ),
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
                      onPressed: () {
                        Haptics.tap();
                        playing ? player.pause() : player.play();
                      },
                    ),
            );
          },
        ),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_next),
          onPressed: onNext,
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
                Haptics.tap();
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
