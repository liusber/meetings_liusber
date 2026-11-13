import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings get st => widget.settings;
  late final _key = TextEditingController(text: st.apiKey);
  late final _model = TextEditingController(text: st.model);
  late final _name = TextEditingController(text: st.myName);
  late final _role = TextEditingController(text: st.myRole);
  late String _locale = st.localeId;
  late double _interval = st.intervalSec.toDouble();
  late double _newsMin = st.newsMin.toDouble();
  bool _hideKey = true;

  static const _locales = {
    'es_MX': 'Español (México)',
    'es_ES': 'Español (España)',
    'en_US': 'Inglés (EE. UU.)',
  };

  @override
  void dispose() {
    for (final c in [_key, _model, _name, _role]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Pega la key desde el portapapeles y la guarda de una vez.
  Future<void> _pasteKey() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    if (!mounted) return;
    if (!text.startsWith('sk-ant-')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('En el portapapeles no hay una key de Claude (empieza con “sk-ant-”).')));
      return;
    }
    setState(() => _key.text = text);
    await st.update(apiKey: text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key pegada y guardada ✅')));
    }
  }

  Future<void> _save() async {
    await st.update(
      apiKey: _key.text,
      model: _model.text.isEmpty ? 'claude-opus-5-5' : _model.text,
      myName: _name.text,
      myRole: _role.text,
      localeId: _locale,
      intervalSec: _interval.round(),
      newsMin: _newsMin.round(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        actions: [TextButton(onPressed: _save, child: const Text('Guardar'))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Claude', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _key,
              obscureText: _hideKey,
              decoration: InputDecoration(
                labelText: 'API key de Claude',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_hideKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hideKey = !_hideKey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: _pasteKey,
                icon: const Icon(Icons.content_paste),
                label: const Text('Pegar key'),
              ),
              TextButton(
                onPressed: () => launchUrl(Uri.parse(
                    'https://platform.claude.com/settings/keys')),
                child: const Text('Sacar una key de Claude'),
              ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _model,
              decoration: const InputDecoration(
                labelText: 'Modelo',
                helperText: 'claude-opus-5-5 da las mejores sugerencias; claude-sonnet-5-5 o claude-haiku-5-5 son más baratos y rápidos.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('Sobre ti', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Tu nombre (para firmar correos)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _role,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Tu rol (el copiloto lo usa de contexto)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            Text('Escucha', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _locale,
              decoration: const InputDecoration(labelText: 'Idioma de la junta', border: OutlineInputBorder()),
              items: [
                for (final e in _locales.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _locale = v ?? _locale),
            ),
            const SizedBox(height: 16),
            Text('El copiloto sugiere cada ${_interval.round()} segundos (si hubo plática nueva)'),
            Slider(
              value: _interval,
              min: 15,
              max: 120,
              divisions: 21,
              label: '${_interval.round()} s',
              onChanged: (v) => setState(() => _interval = v),
            ),
            const SizedBox(height: 8),
            Text(_newsMin.round() == 0
                ? 'Noticias tech: solo cuando toques 📰'
                : 'Noticia tech real (web) cada ${_newsMin.round()} min mientras escucha'),
            Slider(
              value: _newsMin,
              min: 0,
              max: 15,
              divisions: 15,
              label: _newsMin.round() == 0 ? 'apagado' : '${_newsMin.round()} min',
              onChanged: (v) => setState(() => _newsMin = v),
            ),
            const SizedBox(height: 16),
            Text(
              'Privacidad: la transcripción y tus notas se guardan solo en este equipo; en Mac y iPhone el audio se transcribe sin salir de él. '
              'Para darte sugerencias se envía un fragmento a Claude (Anthropic). '
              'Avisa a la otra persona que estás transcribiendo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
        ),
      ),
    );
  }
}
