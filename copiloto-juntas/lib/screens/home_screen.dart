import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
import '../settings.dart';
import '../store.dart';
import 'libreta_screen.dart';
import 'meeting_view.dart';
import 'settings_screen.dart';

/// Lista de juntas. En pantallas anchas (Mac) muestra la junta al lado;
/// en el iPhone la abre en otra pantalla.
class HomeScreen extends StatefulWidget {
  final MeetingStore store;
  final AppSettings settings;

  const HomeScreen({super.key, required this.store, required this.settings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MeetingSession? _session;

  bool _wide(BuildContext c) => MediaQuery.sizeOf(c).width >= 900;

  @override
  void initState() {
    super.initState();
    if (widget.settings.apiKey.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSettings());
    }
  }

  void _open(Meeting m) {
    if (_session?.meeting.id == m.id) {
      if (!_wide(context)) _push(_session!);
      return;
    }
    _session?.dispose();
    final s = MeetingSession(m, widget.store, widget.settings);
    setState(() => _session = s);
    if (!_wide(context)) _push(s);
  }

  void _push(MeetingSession s) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => Scaffold(
                  appBar: AppBar(
                      title: ListenableBuilder(
                          listenable: s,
                          builder: (_, _) => Text(s.meeting.displayTitle))),
                  body: MeetingView(session: s, store: widget.store),
                )))
        .then((_) {
      // Al regresar a la lista en el iPhone, deja de escuchar.
      if (s.transcriber.isRunning) s.stop();
    });
  }

  void _nueva() => _open(widget.store.create());

  Future<void> _delete(Meeting m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Borrar junta?'),
        content: Text('Se borrará “${m.displayTitle}” con sus notas y transcripción.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    if (_session?.meeting.id == m.id) {
      _session?.dispose();
      setState(() => _session = null);
    }
    await widget.store.delete(m.id);
  }

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(settings: widget.settings)));

  void _openLibreta() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LibretaScreen(store: widget.store)));

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = _wide(context);
    final list = ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final ms = widget.store.meetings;
        if (ms.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.groups_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                const Text('Cuando llegue alguien, toca “Nueva junta” y empieza a escuchar.',
                    textAlign: TextAlign.center),
              ]),
            ),
          );
        }
        return ListView.builder(
          itemCount: ms.length,
          itemBuilder: (c, i) {
            final m = ms[i];
            final d = m.date.toLocal();
            return ListTile(
              selected: wide && _session?.meeting.id == m.id,
              leading: const Icon(Icons.event_note_outlined),
              title: Text(m.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
                  '${m.notes.isEmpty ? '' : ' · ${m.notes.length} notas'}'),
              onTap: () => _open(m),
              trailing: IconButton(
                tooltip: 'Borrar',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(m),
              ),
            );
          },
        );
      },
    );

    final appBar = AppBar(
      title: const Text('Juntas'),
      actions: [
        IconButton(tooltip: 'Libreta de metáforas', icon: const Icon(Icons.lightbulb_outline), onPressed: _openLibreta),
        IconButton(tooltip: 'Ajustes', icon: const Icon(Icons.settings_outlined), onPressed: _openSettings),
      ],
    );
    final fab = FloatingActionButton.extended(
      onPressed: _nueva,
      icon: const Icon(Icons.add),
      label: const Text('Nueva junta'),
    );

    if (!wide) {
      return Scaffold(appBar: appBar, body: list, floatingActionButton: fab);
    }
    return Scaffold(
      body: Row(children: [
        SizedBox(
          width: 300,
          child: Scaffold(appBar: appBar, body: list, floatingActionButton: fab),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _session == null
              ? const Center(child: Text('Elige una junta o crea una nueva.'))
              : MeetingView(key: ValueKey(_session!.meeting.id), session: _session!, store: widget.store),
        ),
      ]),
    );
  }
}
