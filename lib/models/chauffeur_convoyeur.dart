class ChauffeurConvoyeur {
  final String uuid;
  final int? id;
  final int sync;
  final String nom;
  final String? telephone;
  final String? adresse;
  final String? dateEngagement;
  final String? fonction;

  const ChauffeurConvoyeur({
    required this.uuid,
    this.id,
    this.sync = 0,
    required this.nom,
    this.telephone,
    this.adresse,
    this.dateEngagement,
    this.fonction,
  });

  factory ChauffeurConvoyeur.fromMap(Map<String, dynamic> map) {
    return ChauffeurConvoyeur(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: (map['sync'] as int?) ?? 0,
      nom: map['nom'] as String,
      telephone: map['telephone'] as String?,
      adresse: map['adresse'] as String?,
      dateEngagement: map['date_engagement'] as String?,
      fonction: map['fonction'] as String?,
    );
  }
}
