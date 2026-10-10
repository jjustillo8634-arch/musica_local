import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'artwork.dart';
import 'library.dart';
import 'now_playing_page.dart';
import 'player_hub.dart';
import 'theme.dart';

/// Mini reproductor flotante: toca para abrir la pantalla de reproducción.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerHub.instance.player;
    return StreamBuilder<SequenceState?>(
      stream: player.sequenceStateStream,
      builder: (context, snap) {
        final tag = snap.data?.currentSource?.tag;
        if (tag is! MediaItem) return const SizedBox.shrink();
        final song = MusicLibrary.instance.byId[int.tryParse(tag.id)];

        return GestureDetector(
          onTap: () => openNowPlaying(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
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
                        child: Artwork(albumId: song?.albumId, px: 150, radius: 8),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tag.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              tag.artist ?? '',
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
                            onPressed: playing ? player.pause : player.play,
                          );
                        },
                      ),
                      IconButton(
                        iconSize: 30,
                        icon: const Icon(Icons.skip_next),
                        onPressed: player.seekToNext,
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
        );
      },
    );
  }
}
