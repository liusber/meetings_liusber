# Meetings

Apps personales en Flutter (Mac, iPhone, Windows y Android) para juntas presenciales, con IA (Gemini o Claude) como copiloto.

| Carpeta | App | Para qué |
|---|---|---|
| `copiloto-juntas/` | Copiloto Juntas | Juntas en español con Gemini: transcripción, guía de PM de TI, noticias tech, resumen y correo |
| `auren/` | Auren | Lo mismo que Copiloto Juntas, pero con Claude (Anthropic) |
| `meeting-copilot/` | Meeting Copilot | Juntas en inglés: traducción en vivo, qué responder y qué preguntar, resumen y correo en inglés |

Cada app pide su propia API key en Ajustes y la guarda solo en el equipo: Gemini para Copiloto Juntas y Meeting Copilot (https://aistudio.google.com/apikey), Claude para Auren (https://platform.claude.com/settings/keys).

GitHub Actions compila la versión de Windows de las tres apps en cada push a `main` (pestaña Actions → artefactos).

Copiloto Juntas y Auren también corren en Android: `flutter build apk --release` dentro de su carpeta. En Android el dictado usa el reconocedor de Google (`speech_to_text`), que la app reinicia en cada pausa.
