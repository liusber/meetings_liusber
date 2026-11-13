import 'dart:convert';

import 'package:http/http.dart' as http;

class ClaudeException implements Exception {
  final String message;
  ClaudeException(this.message);
  @override
  String toString() => message;
}

/// Cliente mínimo de la API de Claude (Anthropic) por HTTP: Dart no tiene
/// SDK oficial. Pide JSON con esquema (structured outputs) o texto con
/// búsqueda web.
class ClaudeClient {
  final String apiKey;
  final String model;

  ClaudeClient(this.apiKey, this.model);

  /// Respuesta en texto apoyada en búsqueda web. Devuelve el texto y las
  /// fuentes que usó; sin fuentes la respuesta no está verificada.
  Future<({String text, List<({String title, String url})> sources})> searchText({
    required String system,
    required String prompt,
  }) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'user', 'content': prompt},
    ];
    Map<String, dynamic> data;
    // La búsqueda puede pausar el turno (pause_turn): se reenvía para que siga.
    var rounds = 0;
    while (true) {
      data = await _post({
        'system': system,
        'messages': messages,
        'tools': [
          {'type': 'web_search_20260209', 'name': 'web_search', 'max_uses': 5},
        ],
        // Revisar fechas de varias páginas pide algo más de esfuerzo.
        'output_config': {'effort': 'medium'},
      });
      if (data['stop_reason'] != 'pause_turn' || ++rounds >= 3) break;
      messages.add({'role': 'assistant', 'content': data['content']});
    }
    final content = data['content'] as List? ?? const [];
    final sources = <({String title, String url})>[];
    final seen = <String>{};
    void add(Map m) {
      final url = '${m['url'] ?? ''}';
      if (url.isNotEmpty && seen.add(url)) sources.add((title: '${m['title'] ?? ''}', url: url));
    }

    // Primero lo que el texto cita; después el resto de resultados.
    for (final b in content) {
      if (b is Map && b['type'] == 'text') {
        for (final c in b['citations'] as List? ?? const []) {
          if (c is Map) add(c);
        }
      }
    }
    for (final b in content) {
      if (b is Map && b['type'] == 'web_search_tool_result' && b['content'] is List) {
        for (final r in b['content'] as List) {
          if (r is Map) add(r);
        }
      }
    }
    return (text: _text(data), sources: sources);
  }

  /// [schema] usa el formato de los prompts (tipos en mayúsculas); se
  /// convierte a JSON Schema estricto.
  Future<Map<String, dynamic>> generateJson({
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    String effort = 'medium',
  }) async {
    final data = await _post({
      'system': system,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'output_config': {
        'effort': effort,
        'format': {'type': 'json_schema', 'schema': jsonSchema(schema)},
      },
    });
    if (data['stop_reason'] == 'max_tokens') {
      throw ClaudeException('Claude se quedó sin espacio para responder; intenta de nuevo.');
    }
    final text = _text(data);
    if (text.isEmpty) throw ClaudeException('Claude no devolvió texto.');
    try {
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    } catch (_) {
      throw ClaudeException('Claude devolvió algo que no es JSON.');
    }
  }

  /// Convierte el esquema de los prompts (OBJECT, STRING…) a JSON Schema:
  /// tipos en minúsculas, todos los campos requeridos y sin campos extra.
  static Map<String, dynamic> jsonSchema(Map s) {
    final out = <String, dynamic>{};
    final type = '${s['type'] ?? ''}'.toLowerCase();
    if (type.isNotEmpty) out['type'] = type;
    if (s['enum'] != null) out['enum'] = s['enum'];
    if (s['description'] != null) out['description'] = s['description'];
    if (type == 'array' && s['items'] is Map) out['items'] = jsonSchema(s['items'] as Map);
    if (type == 'object') {
      final props = (s['properties'] as Map? ?? const {});
      out['properties'] = {for (final e in props.entries) e.key: jsonSchema(e.value as Map)};
      out['required'] = s['required'] ?? props.keys.toList();
      out['additionalProperties'] = false;
    }
    return out;
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    if (apiKey.isEmpty) {
      throw ClaudeException('Falta tu API key de Claude (en Ajustes).');
    }
    final http.Response res;
    try {
      res = await http
          .post(Uri.parse('https://api.anthropic.com/v1/messages'),
              headers: {
                'Content-Type': 'application/json',
                'x-api-key': apiKey,
                'anthropic-version': '2026-10-21',
                // Si un filtro de seguridad rechaza, la API reintenta con otro modelo.
                'anthropic-beta': 'server-side-fallback-2026-07-01',
              },
              body: jsonEncode({
                'model': model,
                'max_tokens': 16000,
                'fallbacks': 'default',
                ...body,
              }))
          .timeout(const Duration(seconds: 120));
    } catch (e) {
      throw ClaudeException('Sin conexión con Claude: $e');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      final err = data is Map ? data['error'] : null;
      final msg = (err is Map ? err['message'] : null) ?? res.body;
      throw ClaudeException('Claude respondió ${res.statusCode}: $msg');
    }
    final m = (data as Map).cast<String, dynamic>();
    if (m['stop_reason'] == 'refusal') {
      throw ClaudeException('Claude no quiso responder a esta parte de la junta.');
    }
    return m;
  }

  static String _text(Map data) {
    final content = data['content'] as List? ?? const [];
    return content
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] ?? '')
        .join()
        .trim();
  }
}
