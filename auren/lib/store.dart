import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Guarda cada junta como un JSON en la carpeta de soporte de la app,
/// y la "Libreta de metáforas" (datos y metáforas guardadas) en libreta.json.
class MeetingStore extends ChangeNotifier {
  late final Directory _dir;
  List<Meeting> meetings = [];
  List<Note> libreta = [];

  Future<void> load() async {
    final base = await getApplicationSupportDirectory();
    _dir = Directory('${base.path}/juntas');
    await _dir.create(recursive: true);
    final files = _dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json') && !f.path.endsWith('libreta.json'));
    meetings = [];
    for (final f in files) {
      try {
        meetings.add(Meeting.fromJson(jsonDecode(await f.readAsString())));
      } catch (_) {
        // Archivo dañado: se ignora para no tumbar la app.
      }
    }
    meetings.sort((a, b) => b.date.compareTo(a.date));
    final lib = File('${_dir.path}/libreta.json');
    if (await lib.exists()) {
      try {
        libreta = (jsonDecode(await lib.readAsString()) as List)
            .map((e) => Note.fromJson((e as Map).cast()))
            .toList();
      } catch (_) {}
    }
    notifyListeners();
  }

  File _file(String id) => File('${_dir.path}/$id.json');

  Meeting create() {
    final m = Meeting();
    meetings.insert(0, m);
    save(m);
    return m;
  }

  Future<void> save(Meeting m) async {
    final i = meetings.indexWhere((x) => x.id == m.id);
    if (i >= 0) meetings[i] = m;
    notifyListeners();
    await _file(m.id).writeAsString(
        const JsonEncoder.withIndent(' ').convert(m.toJson()),
        flush: true);
  }

  Future<void> delete(String id) async {
    meetings.removeWhere((m) => m.id == id);
    notifyListeners();
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }

  Future<void> addToLibreta(String text) async {
    if (libreta.any((n) => n.text == text)) return;
    libreta.insert(0, Note(text: text));
    await _saveLibreta();
  }

  Future<void> removeFromLibreta(String id) async {
    libreta.removeWhere((n) => n.id == id);
    await _saveLibreta();
  }

  Future<void> _saveLibreta() async {
    notifyListeners();
    await File('${_dir.path}/libreta.json').writeAsString(
        jsonEncode(libreta.map((n) => n.toJson()).toList()),
        flush: true);
  }
}
