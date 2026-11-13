# Meetings

Apps personales en Flutter (Mac, iPhone, Windows y Android) para juntas presenciales, con Gemini como copiloto.

| Carpeta | App | Para qué |
|---|---|---|
| `copiloto-juntas/` | Auren (antes Copiloto Juntas) | Juntas en español: transcripción, guía de PM de TI, noticias tech, resumen y correo |
| `meeting-copilot/` | Meeting Copilot | Juntas en inglés: traducción en vivo, qué responder y qué preguntar, resumen y correo en inglés |

Cada app pide su propia API key de Gemini en Ajustes (https://aistudio.google.com/apikey); la key se guarda solo en el equipo.

GitHub Actions compila la versión de Windows de las dos apps en cada push a `main` (pestaña Actions → artefactos).

Copiloto Juntas también corre en Android: `flutter build apk --release` dentro de `copiloto-juntas/`. En Android el dictado usa el reconocedor de Google (`speech_to_text`), que la app reinicia en cada pausa.
