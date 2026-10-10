import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'artwork.dart';
import 'library.dart';
import 'player_hub.dart';
import 'theme.dart';

/// Cola de reproducción editable: reordenar arrastrando, quitar deslizando
/// y saltar a cualquier canción tocándola.
void showQueueSheet(BuildContext context) {
  final hub = PlayerHub.instance;
  final player = hub.player;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => StreamBuilder<SequenceState?>(
        stream: player.sequenceStateStream,
        builder: (ctx, snap) {
          final state = snap.data;
          if (state == null || state.effectiveSequence.isEmpty) {
            return const Center(
              child: Text('La cola está vacía', style: TextStyle(color: kMuted)),
            );
          }

          final order = state.effectiveSequence;
          final current = state.currentSource;
          var start = current == null ? 0 : order.indexOf(current);
          if (start < 0) start = 0;
          final upcoming = order.sublist(start + 1);
          final shuffle = player.shuffleModeEnabled;

          Widget row(IndexedAudioSource src, {required bool isCurrent}) {
            final tag = src.tag;
            final title = tag is MediaItem ? tag.title : '';
            final artist = tag is MediaItem ? (tag.artist ?? '') : '';
            final song = tag is MediaItem
                ? MusicLibrary.instance.byId[int.tryParse(tag.id)]
                : null;
            return ListTile(
              contentPadding: const EdgeInsets.only(left: 20, right: 4),
              leading: SizedBox(
                width: 44,
                height: 44,
                child: Artwork(albumId: song?.albumId, px: 120, radius: 6),
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isCurrent ? kRed : null,
                ),
              ),
              subtitle: Text(
                artist,
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
          }

          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  'Reproduciendo ahora',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              if (current != null) row(current, isCurrent: true),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  upcoming.isEmpty ? 'No hay más canciones en la cola' : 'A continuación',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  shuffle
                      ? 'Aleatorio activado: puedes quitar canciones, pero no reordenarlas.'
                      : 'Mantén pulsado el ≡ y arrastra · desliza para quitar',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ),
            ],
          );

          return ReorderableListView.builder(
            scrollController: scroll,
            header: header,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: upcoming.length,
            onReorder: (oldIndex, newIndex) {
              if (shuffle) return;
              if (newIndex > oldIndex) newIndex -= 1;
              // Sin aleatorio, el orden de reproducción es el orden de la lista.
              hub.moveInQueue(start + 1 + oldIndex, start + 1 + newIndex);
            },
            itemBuilder: (ctx, i) {
              final src = upcoming[i];
              return Dismissible(
                key: ObjectKey(src),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: kRed,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) {
                  final idx = state.sequence.indexOf(src);
                  if (idx >= 0) hub.removeFromQueue(idx);
                },
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    row(src, isCurrent: false),
                    if (!shuffle)
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Icon(Icons.drag_handle, color: kMuted),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
