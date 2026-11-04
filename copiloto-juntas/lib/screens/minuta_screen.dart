import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../session.dart';

/// Pestaña "Resumen y acuerdos": se genera con Gemini solo cuando lo pides.
/// El correo se abre como borrador en la app de correo: tú das Enviar.
class MinutaPane extends StatefulWidget {
  final MeetingSession session;

  const MinutaPane({super.key, required this.session});

  @override
  State<MinutaPane> createState() => _MinutaPaneState();
}

class _MinutaPaneState extends State<MinutaPane> {
  MeetingSession get s => widget.session;
  final _para = TextEditingController();
  final _asunto = TextEditingController();
  final _cuerpo = TextEditingController();
  Minuta? _bound;

  @override
  void dispose() {
    _para.dispose();
    _asunto.dispose();
    _cuerpo.dispose();
    super.dispose();
  }

  void _bind(Minuta m) {
    if (identical(_bound, m)) return;
    _bound = m;
    _para.text = m.correo.para;
    _asunto.text = m.correo.asunto;
    _cuerpo.text = m.correo.cuerpo;
  }

  Future<void> _openMail() async {
    final q =
        'subject=${Uri.encodeComponent(_asunto.text)}&body=${Uri.encodeComponent(_cuerpo.text)}';
    final uri = Uri.parse(
      'mailto:${Uri.encodeComponent(_para.text.trim()).replaceAll('%40', '@')}?$q',
    );
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No encontré una app de correo. Usa Copiar.'),
        ),
      );
    }
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what copiado')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final m = s.meeting.minuta;
        if (m != null) _bind(m);
        return Column(
          children: [
            if (m != null && !s.makingMinuta)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Resumen y acuerdos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Compartir',
                      icon: const Icon(Icons.ios_share),
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: m.asText(s.meeting.displayTitle)),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: s.makeMinuta,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Volver a generar'),
                    ),
                  ],
                ),
              ),
            Expanded(child: _body(context, m)),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, Minuta? m) {
    final cs = Theme.of(context).colorScheme;
    if (s.makingMinuta) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Preparando resumen, acuerdos y correo…'),
          ],
        ),
      );
    }
    if (m == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (s.copilotError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    s.copilotError!,
                    style: TextStyle(color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              const Text(
                'Cuando termine la junta, genera el resumen, los acuerdos, los pendientes '
                'y el correo de seguimiento con lo que se habló y tus notas.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: s.makeMinuta,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generar resumen y acuerdos'),
              ),
            ],
          ),
        ),
      );
    }

    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (s.copilotError != null)
          Text(s.copilotError!, style: TextStyle(color: cs.error)),
        Text('Resumen', style: tt.titleSmall),
        const SizedBox(height: 4),
        SelectableText(m.resumen),
        if (m.acuerdos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Acuerdos', style: tt.titleSmall),
          for (final a in m.acuerdos) SelectableText('• $a'),
        ],
        if (m.pendientes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Pendientes', style: tt.titleSmall),
          for (final p in m.pendientes) SelectableText('• $p'),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _copy(m.asText(s.meeting.displayTitle), 'Minuta'),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar minuta'),
          ),
        ),
        const Divider(height: 32),
        Text('Correo de seguimiento', style: tt.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _para,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Para',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            m.correo.para = v;
            s.changed();
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _asunto,
          decoration: const InputDecoration(
            labelText: 'Asunto',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            m.correo.asunto = v;
            s.changed();
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _cuerpo,
          minLines: 8,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: 'Cuerpo',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (v) {
            m.correo.cuerpo = v;
            s.changed();
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _openMail,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Abrir borrador en Mail'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  _copy('${_asunto.text}\n\n${_cuerpo.text}', 'Correo'),
              icon: const Icon(Icons.copy),
              label: const Text('Copiar correo'),
            ),
          ],
        ),
      ],
    );
  }
}
