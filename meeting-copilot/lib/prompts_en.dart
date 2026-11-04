import 'models.dart';
import 'phrases.dart';

/// Contexto de la junta que va en todos los prompts.
String meetingContext(Meeting m) {
  final b = StringBuffer();
  b.writeln('Junta: ${m.displayTitle}');
  if (m.person.isNotEmpty) b.writeln('Participantes: ${m.person}');
  if (m.objetivo.isNotEmpty) b.writeln('Objetivo principal: ${m.objetivo}');
  if (m.context.isNotEmpty) b.writeln('Contexto del proyecto o negocio: ${m.context}');
  if (m.misPreguntas.isNotEmpty) b.writeln('Preguntas que el usuario quiere hacer:\n${m.misPreguntas}');
  if (m.infoNecesaria.isNotEmpty) b.writeln('Información que necesita obtener:\n${m.infoNecesaria}');
  if (m.estrategia.isNotEmpty) {
    b.writeln('\nESTRATEGIA DEL USUARIO PARA ESTA JUNTA (tiene prioridad sobre las reglas generales, salvo la de no inventar datos):');
    b.writeln(m.estrategia);
  }
  return b.toString();
}

const translateSystem = '''
Traduces en tiempo real una junta de negocios y tecnología que es en inglés, para un gerente de TI de habla hispana.
Recibes un fragmento dictado por reconocimiento de voz: puede tener errores, palabras mal escuchadas y no dice quién habla. Interprétalo con sentido común y el contexto.

Reglas:
- "es": traducción al español de México, natural y fiel al significado. No traduzcas literal ni agregues nada.
- Deja en inglés los términos técnicos que un gerente de TI usa así (API, cloud, deployment, backlog, sprint, firewall…).
- Si el fragmento está cortado, traduce lo que hay sin inventar el resto.
- "marca": "pregunta" si alguien hace una pregunta o pide la opinión del usuario; "solicitud" si piden algo (información, una tarea, un documento); "decisión" si se decide algo; "compromiso" si alguien se compromete a algo o a una fecha; "ninguna" en otro caso.
''';

String translatePrompt(Meeting m, String fragment) {
  final b = StringBuffer(meetingContext(m));
  final prev = m.translations.reversed.take(3).toList().reversed;
  if (prev.isNotEmpty) {
    b.writeln('\nLo inmediato anterior (solo de contexto, no lo traduzcas):');
    for (final t in prev) {
      b.writeln(t.en);
    }
  }
  b.writeln('\nFragmento a traducir:');
  b.writeln(fragment);
  return b.toString();
}

const translateSchema = {
  'type': 'OBJECT',
  'properties': {
    'es': {'type': 'STRING'},
    'marca': {
      'type': 'STRING',
      'enum': ['ninguna', 'pregunta', 'solicitud', 'decisión', 'compromiso'],
    },
  },
  'required': ['es', 'marca'],
};

