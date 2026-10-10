import 'package:flutter/material.dart';

import 'equalizer_page.dart';
import 'library.dart';
import 'sleep_timer_sheet.dart';
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.equalizer, color: kRed),
            title: const Text('Ecualizador'),
            subtitle: const Text('Graves, agudos y presets'),
            trailing: const Icon(Icons.chevron_right, color: kMuted),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EqualizerPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined, color: kRed),
            title: const Text('Temporizador de apagado'),
            subtitle: const Text('Detén la música automáticamente'),
            trailing: const Icon(Icons.chevron_right, color: kMuted),
            onTap: () => showSleepTimerSheet(context),
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: kRed),
            title: const Text('Actualizar biblioteca'),
            subtitle: const Text('Busca canciones nuevas en el teléfono'),
            onTap: () {
              MusicLibrary.instance.load();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Actualizando biblioteca…')),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline, color: kMuted),
            title: Text('Mi música'),
            subtitle: Text('Reproductor de música local'),
          ),
        ],
      ),
    );
  }
}
