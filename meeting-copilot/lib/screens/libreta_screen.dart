import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../store.dart';

/// Datos y metáforas de TI guardados de todas las juntas, para reusar.
class LibretaScreen extends StatefulWidget {
  final MeetingStore store;

  const LibretaScreen({super.key, required this.store});

  @override
  State<LibretaScreen> createState() => _LibretaScreenState();
}

class _LibretaScreenState extends State<LibretaScreen> {
  final _new = TextEditingController();

  @override
  void dispose() {
    _new.dispose();
    super.dispose();
  }

  void _add() {
    final t = _new.text.trim();
    if (t.isEmpty) return;
    widget.store.addToLibreta(t);
    _new.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Libreta IT')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final items = widget.store.libreta;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _new,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(
                        hintText: 'Agrega un dato o metáfora propia…', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
              ]),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Guarda aquí los datos y metáforas de TI que te sugiera el copiloto (ícono de marcador).',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final n = items[i];
                        return ListTile(
                          leading: const Icon(Icons.lightbulb_outline),
                          title: SelectableText(n.text),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: 'Copiar',
                              icon: const Icon(Icons.copy, size: 20),
                              onPressed: () => Clipboard.setData(ClipboardData(text: n.text)),
                            ),
                            IconButton(
                              tooltip: 'Compartir',
                              icon: const Icon(Icons.ios_share, size: 20),
                              onPressed: () => SharePlus.instance.share(ShareParams(text: n.text)),
                            ),
                            IconButton(
                              tooltip: 'Quitar',
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => widget.store.removeFromLibreta(n.id),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
