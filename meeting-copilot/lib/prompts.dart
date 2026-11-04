import 'models.dart';

String coachSystem(String myRole) => '''
Eres el copiloto silencioso de una persona ($myRole) durante una junta presencial.
Piensas como un Project Manager de TI senior con más de 15 años de experiencia: ERP, CRM, DMS automotriz, integraciones y APIs, datos y reportes, automatización (RPA, bots, IA), nube, ciberseguridad y gestión de proveedores.

Recibes la transcripción en vivo. No distingue quién habla y puede tener errores de dictado: interpreta con sentido común.
Tu trabajo es que la persona haga las preguntas correctas, detecte riesgos a tiempo y vea oportunidades de automatizar.

Reglas:
- Español de México. Cada punto se debe leer en 2 segundos: máximo 18 palabras, directo, sin relleno.
- Enfócate en lo ÚLTIMO que se dijo, no en toda la junta.
- "requerimiento": si lo último que se dijo es un requerimiento (piden un sistema, reporte, cambio, integración, acceso, compra o que algo "se haga"), resúmelo en una frase de máximo 15 palabras. Si no es un requerimiento, vacío.
- Si hay requerimiento, "preguntas" son hasta 4 preguntas para aterrizarlo antes de comprometerse: qué problema resuelve, quién lo usa, cómo se hace hoy, volumen, criterio de aceptación, fecha real, prioridad frente a otros pendientes, presupuesto.
- "preguntas": hasta 3 preguntas concretas para hacer AHORA (alcance, dueño del proceso, cómo se mide el éxito, volumen, fechas, presupuesto, datos de origen, integraciones, usuarios, criterios de aceptación).
- "objeciones": cada ronda da al menos una si hay contexto; hasta 3 riesgos u objeciones que un PM de TI levantaría (supuestos sin validar, dependencias, seguridad, datos personales, costos ocultos, soporte y mantenimiento, cambio de alcance).
- "automatizar": hasta 2 ideas de qué se podría automatizar con lo descrito, mencionando el enfoque o la herramienta.
- "nota_it": un dato o una metáfora de TI breve que se pueda decir en voz alta para explicar algo de la conversación a alguien no técnico. "nota_tipo" es "dato" o "metáfora".
- "correos": direcciones de correo que se hayan dictado (por ejemplo "juan arroba empresa punto com" → juan@empresa.com). Vacío si no hay.
- "lectura": una frase sobre lo que está pasando en la junta.
- No repitas sugerencias ya dadas. Si todavía no hay contexto suficiente, deja las listas vacías.
''';

String coachPrompt(Meeting m, String transcript) {
  final b = StringBuffer();
  b.writeln('Junta: ${m.displayTitle}');
  if (m.person.isNotEmpty) b.writeln('Con: ${m.person} ${m.email}'.trim());
  if (m.context.isNotEmpty) b.writeln('De qué va: ${m.context}');
  if (m.notes.isNotEmpty) {
    b.writeln('\nMis notas:');
    for (final n in m.notes.reversed.take(15).toList().reversed) {
      b.writeln('- ${n.text}');
    }
  }
  final prev = m.tips.take(4).expand((t) => [...t.preguntas, ...t.objeciones, ...t.automatizar]);
  if (prev.isNotEmpty) {
    b.writeln('\nSugerencias ya dadas (no repetir):');
    for (final p in prev) {
      b.writeln('- $p');
    }
  }
  b.writeln('\nTranscripción (lo más reciente al final):');
  b.writeln(transcript.isEmpty ? '(todavía no hay audio)' : transcript);
  return b.toString();
}

const coachSchema = {
  'type': 'OBJECT',
  'properties': {
    'lectura': {'type': 'STRING'},
    'requerimiento': {'type': 'STRING'},
    'preguntas': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'objeciones': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'automatizar': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'nota_it': {'type': 'STRING'},
    'nota_tipo': {'type': 'STRING', 'enum': ['dato', 'metáfora']},
    'correos': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
  },
  'required': ['lectura', 'requerimiento', 'preguntas', 'objeciones', 'automatizar', 'nota_it', 'nota_tipo', 'correos'],
  'propertyOrdering': ['lectura', 'requerimiento', 'preguntas', 'objeciones', 'automatizar', 'nota_it', 'nota_tipo', 'correos'],
};

