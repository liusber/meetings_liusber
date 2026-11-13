import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'claude.dart';
import 'models.dart';
import 'prompts.dart';
import 'settings.dart';
import 'store.dart';
import 'transcriber.dart';

/// Estado de la junta abierta: escucha, notas, copiloto y minuta.
class MeetingSession extends ChangeNotifier {
  final Meeting meeting;
  final MeetingStore store;
  final AppSettings settings;
  final transcriber = Transcriber();

  bool thinking = false;
  bool makingMinuta = false;
  bool fetchingNews = false;
  String? copilotError;
  String? newsError;
  int _newsRound = 0;
  bool _disposed = false;

  Timer? _coachTimer;
  Timer? _newsTimer;
  Timer? _saveTimer;
  int _lastCoachedLength = 0;

  MeetingSession(this.meeting, this.store, this.settings) {
    transcriber.onFinal = _appendTranscript;
    transcriber.addListener(notifyListeners);
    _lastCoachedLength = meeting.transcript.length;
    _startNews();
  }

  /// Las noticias llegan solas desde que abres la junta (una tech y una de
  /// Apple) y se renuevan cada [AppSettings.newsMin] minutos, escuches o no.
  /// Las juntas viejas no buscan noticias.
  Future<void> _startNews() async {
    if (settings.newsMin <= 0 || settings.activeKey.isEmpty) return;
    if (DateTime.now().difference(meeting.date) > const Duration(hours: 12)) return;
    _newsTimer = Timer.periodic(
        Duration(minutes: settings.newsMin), (_) => news(apple: (_newsRound++).isOdd));
    final last = meeting.tips.where((t) => t.noticia.isNotEmpty).firstOrNull;
    if (last != null &&
        DateTime.now().difference(last.date) < Duration(minutes: settings.newsMin)) {
      return;
    }
    await news();
    if (!_disposed) await news(apple: true);
  }

  ClaudeClient get _client => ClaudeClient(settings.activeKey, settings.model);

  String get liveTranscript => transcriber.partial.isEmpty
      ? meeting.transcript
      : '${meeting.transcript}${meeting.transcript.isEmpty ? '' : '\n'}… ${transcriber.partial}';

  // ---- Escuchar ----

  Future<void> toggleListening() async {
    if (transcriber.isRunning) {
      await stop();
      return;
    }
    final ok = await transcriber.start(settings.localeId);
    if (!ok) return;
    WakelockPlus.enable();
    _coachTimer?.cancel();
    _coachTimer = Timer.periodic(Duration(seconds: settings.intervalSec), (_) {
      // Solo pide sugerencias si hubo conversación nueva suficiente.
      if (liveTranscript.length - _lastCoachedLength >= 150) coach();
    });
    notifyListeners();
  }

  Future<void> stop() async {
    _coachTimer?.cancel();
    _coachTimer = null;
    await transcriber.stop();
    WakelockPlus.disable();
    _saveNow();
  }

  void _appendTranscript(String text) {
    final t = DateTime.now();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    meeting.transcript += '${meeting.transcript.isEmpty ? '' : '\n'}[$hh:$mm] $text';
    changed();
  }

  // ---- Notas ----

  void addNote(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    meeting.notes.add(Note(text: t));
    changed();
  }

  void removeNote(String id) {
    meeting.notes.removeWhere((n) => n.id == id);
    changed();
  }

  // ---- Copiloto ----

  Future<void> coach() async {
    if (thinking) return;
    thinking = true;
    notifyListeners();
    final text = liveTranscript;
    _lastCoachedLength = text.length;
    try {
      final j = await _client.generateJson(
        system: coachSystem(settings.myRole),
        prompt: coachPrompt(meeting,
            text.length > 8000 ? text.substring(text.length - 8000) : text),
        schema: coachSchema,
        // En vivo importa la rapidez.
        effort: 'low',
      );
      final tip = CoachTip.fromJson(j);
      if (!tip.isEmpty) meeting.tips.insert(0, tip);
      if (meeting.email.isEmpty && tip.correos.isNotEmpty) {
        meeting.email = tip.correos.first;
      }
      copilotError = null;
      changed();
    } catch (e) {
      copilotError = e.toString();
    } finally {
      thinking = false;
      notifyListeners();
    }
  }

  /// Noticia real de tecnología (búsqueda web) para comentar en la junta.
  Future<void> news({bool apple = false}) async {
    if (fetchingNews) return;
    fetchingNews = true;
    notifyListeners();
    final text = liveTranscript;
    try {
      final r = await _client.searchText(
        system: newsSystem(DateTime.now(), apple: apple),
        prompt: newsPrompt(meeting, text.length > 3000 ? text.substring(text.length - 3000) : text),
      );
      String field(String name) {
        final m = RegExp('^\\**$name\\**:\\s*(.+)\$', multiLine: true, caseSensitive: false)
            .firstMatch(r.text);
        return m?.group(1)?.replaceAll('*', '').trim() ?? '';
      }

      final titular = field('TITULAR');
      final dato = field('DATO');
      final fuente = field('FUENTE');
      // La fecha debe traer año y ser de este año (o del anterior en enero).
      final now = DateTime.now();
      final years = RegExp(r'\b20\d\d\b').allMatches(fuente).map((m) => int.parse(m[0]!));
      final recent = years.isNotEmpty &&
          years.every((y) => y == now.year || (now.month == 1 && y == now.year - 1));
      // Sin fuentes web no se muestra: evita noticias inventadas.
      if (titular.isEmpty || dato.isEmpty || r.sources.isEmpty || !recent) {
        newsError = 'No encontré una noticia reciente con fuente verificable; intenta de nuevo.';
      } else {
        meeting.tips.insert(
          0,
          CoachTip(
            lectura: titular,
            noticia: dato,
            noticiaFuente: fuente.isNotEmpty ? fuente : r.sources.first.title,
            noticiaUrl: r.sources.first.url,
          ),
        );
        newsError = null;
        changed();
      }
    } catch (e) {
      newsError = e.toString();
    } finally {
      fetchingNews = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ---- Minuta y correo ----

  Future<void> makeMinuta() async {
    if (makingMinuta) return;
    makingMinuta = true;
    copilotError = null;
    notifyListeners();
    try {
      final j = await _client.generateJson(
        system: minutaSystem(settings.myName, settings.myRole),
        prompt: minutaPrompt(meeting),
        schema: minutaSchema,
      );
      final m = Minuta.fromJson(j);
      if (m.correo.para.isEmpty) m.correo.para = meeting.email;
      meeting.minuta = m;
      changed();
    } catch (e) {
      copilotError = e.toString();
    } finally {
      makingMinuta = false;
      notifyListeners();
    }
  }

  // ---- Guardado ----

  /// Llamar tras cualquier cambio en [meeting]; guarda con un pequeño retraso.
  void changed() {
    if (_disposed) {
      store.save(meeting);
      return;
    }
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _saveNow);
  }

  void _saveNow() {
    _saveTimer?.cancel();
    store.save(meeting);
  }

  @override
  void dispose() {
    _disposed = true;
    _coachTimer?.cancel();
    _newsTimer?.cancel();
    if (transcriber.isRunning) {
      transcriber.stop();
      WakelockPlus.disable();
    }
    _saveNow();
    transcriber.removeListener(notifyListeners);
    transcriber.dispose();
    super.dispose();
  }
}
