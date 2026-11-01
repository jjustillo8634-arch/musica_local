import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'albums_page.dart';
import 'art_cache.dart';
import 'artists_page.dart';
import 'glass.dart';
import 'home_page.dart';
import 'library.dart';
import 'meta_store.dart';
import 'mini_player.dart';
import 'platform_bridge.dart';
import 'player_hub.dart';
import 'playlists.dart';
import 'settings.dart';
import 'songs_page.dart';
import 'theme.dart';

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
  );
  await ArtCache.init();
  await AppSettings.instance.load();
  await MetaStore.instance.load();
  // Al editar una canción o un artista se vuelven a agrupar álbumes y artistas.
  MetaStore.instance.addListener(MusicLibrary.instance.reindex);
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
    await PlatformBridge.requestNotifications();
    await MusicLibrary.instance.load();
    final songs = MusicLibrary.instance.songs;
    if (songs.isNotEmpty) await hub.prepareQueue(songs);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([MusicLibrary.instance, AppSettings.instance]),
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
          extendBody: AppSettings.instance.liquidGlass,
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
              GlassBar(
                child: NavigationBar(
                backgroundColor: Colors.transparent,
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
              ),
            ],
          ),
        );
      },
    );
  }
}
