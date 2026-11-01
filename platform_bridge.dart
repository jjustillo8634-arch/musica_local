import 'package:flutter/services.dart';

/// Funciones nativas de Android: permisos, elegir imágenes y cambiar el icono.
class PlatformBridge {
  static const _channel = MethodChannel('musica_local/platform');

  /// Android 13+: pide permiso para mostrar la notificación con controles.
  static Future<void> requestNotifications() async {
    try {
      await _channel.invokeMethod<void>('requestNotifications');
    } catch (_) {}
  }

  /// Abre el selector de imágenes y devuelve la ruta de una copia temporal.
  static Future<String?> pickImage() async {
    try {
      return await _channel.invokeMethod<String>('pickImage');
    } catch (_) {
      return null;
    }
  }

  /// Cambia el icono de la app: 'normal', 'dark' o 'glass'.
  static Future<bool> setLauncherIcon(String name) async {
    try {
      final alias = switch (name) {
        'dark' => 'IconDark',
        'glass' => 'IconGlass',
        _ => 'IconNormal',
      };
      final ok = await _channel.invokeMethod<bool>('setLauncherIcon', {'name': alias});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
