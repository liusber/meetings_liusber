import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../phrases.dart';
import '../session.dart';

void copyPhrase(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copiada: $text'), duration: const Duration(seconds: 2)));
}

/// Una frase rápida en inglés y español; un clic la copia.
class QuickPhraseTile extends StatelessWidget {
  final QuickPhrase phrase;
  final bool highlighted;

  const QuickPhraseTile({super.key, required this.phrase, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: highlighted ? cs.primaryContainer : cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: highlighted ? cs.primary : cs.outlineVariant, width: highlighted ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => copyPhrase(context, phrase.en),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(phrase.en, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.3)),
                  Text(phrase.es, style: tt.bodySmall),
                  Text(phrase.uso, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              Icon(highlighted ? Icons.star : Icons.copy, size: 16,
                  color: highlighted ? cs.primary : cs.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Todas las frases de ayuda rápida, por intención. Siempre visibles.
class QuickPhrasesPane extends StatelessWidget {
  final MeetingSession session;

  const QuickPhrasesPane({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hl = session.highlightedPhrases;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        Text('Un clic copia la frase. ★ = la recomienda el copiloto ahora.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        for (final g in quickPhrases.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 2),
            child: Text(g.key, style: tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
          ),
          for (final p in g.value) QuickPhraseTile(phrase: p, highlighted: hl.contains(p.id)),
        ],
      ],
    );
  }
}

/// Conectores en acordeón, por propósito.
class ConnectorsPane extends StatelessWidget {
  const ConnectorsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      children: [
        for (final g in connectors.entries)
          ExpansionTile(
            title: Text(g.key, style: tt.titleSmall),
            shape: const Border(),
            collapsedShape: const Border(),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              for (final c in g.value)
                InkWell(
                  onTap: () => copyPhrase(context, c.ejemplo),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 130,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.en, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text(c.es, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ]),
                      ),
                      Expanded(child: Text(c.ejemplo, style: tt.bodyMedium)),
                    ]),
                  ),
                ),
            ],
          ),
        ExpansionTile(
          title: Text('Ejemplo: cómo usarlos con Nick', style: tt.titleSmall),
          shape: const Border(),
          collapsedShape: const Border(),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sin conectores', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
            Text(connectorsExample.sin, style: tt.bodyMedium),
            const SizedBox(height: 10),
            Text('Con conectores', style: tt.labelMedium?.copyWith(color: cs.primary)),
            for (final l in connectorsExample.con)
              InkWell(
                onTap: () => copyPhrase(context, l),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(l, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
