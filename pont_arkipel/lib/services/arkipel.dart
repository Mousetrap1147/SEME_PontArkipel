import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

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
}