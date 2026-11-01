import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'settings.dart';
import 'theme.dart';

/// Panel que cambia de estilo según el ajuste "Liquid Glass":
/// desactivado = tarjeta sólida; activado = cristal translúcido con desenfoque.
class GlassBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? solidColor;

  /// Si es true, con el cristal apagado no dibuja tarjeta (solo el contenido).
  final bool transparentWhenOff;

  const GlassBox({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding,
    this.solidColor,
    this.transparentWhenOff = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final borderRadius = BorderRadius.circular(radius);
        if (!AppSettings.instance.liquidGlass) {
          if (transparentWhenOff) return child;
          return Container(
            padding: padding,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: solidColor ?? kCard,
              borderRadius: borderRadius,
            ),
            child: child,
          );
        }
        return ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x38FFFFFF), Color(0x12FFFFFF)],
                ),
                border: Border.all(color: const Color(0x4DFFFFFF), width: 0.8),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Fondo de la barra de navegación inferior (sólido o cristal).
class GlassBar extends StatelessWidget {
  final Widget child;
  const GlassBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        if (!AppSettings.instance.liquidGlass) {
          return ColoredBox(color: kBg, child: child);
        }
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0x660B0B0D),
                border: Border(top: BorderSide(color: Color(0x33FFFFFF), width: 0.6)),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
