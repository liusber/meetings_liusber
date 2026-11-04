import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'gemini.dart';
import 'models.dart';
import 'prompts.dart';
import 'prompts_en.dart';
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
  bool translating = false;
  bool meSpeaking = false;
  int _pending = 0;
  String? translateError;
  bool _disposed = false;

  Timer? _coachTimer;
  Timer? _newsTimer;
  Timer? _saveTimer;
  Timer? _translateTimer;
  int _lastCoachedLength = 0;

  /// Todo lo dictado en esta sesión, sin horas, y hasta dónde ya se tradujo.
  String _raw = '';
  int _translated = 0;
  String _lastHeard = '';

  MeetingSession(this.meeting, this.store, this.settings) {
    transcriber.onFinal = _appendTranscript;
    transcriber.addListener(notifyListeners);
    _lastCoachedLength = meeting.transcript.length;
  }

  GeminiClient get _client => GeminiClient(settings.apiKey, settings.model);

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
    _translateTimer?.cancel();
    _translateTimer = Timer.periodic(const Duration(seconds: 3), (_) => _translate());
    notifyListeners();
  }

  Future<void> stop() async {
    _coachTimer?.cancel();
    _coachTimer = null;
    _translateTimer?.cancel();
    _translateTimer = null;
    await transcriber.stop();
    _translate(flush: true);
    meSpeaking = false;
    WakelockPlus.disable();
    _saveNow();
  }

  void _appendTranscript(String text) {
    final t = DateTime.now();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    meeting.transcript += '${meeting.transcript.isEmpty ? '' : '\n'}[$hh:$mm] $text';
    _raw = _raw.isEmpty ? text : '$_raw $text';
    changed();
  }

  String get _heard => transcriber.partial.isEmpty
      ? _raw
      : _raw.isEmpty
          ? transcriber.partial
          : '$_raw ${transcriber.partial}';

  // ---- Traducción en vivo ----

  /// Traduce lo nuevo que se dijo: cuando la persona hace una pausa, o cada
  /// ~12 palabras dejando las últimas 3, que el dictado todavía corrige.
  Future<void> _translate({bool flush = false}) async {
    final chunk = _takeChunk(flush: flush);
    if (chunk != null) await _emit(chunk, me: meSpeaking);
  }

  /// Botón “Hablo yo”: lo dicho hasta ahora es de quien hablaba antes y lo
  /// que sigue, del otro.
  void toggleMe() {
    final chunk = _takeChunk(flush: true);
    final wasMe = meSpeaking;
    meSpeaking = !meSpeaking;
    notifyListeners();
    if (chunk != null) _emit(chunk, me: wasMe);
  }

  /// Separa el siguiente fragmento por traducir, o null si todavía no toca.
  String? _takeChunk({bool flush = false}) {
    final heard = _heard;
    if (_translated > heard.length) _translated = heard.length;
    // Si el dictado corrigió texto ya traducido, no partas una palabra.
    while (_translated > 0 &&
        _translated < heard.length &&
        heard[_translated - 1].trim().isNotEmpty) {
      _translated++;
    }
    final paused = heard == _lastHeard;
    _lastHeard = heard;
    final tail = heard.substring(_translated);
    final words = RegExp(r'\S+').allMatches(tail).toList();
    if (words.isEmpty) return null;
    var cut = tail.length;
    if (!flush && !(paused && words.length >= 2)) {
      if (words.length < 12) return null;
      cut = words[words.length - 3].start;
      final end = tail.substring(0, cut).lastIndexOf(RegExp(r'[.?!]\s'));
      if (end > 30) cut = end + 1;
    }
    _translated += cut;
    return tail.substring(0, cut).trim();
  }

  /// Agrega el fragmento de una vez (para conservar el orden) y, si es de la
  /// otra persona, le pone la traducción cuando llega.
  Future<void> _emit(String chunk, {required bool me}) async {
    final prompt = translatePrompt(meeting, chunk);
    final t = Translation(en: chunk, speaker: me ? 'yo' : '');
    meeting.translations.add(t);
    changed();
    if (me) return;
    _pending++;
    translating = true;
    notifyListeners();
    try {
      final j = await _client.generateJson(
        system: translateSystem,
        prompt: prompt,
        schema: translateSchema,
        temperature: 0.2,
        thinkingLevel: 'low',
      );
      t.es = '${j['es'] ?? ''}';
      t.marca = j['marca'] == 'ninguna' ? '' : '${j['marca'] ?? ''}';
      translateError = null;
      changed();
      // Si te preguntan o te piden algo, el copiloto responde de inmediato.
      if (t.marca == 'pregunta' || t.marca == 'solicitud') coach();
    } catch (e) {
      translateError = e.toString();
    } finally {
      _pending--;
      translating = _pending > 0;
      if (!_disposed) notifyListeners();
    }
  }

  /// Lo dicho en la junta con [YO] en lo que dijo el usuario.
  String get _labeledTranscript {
    final b = StringBuffer();
    for (final t in meeting.translations) {
      b.writeln(t.isMe ? '[YO] ${t.en}' : t.en);
    }
    final heard = _heard;
    if (_translated < heard.length) {
      final rest = heard.substring(_translated).trim();
      if (rest.isNotEmpty) b.writeln(meSpeaking ? '[YO] $rest' : rest);
    }
    final s = b.toString().trim();
    return s.length > 8000 ? s.substring(s.length - 8000) : s;
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
        system: enCoachSystem(settings.myRole, settings.englishLevel),
        prompt: enCoachPrompt(meeting, _labeledTranscript),
        schema: enCoachSchema,
        // En vivo importa la rapidez: ~5 s en vez de ~10 s.
        thinkingLevel: 'low',
      );
      final tip = EnTip.fromJson(j);
      if (!tip.isEmpty) meeting.enTips.insert(0, tip);
      copilotError = null;
      changed();
    } catch (e) {
      copilotError = e.toString();
    } finally {
      thinking = false;
      notifyListeners();
    }
  }

  /// Noticia real de tecnología (Google Search) para comentar en la junta.
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
      // Sin fuentes de Google no se muestra: evita noticias inventadas.
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
        temperature: 0.4,
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
    _translateTimer?.cancel();
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
