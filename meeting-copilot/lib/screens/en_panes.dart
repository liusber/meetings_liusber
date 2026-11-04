import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';

String _hhmm(DateTime d) {
  final t = d.toLocal();
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

Widget _paneHeader(BuildContext context, IconData icon, String title,
    {bool busy = false, Widget? action}) {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    child: Row(children: [
      Icon(icon, color: cs.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
      if (busy)
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ?action,
    ]),
  );
}

/// Lo que se dice en inglés y su traducción, lo más reciente abajo.
class TranslationPane extends StatefulWidget {
  final MeetingSession session;

  const TranslationPane({super.key, required this.session});

  @override
  State<TranslationPane> createState() => _TranslationPaneState();
}

class _TranslationPaneState extends State<TranslationPane> {
  final _scroll = ScrollController();
  bool _showEnglish = true;
  int _count = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final cs = Theme.of(context).colorScheme;
    final items = s.meeting.translations;
    final partial = s.transcriber.partial;
    final count = items.length + partial.length;
    if (count != _count) {
      _count = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
    return Column(children: [
      _paneHeader(
        context,
        Icons.translate,
        'Traducción en vivo',
        busy: s.translating,
        action: TextButton(
          onPressed: () => setState(() => _showEnglish = !_showEnglish),
          child: Text(_showEnglish ? 'Ocultar inglés' : 'Ver inglés'),
        ),
      ),
      if (s.translateError != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(s.translateError!, style: TextStyle(color: cs.error)),
        ),
      Expanded(
        child: items.isEmpty && partial.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Dale “Escuchar junta”.\nAquí verás lo que dicen en inglés traducido al español, '
                    'y se marcan las preguntas, solicitudes, decisiones y compromisos.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                children: [
                  for (final t in items) _TranslationTile(t: t, showEnglish: _showEnglish),
                  if (partial.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('… $partial',
                          style: TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
      ),
    ]);
  }
}

class _TranslationTile extends StatelessWidget {
  final Translation t;
  final bool showEnglish;

  const _TranslationTile({required this.t, required this.showEnglish});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mark = t.marca.isNotEmpty;
    final question = t.marca == 'pregunta' || t.marca == 'solicitud';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: question ? cs.primaryContainer : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_hhmm(t.date), style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          if (mark) ...[
            const SizedBox(width: 8),
            Text(t.marca.toUpperCase(),
                style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
          ],
        ]),
        if (t.es.isNotEmpty) ...[
          const SizedBox(height: 4),
          SelectableText(t.es, style: tt.bodyLarge?.copyWith(height: 1.3)),
        ],
        if (showEnglish || t.es.isEmpty) ...[
          const SizedBox(height: 4),
          SelectableText(t.en, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

/// Sugerencias del copiloto: qué te preguntaron, qué responder y qué preguntar.
class EnCopilotPane extends StatelessWidget {
  final MeetingSession session;

  const EnCopilotPane({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tips = session.meeting.enTips;
    return Column(children: [
      _paneHeader(
        context,
        Icons.auto_awesome,
        session.transcriber.isRunning
            ? 'Copiloto · cada ${session.settings.intervalSec} s'
            : 'Copiloto',
        busy: session.thinking,
        action: FilledButton.tonalIcon(
          onPressed: session.thinking ? null : session.coach,
          icon: const Icon(Icons.bolt),
          label: const Text('¿Qué digo?'),
        ),
      ),
      if (session.copilotError != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(session.copilotError!, style: TextStyle(color: cs.error)),
        ),
      Expanded(
        child: tips.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Cuando te pregunten algo, aquí aparece qué te preguntaron y cómo responder en inglés.\n'
                    'También preguntas para tu objetivo y lo que falta cubrir.\n'
                    'Toca “¿Qué digo?” cuando lo necesites.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: tips.length,
                itemBuilder: (c, i) => _EnTipCard(tip: tips[i], latest: i == 0, session: session),
              ),
      ),
    ]);
  }
}

class _EnTipCard extends StatelessWidget {
  final EnTip tip;
  final bool latest;
  final MeetingSession session;

  const _EnTipCard({required this.tip, required this.latest, required this.session});

  void _pin(BuildContext context, String text) {
    session.addNote(text);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregado a tus notas'), duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Text(text, style: tt.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
        );

    Widget phrase(Phrase p) => InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pin(context, '${p.en} — ${p.es}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('“${p.en}”', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3)),
              Text(p.es, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
        );

    Widget bullet(String text) => InkWell(
          onTap: () => _pin(context, text),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('• $text'),
          ),
        );

    return Opacity(
      opacity: latest ? 1 : 0.6,
      child: Card(
        margin: const EdgeInsets.only(top: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_hhmm(tip.date), style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(width: 8),
              Expanded(child: Text(tip.lectura, style: tt.bodySmall)),
            ]),
            if (tip.tePreguntaron.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Te preguntaron: ${tip.tePreguntaron}',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
            if (tip.ritmo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.speed, size: 16, color: cs.tertiary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(tip.ritmo, style: tt.bodySmall?.copyWith(color: cs.tertiary))),
                ]),
              ),
            if (tip.respuestas.isNotEmpty) ...[
              label('Puedes responder'),
              for (final p in tip.respuestas) phrase(p),
            ],
            if (tip.preguntas.isNotEmpty) ...[
              label('Pregunta tú'),
              for (final p in tip.preguntas) phrase(p),
            ],
            if (tip.recomendaciones.isNotEmpty) ...[
              label('Recomendación técnica (no es oferta)'),
              for (final p in tip.recomendaciones) phrase(p),
            ],
            if (tip.acuerdos.isNotEmpty) ...[
              label('Acuerdos y compromisos'),
              for (final a in tip.acuerdos) bullet(a),
            ],
            if (tip.pendientes.isNotEmpty) ...[
              label('Falta cubrir de tu objetivo'),
              for (final p in tip.pendientes) bullet(p),
            ],
            if (tip.vocabulario.isNotEmpty) ...[
              label('Vocabulario'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final v in tip.vocabulario)
                  Tooltip(
                    message: v.es,
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${v.en}: ${v.es}'),
                    ),
                  ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
