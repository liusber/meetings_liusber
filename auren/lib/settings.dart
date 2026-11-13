import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  late SharedPreferences _p;

  String apiKey = '';
  String model = 'claude-opus-5-5';
  String myName = '';
  String myRole = 'Responsable de TI en un grupo automotriz';
  String localeId = 'es_MX';
  int intervalSec = 30;
  int newsMin = 3; // 0 = sin noticias automáticas
  /// Proporción de ancho de las 3 columnas de la junta.
  List<double> columns = [1, 1, 1];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    apiKey = _p.getString('apiKey') ?? apiKey;
    model = _p.getString('model') ?? model;
    myName = _p.getString('myName') ?? myName;
    myRole = _p.getString('myRole') ?? myRole;
    localeId = _p.getString('localeId') ?? localeId;
    intervalSec = _p.getInt('intervalSec') ?? intervalSec;
    newsMin = _p.getInt('newsMin') ?? newsMin;
    final cols = _p.getStringList('columns')?.map(double.tryParse).whereType<double>().toList();
    if (cols != null && cols.length == 3) columns = cols;
  }

  Future<void> update({
    String? apiKey,
    String? model,
    String? myName,
    String? myRole,
    String? localeId,
    int? intervalSec,
    int? newsMin,
    List<double>? columns,
  }) async {
    if (apiKey != null) await _p.setString('apiKey', this.apiKey = apiKey.trim());
    if (model != null) await _p.setString('model', this.model = model.trim());
    if (myName != null) await _p.setString('myName', this.myName = myName);
    if (myRole != null) await _p.setString('myRole', this.myRole = myRole);
    if (localeId != null) await _p.setString('localeId', this.localeId = localeId);
    if (intervalSec != null) {
      await _p.setInt('intervalSec', this.intervalSec = intervalSec);
    }
    if (newsMin != null) await _p.setInt('newsMin', this.newsMin = newsMin);
    if (columns != null) {
      await _p.setStringList('columns', (this.columns = columns).map((c) => '$c').toList());
    }
    notifyListeners();
  }
}
