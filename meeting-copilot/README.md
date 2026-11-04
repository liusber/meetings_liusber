# Copiloto Juntas

App personal (Flutter) para juntas presenciales: escucha y transcribe en vivo, toma notas
y un copiloto con Gemini te va guiando como un PM de TI (preguntas, objeciones,
qué automatizar y datos o metáforas de TI). Al final genera la minuta y el correo de seguimiento,
que se abre como borrador en Mail.

## Primer uso
1. Saca una API key en https://aistudio.google.com/apikey
2. Abre la app → Ajustes → pega la key, tu nombre y tu rol → Guardar.

## Correr
```bash
flutter run -d macos
```
En el iPhone (conectado por cable, la primera vez): abre `ios/Runner.xcworkspace` en Xcode,
en Runner → Signing & Capabilities elige tu Team (tu Apple ID) y luego:
```bash
flutter run --release
```

## Windows (.exe) a futuro
En una PC con Windows y Flutter: `flutter build windows`. El .exe queda en
`build/windows/x64/runner/Release/`. Se distribuye la carpeta completa.

## Dónde vive cada cosa
- `lib/transcriber.dart`: dictado continuo con el reconocedor del sistema (se reinicia solo).
- `lib/prompts.dart`: lo que se le pide a Gemini; aquí se afina el tono del copiloto.
- `lib/session.dart`: junta abierta, temporizador del copiloto y minuta.
- Las juntas se guardan como JSON en la carpeta de soporte de la app (solo en el equipo).
