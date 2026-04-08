import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pont_arkipel/model/household.dart';
import 'package:pont_arkipel/model/rdv.dart';

class ArkipelService {
  static final Uri endpoint = Uri.parse(
    "https://staging.gotoucan.app/arkipel/ymhs9rzyfic33s85cy3hizof4sieah3rc3x9spbqhczkzsizzw1i/streams",
  );

  static String arkipelResponse = "No data yet";

  static Future<void> ping() async {
    print("Sending request...");

    String tokenPath = r"C:\Users\maxim\Desktop\ArkipelToken.txt";
    String token = await File(tokenPath).readAsString();

    var payload = {
      "payload": {
        "type": "ping",
      },
      "source_public_key": ""
    };

    try {
      final response = await http.post(
        endpoint,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode(payload),
      );

      print("Status: ${response.statusCode}");

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
    int? limit
  }
) async {
  String tokenPath = r"C:\Users\maxim\Desktop\ArkipelToken.txt";
  String token = await File(tokenPath).readAsString();

  final entries = limit != null
      ? rdvs.entries.take(limit)
      : rdvs.entries;

  for (final entry in entries) {
    final clientId = entry.key;
    final household = clients[clientId];
    if (household == null) continue;

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
          "people": household.persons.map((person) => {
            "type": "people:upsert",
            "first_name" : person.id,
            "import_id": person.id,
            "dob": person.dateOfBirth != null
                ? '${person.dateOfBirth!.year}-${person.dateOfBirth!.month.toString().padLeft(2, '0')}-${person.dateOfBirth!.day.toString().padLeft(2, '0')}'
                : null,
          }).toList(),
        }
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
        print('Distribution envoyée — message_id: $messageId ($procuredOn ${rdv.service} → client $clientId)');
      } catch (e) {
        print('Erreur envoi distribution client $clientId: $e');
      }
    }
  }
}
}