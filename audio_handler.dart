import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;

import 'mix_player.dart';

/// Conecta el motor de mezcla con la notificación y la pantalla de bloqueo
/// de Android: portada, título, artista, anterior / pausa / siguiente.
class MixAudioHandler extends BaseAudioHandler {
  final MixPlayer player;

  MixAudioHandler(this.player) {
    player.queueStateStream.listen((q) {
      final entry = q.current;
      if (entry != null) mediaItem.add(entry.tag);
      _publish();
    });
    player.playerStateStream.listen((_) => _publish());
    player.speedStream.listen((_) => _publish());
    player.jumpStream.listen((_) => _publish());
  }

  AudioProcessingState _processing() {
    switch (player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  void _publish() {
    final playing = player.playing;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _processing(),
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.position,
        speed: player.speed,
        queueIndex: player.currentIndex,
      ),
    );
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => player.seekToNext();

  @override
  Future<void> skipToPrevious() => player.seekToPrevious();

  @override
  Future<void> stop() async {
    await player.pause();
    await super.stop();
  }
}
