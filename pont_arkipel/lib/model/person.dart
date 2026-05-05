class Person {
  final int householdId;
  final int memberIndex;
  final DateTime? dateOfBirth;
  final bool? femme;
  final bool etudiant;
  final bool nouvelArrivant;
  final bool autochtone;

  Person({
    required this.householdId,
    required this.memberIndex,
    required this.dateOfBirth,
    required this.femme,
    this.etudiant = false,
    this.nouvelArrivant = false,
    this.autochtone = false,
  });

  String get id => memberIndex == 0
      ? '$householdId'
      : '$householdId-${String.fromCharCode('A'.codeUnitAt(0) + memberIndex - 1)}';

  String get groupeDage {
    if (dateOfBirth == null) return 'adulte';
    final age = DateTime.now().difference(dateOfBirth!).inDays ~/ 365;
    return age >= 18 ? 'adulte' : 'enfant';
  }

  factory Person.fromMap(
    Map<String, dynamic> map, {
    required int householdId,
    required int memberIndex,
  }) {
    final serial = int.tryParse(map["Date de naissance"].toString());
    final dob = serial != null
        ? DateTime(1899, 12, 30).add(Duration(days: serial))
        : null;

    bool parseBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v != 0;
      final s = v.toString().trim();
      return s == '1' || s.toLowerCase() == 'true';
    }

    return Person(
      householdId: householdId,
      memberIndex: memberIndex,
      dateOfBirth: dob,
      femme: map["Sexe"]?.toString() == "Femme",
      etudiant: parseBool(map["Étudiant"]),
      nouvelArrivant: parseBool(map["Immigrant"]),
      autochtone: parseBool(map["Premières Nations"]),
    );
  }
}
