import 'package:flutter/material.dart';

import 'default_cover.dart';
import 'icon_previews.dart';
import 'platform_bridge.dart';
import 'settings.dart';
import 'theme.dart';

/// Personalización: forma de las portadas, efectos y icono de la app.
class PersonalizationPage extends StatelessWidget {
  const PersonalizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personalización')),
      body: ListenableBuilder(
        listenable: AppSettings.instance,
        builder: (context, _) {
          final s = AppSettings.instance;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _Label('Forma de las portadas'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final shape in CoverShape.values) ...[
                      Expanded(child: _ShapeOption(shape: shape)),
                      if (shape != CoverShape.values.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
              if (s.coverShape == CoverShape.rounded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      const Text('Redondeo'),
                      Expanded(
                        child: Slider(
                          min: 0.3,
                          max: 2.0,
                          value: s.roundness.clamp(0.3, 2.0).toDouble(),
                          activeColor: kRed,
                          onChanged: (v) => s.update((x) => x.roundness = v),
                        ),
                      ),
                    ],
                  ),
                ),

              const _Label('Efectos'),
              _SwitchTile(
                icon: Icons.blur_on,
                title: 'Fondo difuminado',
                subtitle: 'Muestra la portada desenfocada detrás del reproductor',
                value: s.blurBackdrop,
                onChanged: (v) => s.update((x) => x.blurBackdrop = v),
              ),
              _SwitchTile(
                icon: Icons.water_drop_outlined,
                title: 'Liquid Glass',
                subtitle:
                    'Paneles de cristal translúcido en el mini reproductor, la barra inferior y el reproductor',
                value: s.liquidGlass,
                onChanged: (v) => s.update((x) => x.liquidGlass = v),
              ),
              _SwitchTile(
                icon: Icons.album_outlined,
                title: 'Disco de vinilo',
                subtitle: 'Con portada circular, gira mientras suena la música',
                value: s.vinylSpin,
                onChanged: (v) => s.update((x) => x.vinylSpin = v),
              ),
              _SwitchTile(
                icon: Icons.graphic_eq,
                title: 'Barras animadas',
                subtitle: 'Indicador animado en la canción que está sonando',
                value: s.playingBars,
                onChanged: (v) => s.update((x) => x.playingBars = v),
              ),
              _SwitchTile(
                icon: Icons.vibration,
                title: 'Vibración suave',
                subtitle: 'Un toque háptico al usar los controles',
                value: s.haptics,
                onChanged: (v) => s.update((x) => x.haptics = v),
              ),

              const _Label('Icono de la app'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: const [
                    Expanded(child: _IconOption(name: 'normal', label: 'Normal')),
                    SizedBox(width: 10),
                    Expanded(child: _IconOption(name: 'dark', label: 'Oscuro')),
                    SizedBox(width: 10),
                    Expanded(child: _IconOption(name: 'glass', label: 'Cristal')),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  'Al cambiar el icono, tu pantalla de inicio puede tardar unos segundos en '
                  'actualizarse y la app podría cerrarse una vez. Es normal en Android.',
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: kRed),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: kMuted, fontSize: 12.5)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ShapeOption extends StatelessWidget {
  final CoverShape shape;
  const _ShapeOption({required this.shape});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    final selected = s.coverShape == shape;
    final label = switch (shape) {
      CoverShape.rounded => 'Redondeada',
      CoverShape.square => 'Cuadrada',
      CoverShape.circle => 'Circular',
    };

    final image = Image.memory(
      kDefaultCoverBytes,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
    );
    final preview = switch (shape) {
      CoverShape.circle => ClipOval(child: image),
      CoverShape.square => ClipRect(child: image),
      CoverShape.rounded => ClipRRect(
          borderRadius: BorderRadius.circular(16 * s.roundness),
          child: image,
        ),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Haptics.tap();
        s.update((x) => x.coverShape = shape);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? kRed : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            SizedBox(width: 64, height: 64, child: preview),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? kRed : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconOption extends StatelessWidget {
  final String name;
  final String label;
  const _IconOption({required this.name, required this.label});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    final selected = s.launcherIcon == name;
    final bytes = switch (name) {
      'dark' => kIconDark,
      'glass' => kIconGlass,
      _ => kIconNormal,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        if (selected) return;
        final messenger = ScaffoldMessenger.of(context);
        final ok = await PlatformBridge.setLauncherIcon(name);
        if (ok) {
          s.update((x) => x.launcherIcon = name);
          messenger.showSnackBar(
            const SnackBar(content: Text('Icono cambiado')),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('No se pudo cambiar el icono en este teléfono')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? kRed : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            // Fondo colorido para que se note la transparencia del icono de cristal.
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B6BD6), Color(0xFFB343C9)],
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? kRed : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
