import 'package:flutter/material.dart';
import 'package:pont_arkipel/services/spreadsheet.dart';
import 'services/arkipel.dart';
import 'model/rdv.dart';
import 'model/person.dart';
import 'model/household.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pont Arkipel',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Pont Arkipel'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _message = 'No message yet';
  void _ping() {
    setState(() {
      _message = 'Sent ping...';
      ArkipelService.ping();
      _message = ArkipelService.arkipelResponse;
    });
  }

  Future<void> _pickFileClients() async {
    await SpreadsheetService.pickFile(FileTypeExcel.clients);

    setState(() {
      _message = 'File "Clients" picked successfully!';
    });
  }

  Future<void> _pickFileFamille() async {
    await SpreadsheetService.pickFile(FileTypeExcel.famille);

    setState(() {
      _message = 'File "Famille" picked successfully!';
    });
  }

  Future<void> _pickFileRDV() async {
    await SpreadsheetService.pickFile(FileTypeExcel.rdv);

    setState(() {
      _message = 'File "RDV" picked successfully!';
    });
  }

  final Map<int, Household> clients = {};
  final Map<int, List<RDV>> rdvs = {};

  Future<void> _read() async {
    clients.clear();
    rdvs.clear();

    ///////////////////////
    // Clients

    setState(() {
      _message = 'Lecture de clients...';
    });

    await for (final row in SpreadsheetService.read(FileTypeExcel.clients)) {
      final clientId = parseClientId(row["N° de client"]);
      if (clientId == null) continue;

      final household = Household.fromMap(row);

      household.persons.add(
        Person.fromMap(
          row,
          householdId: clientId,
          memberIndex: 0,
        ),
      );

      clients.putIfAbsent(clientId, () => household);
    }

    // for (final household in clients.values.take(2)) {
    //   print('Client number: ${household.id}, Source revenu: ${household.sourceRevenu}');
    // }

    setState(() {
      _message = 'Terminé de lire clients';
    });

    ///////////////////////
    // RDV

    setState(() {
      _message = 'Lecture de RDV...';
    });

    const validServices = {
      "Régulier",
      "Trait d'union",
      "Livraison",
      "Dépannage d'urgence",
    };

    await for (final row in SpreadsheetService.read(FileTypeExcel.rdv)) {
      final statut = row["Statut"];
      final service = row["Service"];
      final clientId = row["N° de client"];
      if (clientId == null) continue;
      if ((statut != null && statut != "Absent") &&
          validServices.contains(service)) {
        final clientIdInt = int.tryParse(clientId);
        if (clientIdInt != null) {
          if (!clients.containsKey(clientIdInt)) {
            print('Client introuvable : $clientIdInt}');
            continue;
          }
          rdvs.putIfAbsent(clientIdInt, () => []).add(RDV.fromMap(row));
        }
      }
    }

    setState(() {
      _message = 'Terminé de lire RDV';
    });

    // // Print RDV
    // for (final entry in rdvs.entries) {
    //   final clientId = entry.key;
    //   final household = clients[clientId];
    //   final label = household != null
    //       ? 'Household ${household.id}'
    //       : 'Client inconnu ($clientId)';

    //   print('┌─ $label — ${entry.value.length} RDV');
    //   for (final rdv in entry.value) {
    //     final serial = int.tryParse(rdv.date.toString());
    //     final date = serial != null
    //         ? DateTime(1899, 12, 30).add(Duration(days: serial))
    //         : null;
    //     final dateStr = date != null
    //         ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
    //         : rdv.date.toString();

    //     print('│   • $dateStr  ${rdv.service}');
    //   }
    //   print('└─────────────────────────────────');
    // }

    ///////////////////////
    // Famille

    setState(() {
      _message = 'Lecture de famille...';
    });

    await for (final row in SpreadsheetService.read(FileTypeExcel.famille)) {
      final clientId = parseClientId(row["N° de client"]);
      if (clientId == null) continue;
      if (!rdvs.containsKey(clientId)) continue;

      final household = clients[clientId];
      if (household == null) continue;

      household.persons.add(
        Person.fromMap(
          row,
          householdId: clientId,
          memberIndex: household.persons.length,
        ),
      );
    }

    setState(() {
      _message = 'Terminé de lire famille';
    });

    // Print all families
    for (final clientId in rdvs.keys) {
      final household = clients[clientId];
      if (household == null) continue;

      print(
        '┌─ Household ${household.id} — ${household.persons.length} personnes',
      );
      for (final person in household.persons) {
        final dobStr = person.dateOfBirth != null
            ? '${person.dateOfBirth!.year}-${person.dateOfBirth!.month.toString().padLeft(2, '0')}-${person.dateOfBirth!.day.toString().padLeft(2, '0')}'
            : 'DoB inconnue';
        print('│   • ${person.id}  $dobStr');
      }
      print('└─────────────────────────────────');
    }
  }

  Future<void> _send() async {
    await ArkipelService.sendDistributions(rdvs, clients, limit: 4);
    setState(() {
      _message = ArkipelService.arkipelResponse;
    });
  }
  
  int? parseClientId(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: <Widget>[
            Text(_message, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            onPressed: _ping,
            tooltip: 'Ping',
            child: const Text('Ping'),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _message = 'No message yet';
              });
            },
            tooltip: 'Clear message',
            child: const Text('Clear'),
          ),
          FloatingActionButton(
            onPressed: _pickFileRDV,
            tooltip: 'Pick file "RDV"',
            child: const Text('Pick file "RDV"'),
          ),
          FloatingActionButton(
            onPressed: _pickFileClients,
            tooltip: 'Pick file "Clients"',
            child: const Text('Pick file "Clients"'),
          ),
          FloatingActionButton(
            onPressed: _pickFileFamille,
            tooltip: 'Pick file "Famille"',
            child: const Text('Pick file "Famille"'),
          ),
          FloatingActionButton(
            onPressed: _read,
            tooltip: 'Read',
            child: const Text('Read'),
          ),
          FloatingActionButton(
            onPressed: _send,
            tooltip: 'Send',
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
