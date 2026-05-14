class Monnaie {
  final String uuid;
  final int? id;
  final int sync;
  final String nom;
  final String? sigle;

  const Monnaie({
    required this.uuid,
    this.id,
    this.sync = 0,
    required this.nom,
    this.sigle,
  });

  factory Monnaie.fromMap(Map<String, dynamic> map) {
    return Monnaie(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: (map['sync'] as int?) ?? 0,
      nom: map['nom'] as String,
      sigle: map['sigle'] as String?,
    );
  }

  String get label => sigle != null && sigle!.isNotEmpty ? '$nom (${sigle!})' : nom;
}
