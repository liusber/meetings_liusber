/// Frases de ayuda rápida para sostener la conversación en inglés.
class QuickPhrase {
  final String id;
  final String en;
  final String es;
  final String uso;

  const QuickPhrase(this.id, this.en, this.es, this.uso);
}

/// Agrupadas por intención. El id lo usa el copiloto para destacarlas.
const quickPhrases = <String, List<QuickPhrase>>{
  'Aclarar': [
    QuickPhrase('1', 'Could you speak a little more slowly, please?', '¿Podrías hablar un poco más despacio, por favor?',
        'Cuando hablen demasiado rápido'),
    QuickPhrase('2', 'Could you explain that again, please?', '¿Podrías explicarlo otra vez, por favor?',
        'Para pedir una explicación'),
    QuickPhrase('3', 'Let me make sure I understand.', 'Déjame asegurarme de que entiendo.', 'Para confirmar información'),
  ],
  'Preguntar': [
    QuickPhrase('4', 'Can you give me an example?', '¿Me puedes dar un ejemplo?', 'Para pedir ejemplos'),
    QuickPhrase('5', "That's interesting. I have a question about that.", 'Interesante. Tengo una pregunta sobre eso.',
        'Para intervenir en la conversación'),
    QuickPhrase('6', 'How does that work?', '¿Cómo funciona eso?', 'Para profundizar en un tema técnico'),
    QuickPhrase('7', 'What is your main challenge right now?', '¿Cuál es tu principal reto ahora?',
        'Para identificar necesidades'),
  ],
  'Opinar': [
    QuickPhrase('8', 'In my experience, there are different options.', 'En mi experiencia, hay diferentes opciones.',
        'Para compartir tu experiencia'),
    QuickPhrase('9', 'I think we should review that first.', 'Creo que deberíamos revisar eso primero.',
        'Para recomendar una acción'),
  ],
  'Responder': [
    QuickPhrase('10', 'Let me review this and get back to you.', 'Déjame revisarlo y te respondo.',
        'Cuando necesitas investigar algo'),
    QuickPhrase('11', 'Let me think for a second.', 'Déjame pensarlo un segundo.', 'Necesito tiempo'),
  ],
};

final quickPhraseById = {
  for (final g in quickPhrases.values)
    for (final p in g) p.id: p,
};

/// Conector, significado y ejemplo.
typedef Connector = ({String en, String es, String ejemplo});

const connectors = <String, List<Connector>>{
  'Para organizar tus ideas': [
    (en: 'First', es: 'Primero', ejemplo: 'First, I have a question.'),
    (en: 'Then', es: 'Después / Entonces', ejemplo: 'Then, we can review the API.'),
    (en: 'After that', es: 'Después de eso', ejemplo: 'After that, we can test it.'),
    (en: 'Finally', es: 'Finalmente', ejemplo: 'Finally, we can make a decision.'),
    (en: 'Also', es: 'También', ejemplo: 'Also, we need to check the server.'),
  ],
  'Para explicar razones': [
    (en: 'Because', es: 'Porque', ejemplo: 'Because we need more information.'),
    (en: 'So', es: 'Así que / Entonces', ejemplo: 'So, we need another option.'),
    (en: "That's why", es: 'Por eso', ejemplo: "That's why I recommend this."),
    (en: 'For example', es: 'Por ejemplo', ejemplo: 'For example, we could use an API.'),
    (en: 'In other words', es: 'En otras palabras', ejemplo: 'In other words, we need more time.'),
  ],
  'Para comparar y dar opiniones': [
    (en: 'But', es: 'Pero', ejemplo: 'But we have another option.'),
    (en: 'However', es: 'Sin embargo', ejemplo: 'However, it could be expensive.'),
    (en: 'On the other hand', es: 'Por otro lado', ejemplo: 'On the other hand, a VPS could work.'),
    (en: 'In my opinion', es: 'En mi opinión', ejemplo: 'In my opinion, we should test it first.'),
    (en: 'I think', es: 'Creo que', ejemplo: 'I think this is a good approach.'),
  ],
  'Para confirmar y continuar la conversación': [
    (en: 'Actually', es: 'En realidad', ejemplo: 'Actually, I have another idea.'),
    (en: 'By the way', es: 'Por cierto', ejemplo: 'By the way, where is your app hosted?'),
    (en: 'Regarding', es: 'Respecto a', ejemplo: 'Regarding the API, I have a question.'),
    (en: 'Based on that', es: 'Con base en eso', ejemplo: 'Based on that, we can decide.'),
    (en: 'In that case', es: 'En ese caso', ejemplo: 'In that case, we could use Linux.'),
  ],
};

/// Ejemplo de cómo encadenar ideas con conectores.
const connectorsExample = (
  sin: 'We need to understand your architecture. We can recommend a developer. We can review the costs.',
  con: [
    "First, I'd like to understand your architecture.",
    'Then, we can identify the right developer.',
    'After that, we can review the costs.',
    'Finally, we can decide on the next steps.',
  ],
);
