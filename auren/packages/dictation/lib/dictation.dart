import 'package:flutter/services.dart';

/// Dictado continuo con el reconocedor de Apple (Mac y iPhone).
/// El micrófono queda abierto toda la junta; solo se renueva el reconocedor.
class Dictation {
  static const _methods = MethodChannel('copiloto/dictation');
  static const _channel = EventChannel('copiloto/dictation/events');
  static Stream<Map<String, String>>? _events;

  /// Eventos {type: partial | final | error, text}.
  static Stream<Map<String, String>> get events => _events ??= _channel
      .receiveBroadcastStream()
      .map((e) => (e as Map).map((k, v) => MapEntry('$k', '$v')));

  /// Pide permiso de micrófono y de reconocimiento de voz.
  static Future<bool> authorize() async =>
      await _methods.invokeMethod<bool>('authorize') ?? false;

  static Future<void> start(String localeId) =>
      _methods.invokeMethod('start', {'locale': localeId});

  static Future<void> stop() => _methods.invokeMethod('stop');
}
