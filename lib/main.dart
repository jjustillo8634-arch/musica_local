import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'albums_page.dart';
import 'art_cache.dart';
import 'artists_page.dart';
import 'home_page.dart';
import 'library.dart';
import 'mini_player.dart';
import 'player_hub.dart';
import 'playlists.dart';
import 'songs_page.dart';
import 'theme.dart';

const _permissions = MethodChannel('musica_local/permissions');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.musica_local.channel.audio',
    androidNotificationChannelName: 'Reproducción de música',
    // La notificación (con controles y portada) se queda también en pausa,
    // así se puede reanudar desde la pantalla de bloqueo.
    androidNotificationOngoing: false,
    androidStopForegroundOnPause: false,
    androidNotificationIcon: 'drawable/ic_music_note',
    notificationColor: kRed,
    preloadArtwork: true,
  );
  await ArtCache.init();
  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi música',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final hub = PlayerHub.instance;
    await hub.init();
    await PlaylistStore.instance.load();
    // Android 13+: permiso para mostrar la notificación con controles.
    try {
      await const MethodChannel('musica_local/permissions')
          .invokeMethod<void>('requestNotifications');
    } catch (_) {}
    await MusicLibrary.instance.load();
    final songs = MusicLibrary.instance.songs;
    if (songs.isNotEmpty) await hub.prepareQueue(songs);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MusicLibrary.instance,
      builder: (context, _) {
        final lib = MusicLibrary.instance;

        if (lib.loading && lib.songs.isEmpty) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: kRed)),
          );
        }

        if (lib.denied) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Necesito permiso para leer tu música.\n'
                      'Concédelo en Ajustes del teléfono y vuelve a intentar.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _boot,
                      style: FilledButton.styleFrom(backgroundColor: kRed),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (lib.songs.isEmpty) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No se encontraron canciones en el teléfono.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _boot,
                      style: FilledButton.styleFrom(backgroundColor: kRed),
                      child: const Text('Actualizar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: const [
              HomePage(),
              SongsPage(),
              ArtistsPage(),
              AlbumsPage(),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayer(),
              NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Inicio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.music_note_outlined),
                    selectedIcon: Icon(Icons.music_note),
                    label: 'Canciones',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Artistas',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.album_outlined),
                    selectedIcon: Icon(Icons.album),
                    label: 'Álbumes',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
