import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'artwork.dart';
import 'glass.dart';
import 'library.dart';
import 'meta_store.dart';
import 'now_playing_page.dart';
import 'player_hub.dart';
import 'settings.dart';
import 'theme.dart';

/// Mini reproductor flotante: toca para abrir la pantalla de reproducción
/// y desliza a los lados para cambiar de canción.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = PlayerHub.instance;
    final player = hub.player;
    return StreamBuilder<SequenceState?>(
      stream: player.sequenceStateStream,
      builder: (context, snap) {
        final tag = snap.data?.currentSource?.tag;
        if (tag is! MediaItem) return const SizedBox.shrink();
        final song = MusicLibrary.instance.byId[int.tryParse(tag.id)];
        final title = song?.shownTitle ?? tag.title;
        final artist = song?.shownArtist ?? (tag.artist ?? '');

        return GestureDetector(
          onTap: () => openNowPlaying(context),
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -250) {
              Haptics.tap();
              hub.next();
            } else if (v > 250) {
              Haptics.tap();
              hub.previous();
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: GlassBox(
              radius: 22,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46,
                          height: 46,
                          child: Artwork(
                            albumId: song?.albumId,
                            songId: song?.id,
                            px: 150,
                            radius: 10,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: kMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: player.playerStateStream,
                          builder: (context, s) {
                            final playing = s.data?.playing ?? false;
                            return IconButton(
                              iconSize: 32,
                              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                              onPressed: () {
                                Haptics.tap();
                                playing ? player.pause() : player.play();
                              },
                            );
                          },
                        ),
                        IconButton(
                          iconSize: 30,
                          icon: const Icon(Icons.skip_next),
                          onPressed: () {
                            Haptics.tap();
                            hub.next();
                          },
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<Duration?>(
                    stream: player.durationStream,
                    builder: (context, d) {
                      final total = d.data?.inMilliseconds ?? 0;
                      return StreamBuilder<Duration>(
                        stream: player.positionStream,
                        builder: (context, p) {
                          final pos = p.data?.inMilliseconds ?? 0;
                          final value = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
                          return LinearProgressIndicator(
                            value: value.toDouble(),
                            minHeight: 2,
                            color: kRed,
                            backgroundColor: Colors.white12,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
