import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'art_cache.dart';
import 'library.dart' show cleanText;

/// Preset de ecualizador. [curve] son 5 puntos de graves a agudos, en dB.
/// Se adapta automáticamente al número de bandas que tenga el teléfono.
class EqPreset {
  final String name;
  final List<double> curve;
  const EqPreset(this.name, this.curve);
}

const eqPresets = <EqPreset>[
  EqPreset('Plano', [0, 0, 0, 0, 0]),
  EqPreset('Bajos potentes', [6, 4, 0, 0, 0]),
  EqPreset('Graves reducidos', [-5, -3, 0, 0, 0]),
  EqPreset('Agudos potentes', [0, 0, 0, 3, 6]),
  EqPreset('Voz', [-3, -1, 4, 4, 1]),
  EqPreset('Pop', [-1, 2, 4, 2, -2]),
  EqPreset('Rock', [5, 3, -1, 3, 5]),
  EqPreset('Hip-Hop', [5, 3, 0, 1, 3]),
  EqPreset('Jazz', [3, 1, -1, 1, 3]),
  EqPreset('Clásica', [3, 2, 0, 2, 4]),
  EqPreset('Electrónica', [6, 4, 0, 2, 4]),
  EqPreset('Acústica', [4, 3, 2, 2, 3]),
];

/// Punto único de acceso al reproductor, sus efectos y el estado de la app
/// (favoritas, recientes y temporizador de apagado).
class PlayerHub extends ChangeNotifier {
  PlayerHub._();
  static final PlayerHub instance = PlayerHub._();

  static const speeds = <double>[0.75, 1.0, 1.25, 1.5, 2.0];

  final AndroidEqualizer equalizer = AndroidEqualizer();

