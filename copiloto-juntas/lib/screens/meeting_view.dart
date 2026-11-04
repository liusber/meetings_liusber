import 'package:flutter/material.dart';

import '../session.dart';
import '../store.dart';
import 'copilot_pane.dart';
import 'minuta_screen.dart';
import 'resizable_row.dart';

class MeetingView extends StatefulWidget {
  final MeetingSession session;
  final MeetingStore store;

  const MeetingView({super.key, required this.session, required this.store});

  @override
  State<MeetingView> createState() => _MeetingViewState();
}

class _MeetingViewState extends State<MeetingView>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  MeetingSession get s => widget.session;
  late final _title = TextEditingController(text: s.meeting.title);
  late final _person = TextEditingController(text: s.meeting.person);
  late final _email = TextEditingController(text: s.meeting.email);
  late final _context = TextEditingController(text: s.meeting.context);
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  final _transcriptScroll = ScrollController();
  bool _showDetails = true;
  bool _wideHeader = true;

  @override
  void initState() {
    super.initState();
    _showDetails = s.meeting.transcript.isEmpty;
    s.addListener(_sync);
  }

  /// El copiloto puede llenar el correo si lo escucha dictado.
  void _sync() {
    if (_email.text != s.meeting.email) _email.text = s.meeting.email;
    if (_transcriptScroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_transcriptScroll.hasClients) {
          _transcriptScroll.jumpTo(_transcriptScroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    s.removeListener(_sync);
    for (final c in [_title, _person, _email, _context, _note]) {
      c.dispose();
    }
    _noteFocus.dispose();
    _transcriptScroll.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _addNote() {
    s.addNote(_note.text);
    _note.clear();
    _noteFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 820;
          final guide = CopilotPane(session: s, store: widget.store);
          final news = CopilotPane(session: s, store: widget.store, news: true);
          return Column(
            children: [
              _header(context, wide),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    c.maxWidth >= 1000
                        ? ResizableRow(
                            weights: s.settings.columns,
                            onChanged: (w) => s.settings.update(columns: w),
                            children: [
                              Column(
                                children: [
                                  _columnTitle(
                                    context,
                                    Icons.record_voice_over_outlined,
                                    'Transcripción',
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: _transcriptPane(context),
                                  ),
                                  const Divider(height: 1),
                                  Expanded(flex: 2, child: _notesPane(context)),
                                ],
                              ),
                              guide,
                              news,
                            ],
                          )
                        : DefaultTabController(
                            length: 4,
                            child: Column(
                              children: [
                                const TabBar(
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  tabs: [
                                    Tab(text: 'Guía'),
                                    Tab(text: 'Noticias tech'),
                                    Tab(text: 'Transcripción'),
                                    Tab(text: 'Notas'),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    children: [
                                      guide,
                                      news,
                                      _transcriptPane(context),
                                      _notesPane(context),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                    MinutaPane(session: s),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, bool wide) {
    _wideHeader = wide;
    final running = s.transcriber.isRunning;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: running ? cs.error : cs.primary,
                  foregroundColor: running ? cs.onError : cs.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onPressed: s.toggleListening,
                icon: Icon(
                  running ? Icons.stop_circle_outlined : Icons.mic,
                  size: 18,
                ),
                label: Text(running ? 'Detener' : 'Escuchar junta'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: wide ? Alignment.center : Alignment.centerRight,
                  child: _viewSwitch(wide),
                ),
              ),
              IconButton(
                tooltip: _showDetails ? 'Ocultar datos' : 'Datos de la junta',
                onPressed: () => setState(() => _showDetails = !_showDetails),
                icon: Icon(_showDetails ? Icons.expand_less : Icons.edit_note),
              ),
            ],
          ),
          if (running)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.fiber_manual_record, size: 12, color: cs.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Escuchando… avisa a la persona que estás transcribiendo la junta.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (s.transcriber.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                s.transcriber.error!,
                style: TextStyle(color: cs.error),
              ),
            ),
          if (_showDetails) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _field(_title, 'Tema', (v) => s.meeting.title = v, width: 260),
                _field(
                  _person,
                  'Con quién',
                  (v) => s.meeting.person = v,
                  width: 200,
                ),
                _field(
                  _email,
                  'Su correo',
                  (v) => s.meeting.email = v,
                  width: 240,
                  keyboard: TextInputType.emailAddress,
                ),
                _field(
                  _context,
                  'De qué va (ayuda al copiloto)',
                  (v) => s.meeting.context = v,
                  width: 520,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Selector tipo Apple entre la junta en vivo y el resumen.
  Widget _viewSwitch(bool wide) => SegmentedButton<int>(
    showSelectedIcon: false,
    style: SegmentedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    segments: [
      const ButtonSegment(value: 0, label: Text('En vivo')),
      ButtonSegment(
        value: 1,
        label: Text(wide ? 'Resumen y acuerdos' : 'Resumen'),
      ),
    ],
    selected: {_tabs.index},
    onSelectionChanged: (v) => setState(() => _tabs.index = v.first),
  );

  Widget _columnTitle(BuildContext context, IconData icon, String text) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 8),
            Text(text, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      );

  Widget _field(
    TextEditingController c,
    String label,
    void Function(String) set, {
    double width = 220,
    TextInputType? keyboard,
  }) {
    return SizedBox(
      width: _wideHeader ? width : double.infinity,
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) {
          set(v);
          s.changed();
        },
      ),
    );
  }

  Widget _notesPane(BuildContext context) {
    final notes = s.meeting.notes;
    return Column(
      children: [
        Expanded(
          child: notes.isEmpty
              ? const Center(
                  child: Text(
                    'Tus notas aparecen aquí.\nTambién puedes fijar sugerencias del copiloto.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: notes.length,
                  itemBuilder: (c, i) {
                    final n = notes[i];
                    final t = n.date.toLocal();
                    return ListTile(
                      dense: true,
                      leading: Text(
                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      title: SelectableText(n.text),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => s.removeNote(n.id),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _note,
                  focusNode: _noteFocus,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _addNote(),
                  decoration: const InputDecoration(
                    hintText: 'Escribe una nota y Enter…',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addNote,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _transcriptPane(BuildContext context) {
    final text = s.liveTranscript;
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: text.isEmpty
          ? const Center(
              child: Text('La transcripción en vivo aparecerá aquí.'),
            )
          : SingleChildScrollView(
              controller: _transcriptScroll,
              padding: const EdgeInsets.all(16),
              child: SelectableText(text, style: const TextStyle(height: 1.4)),
            ),
    );
  }
}
