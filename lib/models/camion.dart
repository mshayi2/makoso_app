class Camion {
  final String uuid;
  final int? id;
  final int sync;
  final String? marque;
  final String? plaque;
  final String? modele;
  final String? capacite;

  const Camion({
    required this.uuid,
    this.id,
    this.sync = 0,
    this.marque,
    this.plaque,
    this.modele,
    this.capacite,
  });

  factory Camion.fromMap(Map<String, dynamic> map) {
    return Camion(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: (map['sync'] as int?) ?? 0,
      marque: map['marque'] as String?,
      plaque: map['plaque'] as String?,
      modele: map['modele'] as String?,
      capacite: map['capacite'] as String?,
    );
  }
}
