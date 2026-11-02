import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart' show BehaviorSubject;

/// Una canción de la cola.
class QueueEntry {
  final int songId;
  final int? albumId;
  final Uri uri;
  final MediaItem tag;

  const QueueEntry({
    required this.songId,
    required this.albumId,
    required this.uri,
    required this.tag,
  });
}

class QueueState {
  final List<QueueEntry> entries;
  final int index;
  const QueueState(this.entries, this.index);

  QueueEntry? get current =>
      (index >= 0 && index < entries.length) ? entries[index] : null;
}

/// Ajustes de la mezcla entre canciones.
class MixConfig {
  /// Duración de la mezcla. 0 = sin mezcla.
  final double fadeSeconds;

  /// La mezcla empieza este número de segundos antes del final.
  final double leadSeconds;

  /// No mezclar dos canciones seguidas del mismo álbum.
  final bool skipSameAlbum;

  const MixConfig({
    this.fadeSeconds = 0,
    this.leadSeconds = 0,
    this.skipSameAlbum = true,
  });
}

/// Valor observable. Su flujo es SIEMPRE la misma instancia y entrega el
/// valor actual a quien se suscribe (si cambiara de instancia en cada lectura,
/// un StreamBuilder se volvería a suscribir sin parar).
class _Behavior<T> {
  _Behavior(T initial) : _subject = BehaviorSubject<T>.seeded(initial);
  final BehaviorSubject<T> _subject;

  T get value => _subject.value;
  set value(T v) => _subject.add(v);

  Stream<T> get stream => _subject.stream;
}

/// Reproductor con DOS motores de audio que se alternan para poder
/// mezclar (crossfade) el final de una canción con el inicio de la siguiente.
class MixPlayer {
  MixPlayer() {
    _active = _a;
    _idle = _b;
    _wire(_a);
    _wire(_b);
  }

  final AndroidEqualizer eqA = AndroidEqualizer();
  final AndroidEqualizer eqB = AndroidEqualizer();

