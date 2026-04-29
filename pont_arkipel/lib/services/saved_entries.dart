import 'dart:convert';
import 'dart:io';

class SavedEntry {
  final String name;
  final String value;

  const SavedEntry({required this.name, required this.value});

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  factory SavedEntry.fromJson(Map<String, dynamic> json) =>
      SavedEntry(name: json['name'] as String, value: json['value'] as String);
}

class SavedEntriesService {
  static File? _file;
  static final Map<String, List<SavedEntry>> _data = {
    'tokens': [],
    'destinations': [],
  };

  static Future<void> init() async {
    final appData = Platform.environment['APPDATA'] ?? '.';
    final dir = Directory('$appData\\pont_arkipel');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _file = File('${dir.path}\\entries.json');
    if (_file!.existsSync()) {
      final raw = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
      for (final key in _data.keys) {
        _data[key] = ((raw[key] as List?) ?? [])
            .map((e) => SavedEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
  }

  static List<SavedEntry> get tokens => List.unmodifiable(_data['tokens']!);
  static List<SavedEntry> get destinations => List.unmodifiable(_data['destinations']!);

  static Future<void> add(String type, String name, String value) async {
    _data[type]!.removeWhere((e) => e.name == name);
    _data[type]!.add(SavedEntry(name: name, value: value));
    await _save();
  }

  static Future<void> remove(String type, String name) async {
    _data[type]!.removeWhere((e) => e.name == name);
    await _save();
  }

  static Future<void> _save() async {
    final json = {
      for (final key in _data.keys)
        key: _data[key]!.map((e) => e.toJson()).toList(),
    };
    await _file!.writeAsString(jsonEncode(json));
  }
}
