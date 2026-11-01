import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CoverShape { rounded, square, circle }

/// Ajustes de personalización de la app (se guardan en el teléfono).
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  CoverShape coverShape = CoverShape.rounded;

  /// Multiplicador del redondeo de las portadas (solo en forma redondeada).
  double roundness = 1.2;

  /// Fondo difuminado con la portada en la pantalla de reproducción.
  bool blurBackdrop = true;

  /// Estilo "liquid glass": paneles de cristal translúcido.
  bool liquidGlass = false;

  /// Con portada circular, gira como un disco mientras suena.
  bool vinylSpin = true;

  /// Barras animadas junto a la canción que está sonando.
  bool playingBars = true;

  /// Vibración suave al tocar los controles.
  bool haptics = true;

  /// Icono de la app: normal, dark o glass.
  String launcherIcon = 'normal';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final shapeIndex = p.getInt('set_shape') ?? CoverShape.rounded.index;
      coverShape = CoverShape.values[shapeIndex.clamp(0, CoverShape.values.length - 1).toInt()];
      roundness = p.getDouble('set_roundness') ?? 1.2;
      blurBackdrop = p.getBool('set_blur') ?? true;
      liquidGlass = p.getBool('set_glass') ?? false;
      vinylSpin = p.getBool('set_vinyl') ?? true;
      playingBars = p.getBool('set_bars') ?? true;
      haptics = p.getBool('set_haptics') ?? true;
      launcherIcon = p.getString('set_icon') ?? 'normal';
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('set_shape', coverShape.index);
      await p.setDouble('set_roundness', roundness);
      await p.setBool('set_blur', blurBackdrop);
      await p.setBool('set_glass', liquidGlass);
      await p.setBool('set_vinyl', vinylSpin);
      await p.setBool('set_bars', playingBars);
      await p.setBool('set_haptics', haptics);
      await p.setString('set_icon', launcherIcon);
    } catch (_) {}
  }

  void update(void Function(AppSettings s) change) {
    change(this);
    notifyListeners();
    _save();
  }
}

/// Vibración suave opcional.
class Haptics {
  static void tap() {
    if (AppSettings.instance.haptics) HapticFeedback.selectionClick();
  }

  static void heavy() {
    if (AppSettings.instance.haptics) HapticFeedback.lightImpact();
  }
}
