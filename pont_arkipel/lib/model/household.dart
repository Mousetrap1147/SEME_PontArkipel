import 'package:pont_arkipel/model/person.dart';

class Household {
  final String id;
  final String? sourceRevenu;
  final String? raison;
  final String? habitation;
  final List<Person> persons;

  Household({
    required this.id,
    required this.sourceRevenu,
    required this.raison,
    required this.habitation,
    required this.persons,
  });

  factory Household.fromMap(Map<String, dynamic> map) {
    return Household(
      id: map["N° de client"],
      sourceRevenu: map["Source de revenu"],
      raison: map["Raison"],
      habitation: map["Logement"],
      persons: [],
    );
  }
}