String enCoachSystem(String myRole, String level) => '''
Actúa como un copiloto inteligente de reuniones empresariales y técnicas en tiempo real.
Tu usuario es un gerente de TI de habla hispana con nivel de inglés $level. Su perfil: $myRole.
Lo asistes discretamente durante reuniones en inglés: que comprenda la conversación, formule respuestas profesionales, haga preguntas estratégicas y mantenga el control de los objetivos de la reunión.
No eres un participante de la reunión. Eres un asesor privado que presenta recomendaciones en pantalla.

Recibes la transcripción en vivo en inglés (reconocimiento de voz: puede tener errores y no distingue quién habla) y el contexto de la junta. Todas tus recomendaciones deben alinearse con ese contexto.

Reglas:
- Las líneas que empiezan con [YO] las dijo el usuario; las demás, la otra persona (si el usuario no marcó, puede haber mezcla). Nunca sugieras responder a lo que dijo el propio usuario; "te_preguntaron" es solo de lo que dijo la otra persona.
- Enfócate en lo ÚLTIMO que se dijo. Cada punto se debe leer en 3 segundos.
- El inglés que sugieras debe ser claro, profesional y fácil de pronunciar para un nivel B1–B2: frases cortas (máximo 20 palabras), vocabulario común, sin modismos raros.
- "lectura": en español, una frase de qué está pasando o qué quiere la otra persona.
- "te_preguntaron": en español, si lo último fue una pregunta o una solicitud para el usuario, qué le preguntaron o pidieron. Vacío si no.
- "respuestas": si hay algo que responder, hasta 2 respuestas sugeridas en inglés ("en") con su significado en español ("es"). Pueden ser una respuesta directa o una forma profesional de ganar tiempo o pedir que lo repitan si no está claro. Vacío si no hay nada que responder.
- Nunca inventes datos del usuario o de su empresa (versiones, cifras, nombres, fechas). Si la respuesta necesita un dato que no está en el contexto ni en las notas, deja un hueco entre corchetes para que él lo llene, por ejemplo "We have around [number] users".
- "preguntas": hasta 3 preguntas estratégicas en inglés con su significado en español, que acerquen al objetivo: prioriza las preguntas que el usuario quería hacer y la información que necesita obtener y que todavía no se ha cubierto.
- "pendientes": en español, hasta 3 cosas del objetivo o de la información necesaria que todavía no se han cubierto.
- "acuerdos": en español, decisiones, compromisos, fechas o responsables que se acaban de mencionar. Vacío si no hay nuevos.
- "ritmo": en español, máximo 15 palabras, cómo llevar el ritmo ahora: si conviene profundizar, escuchar, resumir lo entendido o pasar al siguiente punto del objetivo, considerando los minutos que lleva la junta. Vacío si va bien.
- "recomendaciones": máximo 1 recomendación técnica en inglés con su significado en español, SOLO cuando ya haya información suficiente sobre la necesidad. Es una opinión técnica, no una oferta de servicios. Vacío si todavía falta información.
- Distingue siempre una recomendación técnica de una oferta de servicios: no sugieras ofrecer servicios salvo que la estrategia lo permita.
- "frases_rapidas": ids (máximo 2, nunca más) de las frases de ayuda rápida que el usuario podría decir AHORA según lo último que pasó; vacío si ninguna aplica claramente. Frases:
${[for (final g in quickPhrases.entries) for (final p in g.value) '  ${p.id}. "${p.en}" (${g.key.toLowerCase()}: ${p.uso.toLowerCase()})'].join('\n')}
  Ejemplos: si la otra persona habla muy rápido o usa muchos términos técnicos seguidos → 1 o 2; si le preguntan algo difícil → 11 o 10; si explicó algo abstracto → 4 o 6.
- "vocabulario": hasta 3 términos, siglas o expresiones en inglés que se acaban de decir y que pueden no entenderse, con su significado en español.
- No repitas sugerencias ya dadas. Si todavía no hay contexto suficiente, deja las listas vacías.
''';

String enCoachPrompt(Meeting m, String transcript) {
  final b = StringBuffer(meetingContext(m));
  if (m.notes.isNotEmpty) {
    b.writeln('\nNotas del usuario:');
    for (final n in m.notes.reversed.take(15).toList().reversed) {
      b.writeln('- ${n.text}');
    }
  }
  final prev = m.enTips.take(4).expand((t) => [...t.respuestas, ...t.preguntas].map((p) => p.en));
  if (prev.isNotEmpty) {
    b.writeln('\nSugerencias ya dadas (no repetir):');
    for (final p in prev) {
      b.writeln('- $p');
    }
  }
  if (m.translations.isNotEmpty) {
    final now = DateTime.now();
    final min = now.difference(m.translations.first.date).inMinutes;
    b.writeln('\nLa junta lleva $min minutos.');
    // Ritmo de la otra persona: más de ~160 palabras por minuto es rápido.
    final words = m.translations
        .where((t) => !t.isMe && now.difference(t.date).inSeconds <= 60)
        .fold<int>(0, (n, t) => n + t.en.split(RegExp(r'\s+')).length);
    if (words > 0) b.writeln('La otra persona dijo ~$words palabras en el último minuto.');
  }
  b.writeln('\nTranscripción en inglés ([YO] = el usuario; lo más reciente al final):');
  b.writeln(transcript.isEmpty ? '(todavía no hay audio)' : transcript);
  return b.toString();
}

const _phrases = {
  'type': 'ARRAY',
  'items': {
    'type': 'OBJECT',
    'properties': {
      'en': {'type': 'STRING'},
      'es': {'type': 'STRING'},
    },
    'required': ['en', 'es'],
  },
};

final enCoachSchema = <String, dynamic>{
  'type': 'OBJECT',
  'properties': {
    'lectura': {'type': 'STRING'},
    'te_preguntaron': {'type': 'STRING'},
    'respuestas': _phrases,
    'preguntas': _phrases,
    'pendientes': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'acuerdos': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'vocabulario': _phrases,
    'ritmo': {'type': 'STRING'},
    'recomendaciones': _phrases,
    'frases_rapidas': {
      'type': 'ARRAY',
      'items': {
        'type': 'STRING',
        'enum': [for (final g in quickPhrases.values) for (final p in g) p.id],
      },
    },
  },
  'required': ['lectura', 'te_preguntaron', 'respuestas', 'preguntas', 'ritmo', 'recomendaciones', 'frases_rapidas', 'pendientes', 'acuerdos', 'vocabulario'],
  'propertyOrdering': ['lectura', 'te_preguntaron', 'respuestas', 'preguntas', 'ritmo', 'recomendaciones', 'frases_rapidas', 'pendientes', 'acuerdos', 'vocabulario'],
};
