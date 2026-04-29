import 'package:flutter/material.dart';
import 'package:pont_arkipel/services/spreadsheet.dart';
import 'services/arkipel.dart';
import 'services/saved_entries.dart';
import 'model/rdv.dart';
import 'model/person.dart';
import 'model/household.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PontArkipel_SEME',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'PontArkipel_SEME'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _tokenController = TextEditingController();
  final _destinationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SavedEntriesService.init();
    _tokenController.addListener(
      () => ArkipelService.setToken(_tokenController.text),
    );
    _destinationController.addListener(
      () => ArkipelService.setEndpoint(_destinationController.text),
    );
  }

  Future<void> _selectFromList(
    String type,
    TextEditingController controller,
  ) async {
    final entries = type == 'tokens'
        ? SavedEntriesService.tokens
        : SavedEntriesService.destinations;
    if (entries.isEmpty) {
      _log('Aucun élément enregistré dans cette liste');
      return;
    }
    final selected = await showDialog<SavedEntry>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sélectionner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: entries
              .map(
                (e) => ListTile(
                  title: Text(e.name),
                  subtitle: Text(
                    e.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(ctx, e),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null) controller.text = selected.value;
  }

  Future<void> _addToList(
    String type,
    TextEditingController controller,
  ) async {
    if (controller.text.trim().isEmpty) {
      _log('Le champ est vide');
      return;
    }
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom de l\'entrée'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: Production'),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      await SavedEntriesService.add(
        type,
        nameController.text.trim(),
        controller.text.trim(),
      );
      _log('"${nameController.text.trim()}" enregistré');
    }
  }

  Future<void> _deleteFromList(String type) async {
    final entries = type == 'tokens'
        ? SavedEntriesService.tokens
        : SavedEntriesService.destinations;
    if (entries.isEmpty) {
      _log('Aucun élément enregistré dans cette liste');
      return;
    }
    final toDelete = await showDialog<SavedEntry>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: entries
              .map(
                (e) => ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(e.name),
                  subtitle: Text(
                    e.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(ctx, e),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (toDelete != null) {
      await SavedEntriesService.remove(type, toDelete.name);
      _log('"${toDelete.name}" supprimé de la liste');
    }
  }

  bool? _pingOk;
  DateTime? _lastPingTime;
  final List<String> _messages = [];

  final Map<int, Household> _clients = {};
  final Map<int, List<RDV>> _rdvs = {};

  DateTime? _deleteFrom;
  DateTime? _deleteTo;

  void _log(String msg) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() => _messages.insert(0, '[$ts] $msg'));
  }

  Future<void> _ping() async {
    _log('Envoi ping...');
    try {
      await ArkipelService.ping();
      setState(() {
        _pingOk = true;
        _lastPingTime = DateTime.now();
      });
      _log('Ping OK');
    } catch (e) {
      setState(() {
        _pingOk = false;
        _lastPingTime = DateTime.now();
      });
      _log('$e'.replaceFirst('Exception: ', ''));
    }
  }

  static const _fileLabels = {
    FileTypeExcel.clients: 'Clients',
    FileTypeExcel.famille: 'Famille',
    FileTypeExcel.rdv: 'RDV',
  };

  Future<void> _pickFile(FileTypeExcel type) async {
    await SpreadsheetService.pickFile(type);
    _log('Fichier "${_fileLabels[type]}" chargé');
  }

  Widget _fileChip(FileTypeExcel type) {
    final loaded = SpreadsheetService.isLoaded(type);
    return ActionChip(
      avatar: Icon(
        loaded ? Icons.check_circle : Icons.upload_file,
        color: loaded ? Colors.green : Colors.grey,
        size: 18,
      ),
      label: Text(_fileLabels[type]!),
      backgroundColor: loaded ? Colors.green[50] : null,
      onPressed: () => _pickFile(type),
    );
  }

  Future<void> _deleteDistributions() async {
    DateTime? from = _deleteFrom;
    DateTime? to = _deleteTo;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Supprimer des distributions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisissez la période selon la date d\'envoi vers GoToucan '
                '(et non la date de distribution associée dans le système).',
              ),
              const SizedBox(height: 4),
              const Text(
                'Maximum 2000 distributions supprimées par opération.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Date d\'envoi — du'),
                subtitle: Text(
                  from != null ? _formatDate(from!) : 'Non défini',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: from ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setLocal(() => from = picked);
                },
              ),
              ListTile(
                title: const Text('Date d\'envoi — au'),
                subtitle: Text(
                  to != null ? _formatDate(to!) : 'Non défini',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: to ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setLocal(() => to = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: (from != null && to != null)
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _deleteFrom = from;
      _deleteTo = to;
    });

    try {
      await ArkipelService.deleteDistributions(
        createdAtGteq: _formatDate(_deleteFrom!),
        createdAtLteq: _formatDate(_deleteTo!),
        onProgress: _log,
      );
    } catch (e) {
      _log('$e'.replaceFirst('Exception: ', ''));
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _doMagic() async {
    await _read();
    await _send();
  }

  Future<void> _read() async {
    _clients.clear();
    _rdvs.clear();

    _log('Lecture de clients...');
    await for (final row in SpreadsheetService.read(FileTypeExcel.clients)) {
      final clientId = _parseClientId(row["N° de client"]);
      if (clientId == null) continue;
      final household = Household.fromMap(row);
      household.persons.add(
        Person.fromMap(row, householdId: clientId, memberIndex: 0),
      );
      _clients.putIfAbsent(clientId, () => household);
    }
    _log('Clients lus: ${_clients.length}');

    _log('Lecture de RDV...');
    int rdvCount = 0;
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
        if (clientIdInt != null && _clients.containsKey(clientIdInt)) {
          _rdvs.putIfAbsent(clientIdInt, () => []).add(RDV.fromMap(row));
          rdvCount++;
        }
      }
    }
    _log('RDV lus: $rdvCount');

    _log('Lecture de famille...');
    await for (final row in SpreadsheetService.read(FileTypeExcel.famille)) {
      final clientId = _parseClientId(row["N° de client"]);
      if (clientId == null) continue;
      if (!_rdvs.containsKey(clientId)) continue;
      final household = _clients[clientId];
      if (household == null) continue;
      household.persons.add(
        Person.fromMap(
          row,
          householdId: clientId,
          memberIndex: household.persons.length,
        ),
      );
    }
    _log('Famille lue. Clients avec RDV: ${_rdvs.length}');
  }

  Future<void> _send() async {
    _log('Envoi des distributions...');
    await ArkipelService.sendDistributions(
      _rdvs,
      _clients,
      onProgress: _log,
    );
  }

  int? _parseClientId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blue = Colors.lightBlue[200]!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ConfigRow(
              label: 'Jeton d\'accès',
              controller: _tokenController,
              obscure: true,
              onSelect: () => _selectFromList('tokens', _tokenController),
              onAdd: () => _addToList('tokens', _tokenController),
              onDelete: () => _deleteFromList('tokens'),
            ),
            const SizedBox(height: 8),
            _ConfigRow(
              label: 'Destination',
              controller: _destinationController,
              onSelect: () => _selectFromList('destinations', _destinationController),
              onAdd: () => _addToList('destinations', _destinationController),
              onDelete: () => _deleteFromList('destinations'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(onPressed: _ping, child: const Text('Tester la connexion')),
                const SizedBox(width: 8),
                Icon(
                  _pingOk == null
                      ? Icons.circle_outlined
                      : _pingOk!
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _pingOk == null
                      ? Colors.grey
                      : _pingOk!
                      ? Colors.green
                      : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                if (_lastPingTime != null)
                  Text(
                    '${_lastPingTime!.hour.toString().padLeft(2, '0')}:'
                    '${_lastPingTime!.minute.toString().padLeft(2, '0')}:'
                    '${_lastPingTime!.second.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _fileChip(FileTypeExcel.clients),
                const SizedBox(width: 6),
                _fileChip(FileTypeExcel.famille),
                const SizedBox(width: 6),
                _fileChip(FileTypeExcel.rdv),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Tooltip(
                  message: 'Débit : ${ArkipelService.sendRateLabel}',
                  child: OutlinedButton(
                    onPressed: (_pingOk == true &&
                            SpreadsheetService.isLoaded(FileTypeExcel.clients) &&
                            SpreadsheetService.isLoaded(FileTypeExcel.famille) &&
                            SpreadsheetService.isLoaded(FileTypeExcel.rdv))
                        ? _doMagic
                        : null,
                    child: const Text('Envoyer'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _deleteDistributions,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Supprimer distributions'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              color: blue,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: const Text(
                'Messages',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.lightBlue[50],
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => Text(
                    _messages[i],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onSelect;
  final VoidCallback onAdd;
  final VoidCallback onDelete;

  const _ConfigRow({
    required this.label,
    required this.controller,
    this.obscure = false,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 15)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.list),
          tooltip: 'Sélectionner dans la liste',
          onPressed: onSelect,
        ),
        IconButton(
          icon: const Icon(Icons.playlist_add),
          tooltip: 'Ajouter à la liste',
          onPressed: onAdd,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Supprimer de la liste',
          onPressed: onDelete,
        ),
      ],
    );
  }
}