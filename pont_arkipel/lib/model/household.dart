import 'package:pont_arkipel/model/person.dart';

class Household {
  final String id;
  final String? typeMenage;
  final String? sourceRevenu;
  final String? raison;
  final String? habitation;
  final List<Person> persons;

  Household({
    required this.id,
    required this.typeMenage,
    required this.sourceRevenu,
    required this.raison,
    required this.habitation,
    required this.persons,
  });

  factory Household.fromMap(Map<String, dynamic> map) {
    return Household(
      id: map["N° de client"],
      typeMenage: map["Type de ménage autre"]?.toString(),
      sourceRevenu: map["Source de revenu"]?.toString(),
      raison: map["Raison"]?.toString(),
      habitation: map["Logement"]?.toString(),
      persons: [],
    );
  }
}
