import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pont_arkipel/model/household.dart';
import 'package:pont_arkipel/model/rdv.dart';

class ArkipelService {
  static final Uri endpoint = Uri.parse(
    "https://gotoucan.app/arkipel/b3y674i4k159y7hs6px6ju8idat1rggdn1ssb5nzc4h6krthrrah/streams",
  );

  static String arkipelResponse = "No data yet";

  static Future<void> ping() async {
    print("Sending request...");

    final token = await _readToken();
    print(
      "Token: '${token.substring(0, 10)}...'",
    ); // verify token starts correctly
    print("Endpoint: $endpoint"); // verify URL

    var payload = {
      "payload": {"type": "ping"},
      "source_public_key": "",
    };

    try {
      final response = await http.post(
        endpoint,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      print("Status: ${response.statusCode}");
      print("Body: ${response.body.substring(0, 100)}");

      var decoded = jsonDecode(response.body);
      var pretty = const JsonEncoder.withIndent('  ').convert(decoded);

      print("\nResponse:");
      print(pretty);

      arkipelResponse = pretty;
    } catch (e) {
      print("Error: $e");
    }
  }

  static const Map<String, int> _templateIds = {
    "Régulier": 120884,
    "Trait d'union": 120884,
    "Livraison": 120884,
    "Dépannage d'urgence": 515887,
  };

  static Future<void> sendDistributions(
    Map<int, List<RDV>> rdvs,
    Map<int, Household> clients, {
    int? limit,
  }) async {
    String tokenPath = r"C:\Users\maxim\Desktop\ArkipelToken.txt";
    String token = await File(tokenPath).readAsString();

    final entries = limit != null ? rdvs.entries.take(limit) : rdvs.entries;

    int sent = 0;

    for (final entry in entries) {
      final clientId = entry.key;
      final household = clients[clientId];
      if (household == null) continue;

      print('Sending client $clientId with ${entry.value.length} RDVs'); // 👈

      print('Client number: ${household.id}');

      for (final rdv in entry.value) {
        final templateId = _templateIds[rdv.service];
        if (templateId == null) {
          print('Template inconnu pour service: ${rdv.service}');
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
            "name": '${household.id}',
            "import_id": '${household.id}',
            "people": household.persons
                .map(
                  (person) => {
                    "type": "people:upsert",
                    "first_name": person.id,
                    "import_id": person.id,
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
          print(
            'Distribution envoyée — message_id: $messageId ($procuredOn ${rdv.service} → client $clientId)',
          );
        } catch (e) {
          print('Erreur envoi distribution client $clientId: $e');
        }

        // Pause pour API
        await Future.delayed(const Duration(milliseconds: 650));
      }
    }

    print('✅ $sent distributions envoyées');
  }

  static Future<String> _readToken() async {
    return (await File(
      r"C:\Users\maxim\Desktop\ArkipelToken.txt",
    ).readAsString()).trim();
  }

  static Future<void> deleteAllTestData(
    Map<int, Household> clients,
    Map<int, List<RDV>> rdvs,
  ) async {
    final token = await _readToken();
    final clientIds = rdvs.keys.map((id) => id.toString()).toSet();

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