  late final AudioPlayer _a = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [eqA]),
  );
  late final AudioPlayer _b = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [eqB]),
  );

  late AudioPlayer _active; // el que suena ahora
  late AudioPlayer _idle; // el otro (precarga la siguiente canción)

  /// Lee la configuración de mezcla vigente (la asigna PlayerHub).
  MixConfig Function() mixConfig = () => const MixConfig();

  /// Si es true no se mezcla (lo usa el temporizador "al terminar la canción").
  bool holdMix = false;

  /// Se llama cuando un motor termina de cargar una canción
  /// (sirve para aplicar el ecualizador a ese motor).
  void Function(AndroidEqualizer eq)? onLoaded;

  AndroidEqualizer _eqOf(AudioPlayer p) => identical(p, _a) ? eqA : eqB;

  // ---------------- Estado ----------------

  List<QueueEntry> _queue = [];
  int _index = -1;
  int? _preloaded; // índice de la cola ya cargado en _idle
  bool _mixing = false;
  bool _busy = false;
  bool _wantPlaying = false;
  double _master = 1.0;
  double _speed = 1.0;
  LoopMode _loop = LoopMode.off;
  int _token = 0;
  DateTime _lastCommand = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _preloadTimer;
  Timer? _mixTimer;
  Completer<void>? _mixDone;

  final _queueB = _Behavior<QueueState>(const QueueState([], -1));
  final _positionB = _Behavior<Duration>(Duration.zero);
  final _durationB = _Behavior<Duration?>(null);
  final _stateB = _Behavior<PlayerState>(PlayerState(false, ProcessingState.idle));
  final _speedB = _Behavior<double>(1.0);
  final _loopB = _Behavior<LoopMode>(LoopMode.off);
  final StreamController<void> _jump = StreamController<void>.broadcast();

  // ---------------- Lectura (misma forma que AudioPlayer) ----------------

  Stream<QueueState> get queueStateStream => _queueB.stream;
  QueueState get queueState => _queueB.value;
  List<QueueEntry> get entries => _queue;
  int? get currentIndex => _index < 0 ? null : _index;
  late final Stream<int?> currentIndexStream =
      _queueB.stream.map((q) => q.index < 0 ? null : q.index).distinct();

  Stream<Duration> get positionStream => _positionB.stream;
  Duration get position => _active.position;
  Stream<Duration?> get durationStream => _durationB.stream;
  Duration? get duration => _durationB.value;

  Stream<PlayerState> get playerStateStream => _stateB.stream;
  bool get playing => _stateB.value.playing;
  ProcessingState get processingState => _stateB.value.processingState;
  late final Stream<bool> playingStream =
      _stateB.stream.map((s) => s.playing).distinct();

  Stream<double> get speedStream => _speedB.stream;
  double get speed => _speed;
  Stream<LoopMode> get loopModeStream => _loopB.stream;
  LoopMode get loopMode => _loop;
  double get volume => _master;

  /// Avisa cuando la posición "salta" (cambio de canción, búsqueda…).
  Stream<void> get jumpStream => _jump.stream;

  // ---------------- Conexión con los motores ----------------

  void _wire(AudioPlayer p) {
    p
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 80),
          maxPeriod: const Duration(milliseconds: 120),
        )
        .listen((pos) {
      if (!identical(p, _active)) return;
      _positionB.value = pos;
      _checkMix(pos);
    });
    p.durationStream.listen((d) {
      if (!identical(p, _active)) return;
      _durationB.value = d ?? _entryDuration();
    });
    p.playerStateStream.listen((s) {
      if (!identical(p, _active)) return;
      _syncExternal(s);
      _stateB.value = PlayerState(_wantPlaying, s.processingState);
      if (s.processingState == ProcessingState.completed) {
        unawaited(_onCompleted());
      }
    });
  }

  /// Detecta pausas o reanudaciones hechas por el sistema (llamadas,
  /// auriculares, otras apps) y las refleja en la intención del usuario.
  void _syncExternal(PlayerState s) {
    if (_busy || _mixing) return;
    if (s.processingState != ProcessingState.ready) return;
    final sinceCommand = DateTime.now().difference(_lastCommand);
    if (sinceCommand < const Duration(milliseconds: 1500)) return;
    if (s.playing != _wantPlaying) _wantPlaying = s.playing;
  }

  Duration? _entryDuration() =>
      (_index >= 0 && _index < _queue.length) ? _queue[_index].tag.duration : null;

  void _emitQueue() => _queueB.value = QueueState(List.unmodifiable(_queue), _index);

  // ---------------- Navegación ----------------

  int? _nextIndex({required bool auto}) {
    if (_queue.isEmpty) return null;
    if (auto && _loop == LoopMode.one) return _index;
    if (_index + 1 < _queue.length) return _index + 1;
    if (_loop == LoopMode.all) return 0;
    return null;
  }

  int? _prevIndex() {
    if (_queue.isEmpty) return null;
    if (_index - 1 >= 0) return _index - 1;
    if (_loop == LoopMode.all) return _queue.length - 1;
    return null;
  }

  // ---------------- Carga ----------------

  Future<bool> _loadInto(AudioPlayer p, int index) async {
    if (index < 0 || index >= _queue.length) return false;
    try {
      await p.setAudioSource(
        AudioSource.uri(_queue[index].uri),
        initialPosition: Duration.zero,
        preload: true,
      );
      await p.setSpeed(_speed);
      onLoaded?.call(_eqOf(p));
      return true;
    } catch (_) {
      return false;
    }
  }

  void _schedulePreload() {
    _preloadTimer?.cancel();
    _preloadTimer = Timer(const Duration(milliseconds: 1200), () {
      unawaited(_preloadNext());
    });
  }

  Future<void> _preloadNext() async {
    if (_mixing || _busy || _loop == LoopMode.one) return;
    final next = _nextIndex(auto: true);
    if (next == null || next == _index || _preloaded == next) return;
    final token = _token;
    _preloaded = null;
    final ok = await _loadInto(_idle, next);
    if (!ok || token != _token || _mixing) return;
    await _idle.setVolume(0);
    _preloaded = next;
  }

  void _invalidatePreload() {
    _preloaded = null;
    _schedulePreload();
  }

  // ---------------- Salto directo ----------------

  Future<void> _jumpTo(int index, {required bool play}) async {
    if (index < 0 || index >= _queue.length) return;
    final token = ++_token;
    _busy = true;
    _lastCommand = DateTime.now();
    _cancelMix();
    _preloadTimer?.cancel();
    try {
      _wantPlaying = play;
      _index = index;
      _emitQueue();

      AudioPlayer target;
      if (_preloaded == index) {
        // La canción ya estaba cargada en el otro motor: cambio casi inmediato.
        final old = _active;
        _active = _idle;
        _idle = old;
        _preloaded = null;
        await old.pause();
        target = _active;
      } else {
        target = _active;
        _preloaded = null;
        await _idle.pause();
        await target.pause(); // evita que arranque sola al cargar la canción nueva
        final ok = await _loadInto(target, index);
        if (!ok || token != _token) return;
      }

      await target.setVolume(_master);
      await target.seek(Duration.zero);
      _durationB.value = target.duration ?? _entryDuration();
      _positionB.value = Duration.zero;
      _stateB.value = PlayerState(_wantPlaying, ProcessingState.ready);
      _jump.add(null);
      if (play) unawaited(target.play());
    } finally {
      if (token == _token) _busy = false;
    }
    _schedulePreload();
  }

  // ---------------- Mezcla ----------------

  void _checkMix(Duration pos) {
    if (_mixing || _busy || !_wantPlaying || _index < 0 || holdMix) return;
    if (_loop == LoopMode.one) return;
    final dur = _active.duration;
    if (dur == null || dur.inMilliseconds < 3000) return;
    final next = _nextIndex(auto: true);
    if (next == null || next == _index) return;

    final cfg = mixConfig();
    var fadeMs = (cfg.fadeSeconds * 1000).round();
    final sameAlbum = cfg.skipSameAlbum &&
        _queue[next].albumId != null &&
        _queue[next].albumId == _queue[_index].albumId;

    int leadMs;
    if (fadeMs <= 0 || sameAlbum) {
      // Sin mezcla: empalme casi sin silencio (microfundido de 140 ms).
      fadeMs = 140;
      leadMs = 320;
    } else {
      leadMs = max(fadeMs, (cfg.leadSeconds * 1000).round());
    }

    final remainingMs = (dur - pos).inMilliseconds;
    if (remainingMs <= leadMs) {
      final effectiveFade = min(fadeMs, max(remainingMs, 140));
      unawaited(_mixTo(next, effectiveFade));
    }
  }

  Future<void> _mixTo(int next, int fadeMs) async {
    if (_mixing || _busy) return;
    _mixing = true;
    final token = ++_token;
    try {
      if (_preloaded != next) {
        final ok = await _loadInto(_idle, next);
        if (!ok || token != _token) return;
        _preloaded = next;
      }
      final outgoing = _active;
      final incoming = _idle;
      await incoming.setVolume(0);

      // La interfaz y la notificación pasan ya a la canción nueva.
      _active = incoming;
      _idle = outgoing;
      _index = next;
      _preloaded = null;
      _emitQueue();
      _durationB.value = incoming.duration ?? _entryDuration();
      _positionB.value = Duration.zero;
      _jump.add(null);
      unawaited(incoming.play());

      final done = Completer<void>();
      _mixDone = done;
      final watch = Stopwatch()..start();
      _mixTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
        final x = (watch.elapsedMilliseconds / fadeMs).clamp(0.0, 1.0).toDouble();
        // Curva de potencia constante: el volumen total se mantiene parejo.
        outgoing.setVolume(cos(x * pi / 2) * _master);
        incoming.setVolume(sin(x * pi / 2) * _master);
        if (x >= 1.0) {
          t.cancel();
          if (!done.isCompleted) done.complete();
        }
      });
      await done.future;
      _mixTimer?.cancel();
      _mixTimer = null;
      await outgoing.pause();
      await incoming.setVolume(_master);
    } finally {
      _mixing = false;
      _mixDone = null;
    }
    _schedulePreload();
  }

  void _cancelMix() {
    _mixTimer?.cancel();
    _mixTimer = null;
    final done = _mixDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  Future<void> _onCompleted() async {
    if (_busy || _mixing) return;
    if (_loop == LoopMode.one) {
      await _active.seek(Duration.zero);
      unawaited(_active.play());
      return;
    }
    final next = _nextIndex(auto: true);
    if (next == null) {
      // Fin de la cola.
      _wantPlaying = false;
      _stateB.value = PlayerState(false, ProcessingState.completed);
      return;
    }
    await _jumpTo(next, play: true);
  }

  // ---------------- Controles ----------------

  Future<void> setQueue(List<QueueEntry> entries, int index, {bool play = false}) async {
    _queue = List.of(entries);
    _preloaded = null;
    await _jumpTo(index, play: play);
  }

  Future<void> play() async {
    _lastCommand = DateTime.now();
    final finished = _stateB.value.processingState == ProcessingState.completed;
    _wantPlaying = true;
    _stateB.value = PlayerState(true, _stateB.value.processingState);
    if ((_index < 0 || finished) && _queue.isNotEmpty) {
      await _jumpTo(0, play: true);
      return;
    }
    unawaited(_active.play());
  }

  Future<void> pause() async {
    _lastCommand = DateTime.now();
    _wantPlaying = false;
    _stateB.value = PlayerState(false, _stateB.value.processingState);
    _cancelMix();
    await _active.pause();
    await _idle.pause();
  }

  Future<void> seek(Duration pos, {int? index}) async {
    if (index != null && index != _index) {
      await _jumpTo(index, play: _wantPlaying);
      if (pos > Duration.zero) await _active.seek(pos);
      return;
    }
    _cancelMix();
    await _active.seek(pos);
    _positionB.value = pos;
    _jump.add(null);
  }

  Future<void> seekToNext() async {
    final n = _nextIndex(auto: false);
    if (n == null) return;
    await _jumpTo(n, play: _wantPlaying);
  }

  /// Si ya pasaron 3 s, reinicia la canción; si no, vuelve a la anterior.
  Future<void> seekToPrevious() async {
    final prev = _prevIndex();
    if (position > const Duration(seconds: 3) || prev == null) {
      await seek(Duration.zero);
      return;
    }
    await _jumpTo(prev, play: _wantPlaying);
  }

  Future<void> setSpeed(double value) async {
    _speed = value;
    _speedB.value = value;
    await _a.setSpeed(value);
    await _b.setSpeed(value);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    _loop = mode;
    _loopB.value = mode;
    _invalidatePreload();
  }

  Future<void> setVolume(double value) async {
    _master = value.clamp(0.0, 1.0).toDouble();
    if (!_mixing) await _active.setVolume(_master);
  }

  // ---------------- Editar la cola ----------------

  Future<void> insert(int at, QueueEntry entry) async {
    final i = at.clamp(0, _queue.length).toInt();
    _queue.insert(i, entry);
    if (i <= _index) _index++;
    _emitQueue();
    _invalidatePreload();
  }

  Future<void> add(QueueEntry entry) => insert(_queue.length, entry);

  Future<void> removeAt(int i) async {
    if (i < 0 || i >= _queue.length) return;
    if (i == _index) {
      final wasPlaying = _wantPlaying;
      _queue.removeAt(i);
      if (_queue.isEmpty) {
        _index = -1;
        _emitQueue();
        await pause();
        return;
      }
      _preloaded = null;
      await _jumpTo(i.clamp(0, _queue.length - 1).toInt(), play: wasPlaying);
      return;
    }
    _queue.removeAt(i);
    if (i < _index) _index--;
    _emitQueue();
    _invalidatePreload();
  }

  Future<void> move(int from, int to) async {
    final n = _queue.length;
    if (from == to || from < 0 || from >= n || to < 0 || to >= n) return;
    final e = _queue.removeAt(from);
    _queue.insert(to, e);
    if (from == _index) {
      _index = to;
    } else if (from < _index && to >= _index) {
      _index--;
    } else if (from > _index && to <= _index) {
      _index++;
    }
    _emitQueue();
    _invalidatePreload();
  }

  /// Reemplaza todo lo que va desde [from] hasta el final de la cola.
  Future<void> replaceTail(int from, List<QueueEntry> tail) async {
    if (from < 0 || from > _queue.length) return;
    _queue.removeRange(from, _queue.length);
    _queue.addAll(tail);
    _emitQueue();
    _invalidatePreload();
  }
}
