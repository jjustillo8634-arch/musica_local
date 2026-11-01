import 'package:flutter/material.dart';

import 'player_hub.dart';
import 'theme.dart';

/// Hoja inferior para programar el apagado automático de la música.
void showSleepTimerSheet(BuildContext context) {
  final hub = PlayerHub.instance;
  const minutes = <int>[5, 10, 15, 30, 45, 60, 90];

  String nameOf(int m) {
    if (m < 60) return '$m minutos';
    if (m == 60) return '1 hora';
    return '1 hora y 30 minutos';
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: ValueListenableBuilder<String?>(
          valueListenable: hub.sleepLabel,
          builder: (ctx, label, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Temporizador de apagado',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label == null
                          ? 'La música se detendrá sola.'
                          : label == 'Fin de canción'
                              ? 'Se detendrá al terminar la canción.'
                              : 'La música se detiene en $label.',
                      style: TextStyle(color: label == null ? kMuted : kRed),
                    ),
                  ),
                ),
                for (final m in minutes)
                  ListTile(
                    leading: const Icon(Icons.timer_outlined, color: kMuted),
                    title: Text(nameOf(m)),
                    onTap: () {
                      hub.startSleepTimer(Duration(minutes: m));
                      Navigator.pop(ctx);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.music_note, color: kMuted),
                  title: const Text('Al terminar la canción'),
                  onTap: () {
                    hub.sleepAfterCurrentTrack();
                    Navigator.pop(ctx);
                  },
                ),
                if (label != null)
                  ListTile(
                    leading: const Icon(Icons.timer_off_outlined, color: kRed),
                    title: const Text(
                      'Desactivar temporizador',
                      style: TextStyle(color: kRed, fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      hub.cancelSleepTimer();
                      Navigator.pop(ctx);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    ),
  );
}
