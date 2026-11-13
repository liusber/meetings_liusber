import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../session.dart';
import '../store.dart';

/// Columna de tarjetas: la guía del copiloto o, con [news], las noticias tech.
/// Lo más reciente va arriba.
class CopilotPane extends StatelessWidget {
  final MeetingSession session;
  final MeetingStore store;
  final bool news;

  const CopilotPane({super.key, required this.session, required this.store, this.news = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tips = session.meeting.tips.where((t) => t.noticia.isNotEmpty == news).toList();
    final busy = news ? session.fetchingNews : session.thinking;
    final running = session.transcriber.isRunning;
    final newsMin = session.settings.newsMin;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          Icon(news ? Icons.newspaper : Icons.auto_awesome, color: news ? cs.tertiary : cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              news
                  ? (running && newsMin > 0 ? 'Noticias tech · cada $newsMin min' : 'Noticias tech')
                  : (running ? 'Guía · cada ${session.settings.intervalSec} s' : 'Guía PM de TI'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (news) ...[
            TextButton(
              onPressed: busy ? null : () => session.news(apple: true),
              child: const Text('Apple'),
            ),
            FilledButton.tonalIcon(
              onPressed: busy ? null : session.news,
              icon: const Icon(Icons.search),
              label: const Text('Tech'),
            ),
          ] else
            FilledButton.tonalIcon(
              onPressed: busy ? null : session.coach,
              icon: const Icon(Icons.bolt),
              label: const Text('Guíame ahora'),
            ),
        ]),
      ),
      if (session.copilotError != null && !news)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(session.copilotError!, style: TextStyle(color: cs.error)),
        ),
      if (session.newsError != null && news)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(session.newsError!, style: TextStyle(color: cs.error)),
        ),
      Expanded(
        child: tips.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    news
                        ? 'Aquí llegan noticias reales de tecnología para comentar, '
                            'incluidas las de Apple (iPhone, iPad, Mac, fechas de lanzamiento).\n'
                            'Toca “Tech” o “Apple” para pedir una ahora.'
                        : 'Empieza a escuchar o toca “Guíame ahora”.\n'
                            'Aquí verás requerimientos detectados, preguntas, objeciones, '
                            'qué automatizar y datos de TI para compartir.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: tips.length,
                itemBuilder: (c, i) => _TipCard(
                  tip: tips[i],
                  latest: i == 0,
                  session: session,
                  store: store,
                ),
              ),
      ),
    ]);
  }
}

class _TipCard extends StatelessWidget {
  final CoachTip tip;
  final bool latest;
  final MeetingSession session;
  final MeetingStore store;

  const _TipCard({required this.tip, required this.latest, required this.session, required this.store});

  void _pin(BuildContext context, String text) {
    session.addNote(text);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregado a tus notas'), duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = tip.date.toLocal();
    return Opacity(
      opacity: latest ? 1 : 0.7,
      child: Card(
        elevation: latest ? 2 : 0,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tip.lectura,
                    style: tip.noticia.isNotEmpty
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ),
            ]),
            if (tip.requerimiento.trim().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  onTap: () => _pin(context, 'Requerimiento: ${tip.requerimiento}'),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.assignment_outlined, color: cs.onPrimaryContainer, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Requerimiento detectado',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onPrimaryContainer)),
                        Text(tip.requerimiento,
                            style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    Icon(Icons.push_pin_outlined, size: 14, color: cs.onPrimaryContainer),
                  ]),
                ),
              ),
            _section(
                context,
                Icons.help_outline,
                tip.requerimiento.trim().isNotEmpty ? 'Pregunta para aterrizarlo' : 'Pregunta',
                cs.primary,
                tip.preguntas),
            _section(context, Icons.shield_outlined, 'Objeción / riesgo', cs.error, tip.objeciones),
            _section(context, Icons.settings_suggest_outlined, 'Automatizar', cs.tertiary, tip.automatizar),
            if (tip.notaIT.trim().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lightbulb_outline, color: cs.onSecondaryContainer, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tip.notaTipo == 'metáfora' ? 'Metáfora para compartir' : 'Dato de TI para compartir',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSecondaryContainer)),
                      SelectableText(tip.notaIT, style: TextStyle(color: cs.onSecondaryContainer)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Guardar en Libreta IT',
                    icon: Icon(Icons.bookmark_add_outlined, color: cs.onSecondaryContainer),
                    onPressed: () {
                      store.addToLibreta(tip.notaIT);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Guardado en tu Libreta IT'), duration: Duration(seconds: 1)));
                    },
                  ),
                ]),
              ),
            if (tip.noticia.trim().isNotEmpty) _news(context),
          ]),
        ),
      ),
    );
  }

  Widget _news(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = '${tip.lectura}. ${tip.noticia}';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.newspaper, color: cs.onTertiaryContainer, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Noticia tech para comentar',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onTertiaryContainer)),
            SelectableText(tip.noticia, style: TextStyle(color: cs.onTertiaryContainer)),
            if (tip.noticiaFuente.isNotEmpty || tip.noticiaUrl.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: tip.noticiaUrl.isEmpty ? null : () => launchUrl(Uri.parse(tip.noticiaUrl)),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(tip.noticiaFuente.isNotEmpty ? tip.noticiaFuente : 'Ver fuente'),
              ),
          ]),
        ),
        IconButton(
          tooltip: 'Guardar en Libreta IT',
          icon: Icon(Icons.bookmark_add_outlined, color: cs.onTertiaryContainer),
          onPressed: () {
            store.addToLibreta(tip.noticiaFuente.isEmpty ? text : '$text (${tip.noticiaFuente})');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Guardado en tu Libreta IT'), duration: Duration(seconds: 1)));
          },
        ),
      ]),
    );
  }

  Widget _section(BuildContext context, IconData icon, String label, Color color, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
        ]),
        for (final it in items)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _pin(context, '$label: $it'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  '),
                Expanded(child: Text(it, style: const TextStyle(fontSize: 15))),
                Icon(Icons.push_pin_outlined, size: 14, color: Theme.of(context).hintColor),
              ]),
            ),
          ),
      ]),
    );
  }
}
