import 'package:flutter/material.dart';

import 'player_hub.dart';

class EqualizerPage extends StatelessWidget {
  const EqualizerPage({super.key});

  String _hz(double hz) {
    if (hz < 1000) return '${hz.round()} Hz';
    final k = hz / 1000;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)} kHz';
  }

  String _db(double g) {
    final sign = g > 0.05 ? '+' : '';
    return '$sign${g.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final hub = PlayerHub.instance;
    final small = Theme.of(context).textTheme.labelSmall;

    return Scaffold(
      appBar: AppBar(title: const Text('Ecualizador')),
      body: ListenableBuilder(
        listenable: hub,
        builder: (context, _) {
          final params = hub.params;
          if (params == null || hub.gains.length != params.bands.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cargando ecualizador…\n'
                  'Si no aparece, reproduce una canción y vuelve.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final bands = params.bands;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('Activar ecualizador'),
                value: hub.eqEnabled,
                onChanged: hub.setEqEnabled,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (hub.presetName == 'Personalizado')
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('Personalizado'),
                          selected: true,
                          onSelected: null,
                        ),
                      ),
                    for (final preset in eqPresets)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(preset.name),
                          selected: hub.presetName == preset.name,
                          onSelected: (_) => hub.applyPreset(preset),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Opacity(
                opacity: hub.eqEnabled ? 1 : 0.4,
                child: IgnorePointer(
                  ignoring: !hub.eqEnabled,
                  child: SizedBox(
                    height: 300,
                    child: Row(
                      children: [
                        for (var i = 0; i < bands.length; i++)
                          Expanded(
                            child: Column(
                              children: [
                                Text(_db(hub.gains[i]), style: small),
                                Expanded(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Slider(
                                      min: params.minDecibels,
                                      max: params.maxDecibels,
                                      value: hub.gains[i]
                                          .clamp(params.minDecibels, params.maxDecibels)
                                          .toDouble(),
                                      onChanged: (v) => hub.setBandGain(i, v),
                                      onChangeEnd: (_) => hub.saveEq(),
                                    ),
                                  ),
                                ),
                                Text(_hz(bands[i].centerFrequency), style: small),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Rango: ${_db(params.minDecibels)} a ${_db(params.maxDecibels)} dB',
                textAlign: TextAlign.center,
                style: small,
              ),
            ],
          );
        },
      ),
    );
  }
}
