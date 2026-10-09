import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Punto único de acceso al reproductor y a sus efectos de audio.
class PlayerHub extends ChangeNotifier {
  PlayerHub._();
  static final PlayerHub instance = PlayerHub._();

  final AndroidEqualizer equalizer = AndroidEqualizer();

  late final AudioPlayer player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
  );

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
