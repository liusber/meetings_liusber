import 'dart:math';

String newId() {
  final r = Random();
  return DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      r.nextInt(1 << 30).toRadixString(36);
}

List<String> _strings(dynamic v) =>
    (v as List? ?? const []).map((e) => e.toString()).toList();

class Note {
  final String id;
  final DateTime date;
  String text;

  Note({required this.text, String? id, DateTime? date})
      : id = id ?? newId(),
        date = date ?? DateTime.now();

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': date.toIso8601String(), 'text': text};

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'],
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        text: j['text'] ?? '',
      );
}

/// Una ronda de sugerencias del copiloto.
class CoachTip {
  final String id;
  final DateTime date;
  final String lectura;
  final List<String> preguntas;
  final List<String> objeciones;
  final List<String> automatizar;
  final String notaIT;
  final String notaTipo;
  final List<String> correos;
  final String requerimiento;
  final String noticia;
  final String noticiaFuente;
  final String noticiaUrl;

  CoachTip({
    String? id,
    DateTime? date,
    this.lectura = '',
    this.preguntas = const [],
    this.objeciones = const [],
    this.automatizar = const [],
    this.notaIT = '',
    this.notaTipo = 'dato',
    this.correos = const [],
    this.requerimiento = '',
    this.noticia = '',
    this.noticiaFuente = '',
    this.noticiaUrl = '',
  })  : id = id ?? newId(),
        date = date ?? DateTime.now();

  bool get isEmpty =>
      preguntas.isEmpty &&
      objeciones.isEmpty &&
      automatizar.isEmpty &&
      notaIT.trim().isEmpty &&
      requerimiento.trim().isEmpty &&
      noticia.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'lectura': lectura,
        'preguntas': preguntas,
        'objeciones': objeciones,
        'automatizar': automatizar,
        'nota_it': notaIT,
        'nota_tipo': notaTipo,
        'correos': correos,
        'requerimiento': requerimiento,
        'noticia': noticia,
        'noticia_fuente': noticiaFuente,
        'noticia_url': noticiaUrl,
      };

  factory CoachTip.fromJson(Map<String, dynamic> j) => CoachTip(
        id: j['id'],
        date: DateTime.tryParse(j['date'] ?? ''),
        lectura: j['lectura'] ?? '',
        preguntas: _strings(j['preguntas']),
        objeciones: _strings(j['objeciones']),
        automatizar: _strings(j['automatizar']),
        notaIT: j['nota_it'] ?? '',
        notaTipo: j['nota_tipo'] ?? 'dato',
        correos: _strings(j['correos']),
        requerimiento: j['requerimiento'] ?? '',
        noticia: j['noticia'] ?? '',
        noticiaFuente: j['noticia_fuente'] ?? '',
        noticiaUrl: j['noticia_url'] ?? '',
      );
}

class EmailDraft {
  String para;
  String asunto;
  String cuerpo;

  EmailDraft({this.para = '', this.asunto = '', this.cuerpo = ''});

  Map<String, dynamic> toJson() =>
      {'para': para, 'asunto': asunto, 'cuerpo': cuerpo};

  factory EmailDraft.fromJson(Map<String, dynamic> j) => EmailDraft(
        para: j['para'] ?? '',
        asunto: j['asunto'] ?? '',
        cuerpo: j['cuerpo'] ?? '',
      );
}

class Minuta {
  String resumen;
  List<String> acuerdos;
  List<String> pendientes;
  EmailDraft correo;

  Minuta({
    this.resumen = '',
    this.acuerdos = const [],
    this.pendientes = const [],
    EmailDraft? correo,
  }) : correo = correo ?? EmailDraft();

  Map<String, dynamic> toJson() => {
        'resumen': resumen,
        'acuerdos': acuerdos,
        'pendientes': pendientes,
        'correo': correo.toJson(),
      };

  factory Minuta.fromJson(Map<String, dynamic> j) => Minuta(
        resumen: j['resumen'] ?? '',
        acuerdos: _strings(j['acuerdos']),
        pendientes: _strings(j['pendientes']),
        correo: EmailDraft.fromJson(
            (j['correo'] as Map?)?.cast<String, dynamic>() ?? {}),
      );

  String asText(String titulo) {
    final b = StringBuffer('Minuta: $titulo\n\n$resumen\n');
    if (acuerdos.isNotEmpty) {
      b.writeln('\nAcuerdos:');
      for (final a in acuerdos) {
        b.writeln('• $a');
      }
    }
    if (pendientes.isNotEmpty) {
      b.writeln('\nPendientes:');
      for (final p in pendientes) {
        b.writeln('• $p');
      }
    }
    return b.toString();
  }
}

class Meeting {
  final String id;
  final DateTime date;
  String title;
  String person;
  String email;
  String context;
  String transcript;
  List<Note> notes;
  List<CoachTip> tips;
  Minuta? minuta;

  Meeting({
    String? id,
    DateTime? date,
    this.title = '',
    this.person = '',
    this.email = '',
    this.context = '',
    this.transcript = '',
    List<Note>? notes,
    List<CoachTip>? tips,
    this.minuta,
  })  : id = id ?? newId(),
        date = date ?? DateTime.now(),
        notes = notes ?? [],
        tips = tips ?? [];

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (person.trim().isNotEmpty) return 'Junta con ${person.trim()}';
    return 'Junta sin título';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'person': person,
        'email': email,
        'context': context,
        'transcript': transcript,
        'notes': notes.map((n) => n.toJson()).toList(),
        'tips': tips.map((t) => t.toJson()).toList(),
        'minuta': minuta?.toJson(),
      };

  factory Meeting.fromJson(Map<String, dynamic> j) => Meeting(
        id: j['id'],
        date: DateTime.tryParse(j['date'] ?? ''),
        title: j['title'] ?? '',
        person: j['person'] ?? '',
        email: j['email'] ?? '',
        context: j['context'] ?? '',
        transcript: j['transcript'] ?? '',
        notes: (j['notes'] as List? ?? [])
            .map((e) => Note.fromJson((e as Map).cast()))
            .toList(),
        tips: (j['tips'] as List? ?? [])
            .map((e) => CoachTip.fromJson((e as Map).cast()))
            .toList(),
        minuta: j['minuta'] == null
            ? null
            : Minuta.fromJson((j['minuta'] as Map).cast()),
      );
}
