import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pont_arkipel/model/household.dart';
import 'package:pont_arkipel/model/rdv.dart';

class ArkipelService {
  static String? _customToken;
  static Uri? _customEndpoint;

  static void setToken(String token) => _customToken = token.trim();
  static void setEndpoint(String value) {
    final s = value.trim();
    if (s.isEmpty) {
      _customEndpoint = null;
      return;
    }
    final atIndex = s.indexOf('@');
    if (atIndex > 0) {
      final key = s.substring(0, atIndex);
      final domain = s.substring(atIndex + 1);
      _customEndpoint = Uri.parse('https://$domain/arkipel/$key/streams');
    } else {
      _customEndpoint = Uri.parse(s);
    }
  }

  static Uri get endpoint {
    if (_customEndpoint == null) throw Exception('Aucune destination saisie');
    return _customEndpoint!;
  }

  static String arkipelResponse = "No data yet";

  /// Throws a descriptive [Exception] on failure, returns normally on success.
  static Future<void> ping() async {
    final token = await _readToken();

    final response = await http.post(
      endpoint,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "payload": {"type": "ping"},
        "source_public_key": "",
      }),
    );

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Adresse de destination incorrecte');
    }

    if (decoded.containsKey('error')) {
      throw Exception('Token refusé par le serveur');
    }

    final type = decoded['payload']?['type'];
    if (type != 'pong') {
      throw Exception('Adresse de destination incorrecte');
    }
  }

  static String _padId(String id) {
    final parts = id.split('-');
    parts[0] = parts[0].padLeft(4, '0');
    return parts.join('-');
  }

  static const Map<String, int> _templateIds = {
    "Régulier": 120884,
    "Trait d'union": 120884,
    "Livraison": 120884,
    "Dépannage d'urgence": 515887,
  };

  static const int _sendDelayMs = 650;
  static String get sendRateLabel =>
      '~${(60000 / _sendDelayMs).round()} distributions/min';

  static Future<void> sendDistributions(
    Map<int, List<RDV>> rdvs,
    Map<int, Household> clients, {
    int? limit,
    void Function(String)? onProgress,
  }) async {
    final token = await _readToken();

    final entries = limit != null ? rdvs.entries.take(limit) : rdvs.entries;
    final total = entries.fold<int>(0, (sum, e) => sum + e.value.length);
    int sent = 0;

    for (final entry in entries) {
      final clientId = entry.key;
      final household = clients[clientId];
      if (household == null) continue;

      for (final rdv in entry.value) {
        final templateId = _templateIds[rdv.service];
        if (templateId == null) {
          onProgress?.call('Service inconnu ignoré : ${rdv.service} (client $clientId)');
          continue;
        }

        final date = DateTime(1899, 12, 30).add(Duration(days: rdv.date));
        final procuredOn =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final payload = {
          "type": "distributions:upsert",
          "template_id": templateId,
          "procured_on": procuredOn,
          "quantity": 1,
          "buyer": {
            "type": "households:upsert",
            "name": _padId(household.id),
            "import_id": _padId(household.id),
            "people": household.persons
                .map(
                  (person) => {
                    "type": "people:upsert",
                    "first_name": _padId(person.id),
                    "import_id": _padId(person.id),
                    "category_id": 127,
                    "dob": person.dateOfBirth != null
                        ? '${person.dateOfBirth!.year}-${person.dateOfBirth!.month.toString().padLeft(2, '0')}-${person.dateOfBirth!.day.toString().padLeft(2, '0')}'
                        : null,
                  },
                )
                .toList(),
          },
        };

        try {
          final response = await http.post(
            endpoint,
            headers: {
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({"payload": payload}),
          );

          final decoded = jsonDecode(response.body);
          final messageId = decoded['payload']['message_id'];
          sent++;
          onProgress?.call('[$sent/$total] Client ${_padId(household.id)} — $procuredOn (${rdv.service}) ✓ #$messageId');
        } catch (e) {
          onProgress?.call('Erreur client $clientId : $e');
        }

        await Future.delayed(const Duration(milliseconds: _sendDelayMs));
      }
    }

    onProgress?.call('Terminé : $sent/$total distributions envoyées');
  }

  static Future<void> deleteDistributions({
    required String createdAtGteq,
    required String createdAtLteq,
    void Function(String)? onProgress,
  }) async {
    final token = await _readToken();

    onProgress?.call('Suppression des distributions du $createdAtGteq au $createdAtLteq...');

    final Map<String, dynamic> decoded;
    try {
      final response = await http.post(
        endpoint,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "payload": {
            "type": "distributions:delete",
            "q": {
              "per_page": 2000,
              "page": 1,
              "created_at_gteq": createdAtGteq,
              "created_at_lteq": createdAtLteq,
            },
          },
        }),
      );
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Réponse invalide du serveur');
    }

    if (decoded.containsKey('error')) {
      throw Exception(decoded['error'].toString());
    }

    final messageId = decoded['payload']?['message_id'];
    onProgress?.call('Suppression effectuée ✓ #$messageId');
  }

  static Future<String> _readToken() async {
    if (_customToken == null || _customToken!.isEmpty) throw Exception('Aucun jeton saisi');
    return _customToken!;
  }

  static Future<void> deleteAllTestData(
    Map<int, Household> clients,
    Map<int, List<RDV>> rdvs,
  ) async {
    final token = await _readToken();
    final clientIds = rdvs.keys.map((id) => _padId(id.toString())).toSet();

    print('ClientIds to delete: $clientIds');

    await _deleteMatchingRecords(
      token,
      'households:query',
      'household:delete',
      'Household',
      (resource) => clientIds.contains(resource['name']?.toString()),
    );

    await _deleteMatchingRecords(
      token,
      'people:query',
      'person:delete',
      'Personne',
      (resource) {
        final importId = resource['import_id']?.toString() ?? '';
        final baseId = importId.split('-').first;
        return clientIds.contains(baseId);
      },
    );
  }

  static Future<void> _deleteMatchingRecords(
    String token,
    String queryType,
    String deleteType,
    String label,
    bool Function(Map) shouldDelete,
  ) async {
    int page = 1;
    int deleted = 0;

    while (true) {
      final queryResponse = await http.post(
        endpoint,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "payload": {
            "type": queryType,
            "q": {"per_page": 100, "page": page},
          },
        }),
      );

      final queryData = jsonDecode(queryResponse.body);
      final resources = queryData['payload']['resources'] as List;

      if (resources.isEmpty) break;

      for (final resource in resources) {
        if (shouldDelete(resource)) {
          final id = resource['id'];
          await http.post(
            endpoint,
            headers: {
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "payload": {"type": deleteType, "id": id},
            }),
          );
          deleted++;
          print('🗑️ $label $id supprimé ($deleted)');
          await Future.delayed(const Duration(milliseconds: 700));
        } else {
          print(
            '⏭️ Skipped: ${resource['import_id']} / ${resource['first_name']}',
          );
        }
      }

      final total = queryData['payload']['q']['total'] as int;
      if (page * 100 >= total) break;
      page++;
    }

    print('✅ $deleted $label(s) supprimés');
  }
}
