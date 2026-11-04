# Meetings

Apps personales en Flutter (Mac, iPhone y Windows) para juntas presenciales, con Gemini como copiloto.

| Carpeta | App | Para qué |
|---|---|---|
| `copiloto-juntas/` | Copiloto Juntas | Juntas en español: transcripción, guía de PM de TI, noticias tech, resumen y correo |
| `meeting-copilot/` | Meeting Copilot | Juntas en inglés: traducción en vivo, qué responder y qué preguntar, resumen y correo en inglés |

Cada app pide su propia API key de Gemini en Ajustes (https://aistudio.google.com/apikey); la key se guarda solo en el equipo.

GitHub Actions compila la versión de Windows de las dos apps en cada push a `main` (pestaña Actions → artefactos).
