class RDV {
  final int date;
  final String service;

  RDV({
    required this.date,
    required this.service,
  });

  factory RDV.fromMap(Map<String, dynamic> map) {
    return RDV(
      date: map['Date']?.toInt() ?? 0,
      service: map['Service']?.toString() ?? '',
    );
  }
}
