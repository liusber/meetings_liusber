import 'dart:async';
import 'dart:io';

import 'package:dictation/dictation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Dictado continuo durante la junta.
///
/// En Mac y iPhone usa el paquete local `dictation`, que deja el micrófono
/// abierto y solo renueva el reconocedor. En Windows usa speech_to_text, que
/// se corta tras silencios y hay que volver a arrancar.
class Transcriber extends ChangeNotifier {
  static final _native = Platform.isMacOS || Platform.isIOS;
  StreamSubscription<Map<String, String>>? _events;

  final _stt = SpeechToText();
  bool _ready = false;
  bool _want = false;
  String _localeId = 'es_MX';
  String _lastCommitted = '';
  // Un solo arranque a la vez: dos listen() simultáneos tumban el audio de macOS.
  bool _starting = false;
  Timer? _restart;

  String partial = '';
  String? error;
  void Function(String text)? onFinal;

  bool get isRunning => _want;

  bool _onDevice = false;

  /// [onDevice]: transcripción privada (el audio no sale del equipo).
  /// [vocabulary]: palabras esperadas en la junta, para reconocerlas mejor.
  Future<bool> start(String localeId,
      {bool onDevice = false, List<String> vocabulary = const []}) async {
    error = null;
    _onDevice = onDevice;
    if (_native) return _startNative(localeId, onDevice, vocabulary);
    if (!_ready) {
      try {
        _ready = await _stt.initialize(onStatus: _onStatus, onError: _onError);
      } catch (e) {
        _ready = false;
      }
      if (!_ready) {
        error = 'Sin permiso de micrófono o reconocimiento de voz. '
            'Actívalos en Ajustes del sistema → Privacidad.';
        notifyListeners();
        return false;
      }
    }
    _localeId = localeId;
    _want = true;
    notifyListeners();
    await _listen();
    return true;
  }

  Future<void> stop() async {
    _want = false;
    _restart?.cancel();
    if (_native) {
      // El último "final" llega por el stream antes de soltar la suscripción.
      await Dictation.stop();
      await _events?.cancel();
      _events = null;
    } else if (_stt.isListening) {
      await _stt.stop();
    }
    _commit();
    notifyListeners();
  }

  Future<bool> _startNative(String localeId, bool onDevice, List<String> vocabulary) async {
    if (!_ready) {
      _ready = await Dictation.authorize();
      if (!_ready) {
        error = 'Sin permiso de micrófono o reconocimiento de voz. '
            'Actívalos en Ajustes del sistema → Privacidad y seguridad.';
        notifyListeners();
        return false;
      }
    }
    _events ??= Dictation.events.listen((e) {
      final text = e['text'] ?? '';
      switch (e['type']) {
        case 'partial':
          partial = text;
        case 'final':
          partial = text;
          _commit();
        case 'error':
          error = text;
      }
      notifyListeners();
    });
    try {
      await Dictation.start(localeId, onDevice: onDevice, vocabulary: vocabulary);
    } catch (e) {
      error = 'El micrófono falló: ${e is PlatformException ? e.message : e}';
      await _events?.cancel();
      _events = null;
      notifyListeners();
      return false;
    }
    _want = true;
    notifyListeners();
    return true;
  }

  Future<void> _listen() async {
    if (!_want || _starting || _stt.isListening) return;
    _starting = true;
    try {
      await _stt.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenFor: const Duration(minutes: 10),
          pauseFor: const Duration(seconds: 45),
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          autoPunctuation: true,
          // Transcripción privada en Android: el reconocedor del teléfono cuando
          // lo tiene; si no, el sistema prefiere sin conexión.
          onDevice: Platform.isAndroid && _onDevice,
        ),
      );
    } catch (e) {
      error = 'El micrófono falló: $e';
      notifyListeners();
      _restartSoon(const Duration(seconds: 3));
    } finally {
      _starting = false;
    }
  }

  void _onResult(SpeechRecognitionResult r) {
    partial = r.recognizedWords;
    if (r.finalResult) _commit();
    notifyListeners();
  }

  void _commit() {
    final t = partial.trim();
    partial = '';
    if (t.isEmpty || t == _lastCommitted) return;
    _lastCommitted = t;
    onFinal?.call(t);
  }

  /// "done" y un error suelen llegar juntos: solo vale el último aviso.
  void _restartSoon(Duration d) {
    _restart?.cancel();
    if (_want) _restart = Timer(d, _listen);
  }

  void _onStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      _commit();
      notifyListeners();
      _restartSoon(const Duration(milliseconds: 800));
    }
  }

  void _onError(SpeechRecognitionError e) {
    // "no_match" y "speech_timeout" son normales cuando hay silencio.
    if (e.errorMsg.contains('permission')) {
      _want = false;
      error = 'Sin permiso de micrófono o reconocimiento de voz.';
      notifyListeners();
      return;
    }
    if (e.errorMsg.contains('language')) {
      _want = false;
      error = 'Falta el idioma para transcribir sin internet. En el teléfono: Ajustes → '
          'Sistema → Idiomas → Reconocimiento de voz sin conexión, y descarga el idioma de la junta.';
      notifyListeners();
      return;
    }
    _restartSoon(const Duration(seconds: 1));
  }

  @override
  void dispose() {
    if (_want && _native) Dictation.stop();
    _events?.cancel();
    _want = false;
    _restart?.cancel();
    super.dispose();
  }
}
