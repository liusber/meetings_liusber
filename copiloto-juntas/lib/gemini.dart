import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

/// Cliente mínimo de la API de Gemini (Google AI Studio) que siempre
/// pide respuesta en JSON con un esquema.
class GeminiClient {
  final String apiKey;
  final String model;

  GeminiClient(this.apiKey, this.model);

  /// Respuesta en texto apoyada en Google Search. Devuelve el texto y las
  /// fuentes web que usó; sin fuentes la respuesta no está verificada.
  Future<({String text, List<({String title, String url})> sources})> searchText({
    required String system,
    required String prompt,
  }) async {
    final data = await _post({
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'tools': [
        {'google_search': {}}
      ],
      'generationConfig': {
        'thinkingConfig': {'thinkingLevel': 'low'},
      },
    });
    final first = _firstCandidate(data);
    final meta = first?['groundingMetadata'] as Map?;
    final chunks = meta?['groundingChunks'] as List? ?? const [];
    final sources = [
      for (final c in chunks)
        if (c is Map && c['web'] is Map)
          (title: '${c['web']['title'] ?? ''}', url: '${c['web']['uri'] ?? ''}')
    ];
    return (text: _text(first), sources: sources);
  }

  Future<Map<String, dynamic>> generateJson({
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    double temperature = 0.7,
    String? thinkingLevel,
  }) async {
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'responseMimeType': 'application/json',
        'responseSchema': schema,
        if (thinkingLevel != null) 'thinkingConfig': {'thinkingLevel': thinkingLevel},
      },
    };
    final text = _text(_firstCandidate(await _post(body)));
    if (text.isEmpty) throw GeminiException('Gemini no devolvió texto.');
    try {
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    } catch (_) {
      throw GeminiException('Gemini devolvió algo que no es JSON.');
    }
  }

  Future<dynamic> _post(Map<String, dynamic> body) async {
    if (apiKey.isEmpty) {
      throw GeminiException('Falta tu API key de Gemini (en Ajustes).');
    }
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    final http.Response res;
    try {
      res = await http
          .post(uri,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw GeminiException('Sin conexión con Gemini: $e');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      final err = data is Map ? data['error'] : null;
      final msg = (err is Map ? err['message'] : null) ?? res.body;
      throw GeminiException('Gemini respondió ${res.statusCode}: $msg');
    }
    return data;
  }

  static Map? _firstCandidate(dynamic data) {
    final candidates = data is Map ? data['candidates'] as List? ?? const [] : const [];
    return candidates.isEmpty ? null : candidates.first as Map?;
  }

  static String _text(Map? candidate) {
    final parts = candidate?['content']?['parts'] as List?;
    return parts?.map((p) => p['text'] ?? '').join().trim() ?? '';
  }
}
