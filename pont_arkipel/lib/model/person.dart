class Person {
  final int householdId;
  final int memberIndex;
  final DateTime? dateOfBirth;
  final bool? femme;

  Person({
    required this.householdId,
    required this.memberIndex,
    required this.dateOfBirth,
    required this.femme,
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

    return Person(
      householdId: householdId,
      memberIndex: memberIndex,
      dateOfBirth: dob,
      femme: map["Sexe"]?.toString() == "Femme",
    );
  }
}
