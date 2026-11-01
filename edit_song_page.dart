import 'dart:io';

import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import 'artwork.dart';
import 'meta_store.dart';
import 'platform_bridge.dart';
import 'theme.dart';

/// Editar el nombre, los artistas, el álbum y la foto de una canción.
/// Los cambios se guardan dentro de la app (el archivo no se modifica).
class EditSongPage extends StatefulWidget {
  final SongModel song;
  const EditSongPage({super.key, required this.song});

  @override
  State<EditSongPage> createState() => _EditSongPageState();
}

class _EditSongPageState extends State<EditSongPage> {
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late final TextEditingController _album;

  String? _pickedTemp; // imagen elegida, aún sin guardar
  bool _removeCover = false;
  bool _applyToAlbum = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.song;
    _title = TextEditingController(text: s.shownTitle);
    _artist = TextEditingController(text: s.rawArtist ?? '');
    _album = TextEditingController(text: s.rawAlbum ?? '');
    for (final c in [_artist, _album]) {
      if (c.text.trim() == '<unknown>') c.text = '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await PlatformBridge.pickImage();
    if (path != null && mounted) {
      setState(() {
        _pickedTemp = path;
        _removeCover = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await MetaStore.instance.saveSongEdits(
      widget.song,
      title: _title.text,
      artist: _artist.text,
      album: _album.text,
      newCoverTempPath: _pickedTemp,
      removeCover: _removeCover,
      applyCoverToAlbum: _applyToAlbum,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cambios guardados')),
    );
  }

  void _reset() {
    MetaStore.instance.resetSong(widget.song.id);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Valores originales restaurados')),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: kCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final song = widget.song;

    Widget preview;
    if (_pickedTemp != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.file(File(_pickedTemp!), fit: BoxFit.cover, cacheWidth: 600),
      );
    } else if (_removeCover) {
      preview = Artwork(albumId: null, px: 600, radius: 22, iconSize: 80);
    } else {
      preview = Artwork(
        albumId: song.albumId,
        songId: song.id,
        px: 600,
        radius: 22,
        iconSize: 80,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar información'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text(
              'Guardar',
              style: TextStyle(color: kRed, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(child: SizedBox(width: 200, height: 200, child: preview)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Cambiar foto'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _pickedTemp = null;
                    _removeCover = true;
                  }),
                  icon: const Icon(Icons.hide_image_outlined),
                  label: const Text('Quitar foto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (song.albumId != null)
            CheckboxListTile(
              value: _applyToAlbum,
              onChanged: (v) => setState(() => _applyToAlbum = v ?? false),
              activeColor: kRed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Usar esta foto para todo el álbum'),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Nombre de la canción'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _artist,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration(
              'Artista(s)',
              hint: 'Ej.: Artista 1, Artista 2',
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Text(
              'Separa varios artistas con coma, & o feat.: la canción aparecerá en la página de cada uno.',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _album,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration('Álbum'),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restore),
            label: const Text('Restaurar valores originales'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kRed,
              side: const BorderSide(color: kRed),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Los cambios se guardan dentro de la app y no modifican el archivo de audio. '
            'La notificación se actualiza la próxima vez que reproduzcas la canción.',
            style: TextStyle(color: kMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