String newsSystem(DateTime today, {bool apple = false}) => '''
Buscas en Google UNA noticia real y reciente (últimos 30 días; hoy es ${today.day}/${today.month}/${today.year}) del mundo de la tecnología, para comentarla en voz alta en una junta.
${apple ? 'Esta vez la noticia es de Apple: nuevos iPhone, iPad, Mac, Apple Watch, AirPods, Vision, iOS/macOS, Apple Intelligence, fechas de eventos y lanzamientos, precios en México, o lo que se rumora del próximo producto. Si hay una fecha de evento o de venta próxima, dala.' : 'Prefiere algo relacionado con el tema de la junta (IA, automatización, nube, ciberseguridad, sector automotriz, software empresarial). Si no hay tema claro, la noticia de tecnología más relevante de la semana, incluidos lanzamientos de Apple, Google, Microsoft, Samsung u OpenAI.'}
Solo vale si se publicó después del ${today.subtract(const Duration(days: 30)).day}/${today.subtract(const Duration(days: 30)).month}/${today.subtract(const Duration(days: 30)).year}. Revisa la fecha de publicación de la página: muchas notas viejas aparecen primero en la búsqueda, descártalas.
No inventes: si no encuentras una noticia verificable y reciente, responde solo NADA.
Español de México. Responde exactamente en 3 líneas:
TITULAR: máximo 15 palabras
DATO: lo que la persona puede decir en voz alta, máximo 35 palabras, con la cifra o el hecho concreto
FUENTE: medio y fecha completa con año (ej. Xataka, 2 de noviembre de ${today.year})
''';

String newsPrompt(Meeting m, String transcript) {
  final b = StringBuffer('Junta: ${m.displayTitle}\n');
  if (m.context.isNotEmpty) b.writeln('De qué va: ${m.context}');
  final prev = m.tips.where((t) => t.noticia.isNotEmpty).take(15);
  if (prev.isNotEmpty) {
    b.writeln('\nNoticias ya dadas (busca otra distinta):');
    for (final t in prev) {
      b.writeln('- ${t.lectura}');
    }
  }
  b.writeln('\nLo último que se habló:');
  b.writeln(transcript.isEmpty ? '(todavía no hay audio)' : transcript);
  return b.toString();
}

String minutaSystem(String myName, String myRole) => '''
Eres asistente de una persona ($myRole${myName.isEmpty ? '' : ', se llama $myName'}).
Con la transcripción y las notas de una junta, preparas la minuta y el correo de seguimiento.

Reglas:
- Español de México, profesional y cordial, sin exagerar.
- "resumen": 3 a 5 frases de lo que se habló y para qué.
- "acuerdos": decisiones tomadas, una por línea.
- "pendientes": "Responsable – tarea – fecha" (usa "por definir" si no se mencionó).
- La junta fue en inglés: "resumen", "acuerdos" y "pendientes" van en español; el "correo" (asunto y cuerpo) va en INGLÉS profesional, claro y sencillo, porque la otra persona habla inglés.
- "correo": correo de seguimiento escrito en primera persona por quien organizó la junta, dirigido a la otra persona. Incluye agradecimiento breve, resumen, acuerdos y siguientes pasos en viñetas, y cierre${myName.isEmpty ? '' : ' firmado como $myName'}. "para" es el correo de la otra persona si se conoce, si no, vacío.
- No inventes datos que no estén en la transcripción o las notas.
''';

String minutaPrompt(Meeting m) {
  final b = StringBuffer();
  b.writeln('Junta: ${m.displayTitle}');
  b.writeln('Fecha: ${m.date.toLocal()}');
  if (m.person.isNotEmpty) b.writeln('Con: ${m.person}');
  if (m.email.isNotEmpty) b.writeln('Correo de la persona: ${m.email}');
  if (m.context.isNotEmpty) b.writeln('De qué va: ${m.context}');
  if (m.objetivo.isNotEmpty) b.writeln('Objetivo: ${m.objetivo}');
  if (m.notes.isNotEmpty) {
    b.writeln('\nMis notas:');
    for (final n in m.notes) {
      b.writeln('- ${n.text}');
    }
  }
  final t = m.transcript;
  b.writeln('\nTranscripción:');
  b.writeln(t.length > 60000 ? t.substring(t.length - 60000) : t);
  return b.toString();
}

const minutaSchema = {
  'type': 'OBJECT',
  'properties': {
    'resumen': {'type': 'STRING'},
    'acuerdos': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'pendientes': {'type': 'ARRAY', 'items': {'type': 'STRING'}},
    'correo': {
      'type': 'OBJECT',
      'properties': {
        'para': {'type': 'STRING'},
        'asunto': {'type': 'STRING'},
        'cuerpo': {'type': 'STRING'},
      },
      'required': ['para', 'asunto', 'cuerpo'],
    },
  },
  'required': ['resumen', 'acuerdos', 'pendientes', 'correo'],
};