  late final AudioPlayer player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
  );

  // ------------------------------------------------------------------
  // Estado de la app
  // ------------------------------------------------------------------

  /// Id de la canción que suena ahora (para resaltarla en las listas).
  final ValueNotifier<int?> currentId = ValueNotifier<int?>(null);

  /// null = temporizador apagado; si no, texto como "12:30" o "Fin de canción".
  final ValueNotifier<String?> sleepLabel = ValueNotifier<String?>(null);

  final Set<int> favorites = <int>{};
  final List<int> recentIds = <int>[];

  bool _started = false;
  bool _armed = false; // true cuando el usuario ya inició una reproducción

  Future<void> init() async {
    if (_started) return;
    _started = true;
    final prefs = await SharedPreferences.getInstance();
    favorites.addAll(
      (prefs.getStringList('fav_ids') ?? const <String>[])
          .map((e) => int.tryParse(e))
          .whereType<int>(),
    );
    recentIds.addAll(
      (prefs.getStringList('recent_ids') ?? const <String>[])
          .map((e) => int.tryParse(e))
          .whereType<int>(),
    );
    player.sequenceStateStream.listen(_onSequence);
    notifyListeners();
  }

  void _onSequence(SequenceState? state) {
    final tag = state?.currentSource?.tag;
    if (tag is! MediaItem) return;
    final id = int.tryParse(tag.id);
    if (id == null || id == currentId.value) return;
    currentId.value = id;
    if (_armed) _recordRecent(id);
  }

  void _recordRecent(int id) {
    recentIds.remove(id);
    recentIds.insert(0, id);
    if (recentIds.length > 30) recentIds.removeLast();
    notifyListeners();
    SharedPreferences.getInstance().then(
      (p) => p.setStringList(
        'recent_ids',
        recentIds.map((e) => e.toString()).toList(),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Cola y reproducción
  // ------------------------------------------------------------------

  AudioSource _toSource(SongModel s) {
    return AudioSource.uri(
      Uri.parse(s.uri!),
      tag: MediaItem(
        id: s.id.toString(),
        title: s.title,
        artist: cleanText(s.artist, 'Artista desconocido'),
        album: cleanText(s.album, ''),
        duration: s.duration != null ? Duration(milliseconds: s.duration!) : null,
        // Portada en archivo: así se ve en la notificación y en el bloqueo.
        artUri: ArtCache.uriFor(s.albumId),
      ),
    );
  }

  /// Cola actual (permite añadir, quitar y reordenar mientras suena).
  ConcatenatingAudioSource? _queue;

  Future<void> _setQueue(List<SongModel> songs, int index) async {
    // La portada de la canción inicial debe existir antes de cargarla.
    await ArtCache.ensure(songs[index].albumId);
    final source = ConcatenatingAudioSource(
      children: [for (final s in songs) _toSource(s)],
    );
    _queue = source;
    await player.setAudioSource(
      source,
      initialIndex: index,
      initialPosition: Duration.zero,
    );
    // El resto de portadas se preparan en segundo plano.
    unawaited(ArtCache.warm(songs.map((s) => s.albumId)));
    unawaited(initEqualizer().catchError((_) {}));
  }

  /// Carga la cola sin reproducir (así el ecualizador queda listo).
  Future<void> prepareQueue(List<SongModel> songs) async {
    if (songs.isEmpty) return;
    await _setQueue(songs, 0);
  }

  /// Reproduce [songs] empezando en [index]. [shuffle] null = no tocar el
  /// modo aleatorio actual.
  Future<void> playSongs(List<SongModel> songs, int index, {bool? shuffle}) async {
    if (songs.isEmpty) return;
    _armed = true;
    await _setQueue(songs, index.clamp(0, songs.length - 1).toInt());
    if (shuffle != null) {
      await player.setShuffleModeEnabled(shuffle);
      if (shuffle) await player.shuffle();
    }
    player.play();
  }

  Future<void> shuffleAll(List<SongModel> songs) async {
    if (songs.isEmpty) return;
    await playSongs(songs, Random().nextInt(songs.length), shuffle: true);
  }

  // ------------------------------------------------------------------
  // Editar la cola
  // ------------------------------------------------------------------

  /// Inserta la canción justo después de la actual.
  Future<void> playNext(SongModel song) async {
    final q = _queue;
    if (q == null) {
      await playSongs([song], 0);
      return;
    }
    await ArtCache.ensure(song.albumId);
    final at = (player.currentIndex ?? -1) + 1;
    await q.insert(at.clamp(0, q.length).toInt(), _toSource(song));
  }

  /// Añade la canción al final de la cola.
  Future<void> addToQueue(SongModel song) async {
    final q = _queue;
    if (q == null) {
      await playSongs([song], 0);
      return;
    }
    await ArtCache.ensure(song.albumId);
    await q.add(_toSource(song));
  }

  Future<void> removeFromQueue(int index) async {
    await _queue?.removeAt(index);
  }

  Future<void> moveInQueue(int from, int to) async {
    await _queue?.move(from, to);
  }

  // ------------------------------------------------------------------
  // Favoritas
  // ------------------------------------------------------------------

  bool isFavorite(int id) => favorites.contains(id);

  Future<void> toggleFavorite(int id) async {
    if (!favorites.remove(id)) favorites.add(id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'fav_ids',
      favorites.map((e) => e.toString()).toList(),
    );
  }

  // ------------------------------------------------------------------
  // Temporizador de apagado
  // ------------------------------------------------------------------

  Timer? _sleepTicker;
  StreamSubscription<Duration>? _trackEndSub;
  DateTime? _sleepEnd;
  bool _fading = false;

  String _fmtLeft(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
  }

  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepEnd = DateTime.now().add(duration);
    sleepLabel.value = _fmtLeft(duration);
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final end = _sleepEnd;
      if (end == null) return;
      final left = end.difference(DateTime.now());
      if (left <= Duration.zero) {
        _fadeOutAndPause();
      } else {
        sleepLabel.value = _fmtLeft(left);
      }
    });
  }

  /// Detiene la música cuando termina la canción actual.
  void sleepAfterCurrentTrack() {
    cancelSleepTimer();
    sleepLabel.value = 'Fin de canción';
    _trackEndSub = player.positionStream.listen((pos) {
      final dur = player.duration;
      if (dur == null || _fading) return;
      if (dur - pos <= const Duration(milliseconds: 1500)) {
        _fadeOutAndPause(seekNext: true);
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _trackEndSub?.cancel();
    _trackEndSub = null;
    _sleepEnd = null;
    sleepLabel.value = null;
  }

  Future<void> _fadeOutAndPause({bool seekNext = false}) async {
    if (_fading) return;
    _fading = true;
    cancelSleepTimer();
    final startVolume = player.volume;
    const steps = 8;
    for (var i = steps - 1; i >= 0; i--) {
      await player.setVolume(startVolume * i / steps);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    await player.pause();
    if (seekNext) await player.seekToNext();
    await player.setVolume(startVolume);
    _fading = false;
  }

  // ------------------------------------------------------------------
  // Ecualizador
  // ------------------------------------------------------------------

  AndroidEqualizerParameters? params;
  List<double> gains = [];
  bool eqEnabled = false;
  String presetName = 'Plano';
  bool _eqReady = false;

  /// Llamar cuando el reproductor ya tenga una fuente de audio cargada.
  Future<void> initEqualizer() async {
    if (_eqReady) return;

    final prefs = await SharedPreferences.getInstance();
    eqEnabled = prefs.getBool('eq_enabled') ?? false;
    presetName = prefs.getString('eq_preset') ?? 'Plano';
    final saved = prefs.getStringList('eq_gains');

    await equalizer.setEnabled(eqEnabled);
    final p = await equalizer.parameters;
    final bands = p.bands;

    final useSaved = saved != null && saved.length == bands.length;
    final loaded = <double>[];
    for (var i = 0; i < bands.length; i++) {
      if (useSaved) {
        final g = (double.tryParse(saved[i]) ?? 0.0)
            .clamp(p.minDecibels, p.maxDecibels)
            .toDouble();
        await bands[i].setGain(g);
        loaded.add(g);
      } else {
        loaded.add(bands[i].gain);
      }
    }

    gains = loaded;
    params = p;
    _eqReady = true;
    notifyListeners();
  }

  Future<void> setEqEnabled(bool value) async {
    await equalizer.setEnabled(value);
    eqEnabled = value;
    notifyListeners();
    _save();
  }

  Future<void> setBandGain(int index, double value) async {
    final p = params;
    if (p == null) return;
    gains[index] = value;
    presetName = 'Personalizado';
    notifyListeners();
    await p.bands[index].setGain(value);
  }

  /// Guarda los ajustes (se llama al soltar un slider).
  Future<void> saveEq() => _save();

  Future<void> applyPreset(EqPreset preset) async {
    final p = params;
    if (p == null) return;
    if (!eqEnabled) await setEqEnabled(true);

    final bands = p.bands;
    final n = bands.length;
    final last = preset.curve.length - 1;

    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 0.0 : i * last / (n - 1);
      final lo = t.floor();
      final hi = min(lo + 1, last);
      final v = preset.curve[lo] + (preset.curve[hi] - preset.curve[lo]) * (t - lo);
      final g = v.clamp(p.minDecibels, p.maxDecibels).toDouble();
      gains[i] = g;
      await bands[i].setGain(g);
    }

    presetName = preset.name;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled', eqEnabled);
    await prefs.setString('eq_preset', presetName);
    await prefs.setStringList(
      'eq_gains',
      gains.map((g) => g.toString()).toList(),
    );
  }
}
