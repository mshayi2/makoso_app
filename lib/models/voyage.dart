class Voyage {
  final String uuid;
  final int? id;
  final int sync;
  final String? numeroVoyage;
  final String? dateVoyage;
  final String? lieuDepart;
  final String? lieuDestination;
  final double? montantConvenu;
  final String? monnaieUuid;
  final String? statut;
  final String? camionUuid;
  final String? chauffeurUuid;
  final String? convoyeurUuid;

  const Voyage({
    required this.uuid,
    this.id,
    this.sync = 0,
    this.numeroVoyage,
    this.dateVoyage,
    this.lieuDepart,
    this.lieuDestination,
    this.montantConvenu,
    this.monnaieUuid,
    this.statut,
    this.camionUuid,
    this.chauffeurUuid,
    this.convoyeurUuid,
  });

  factory Voyage.fromMap(Map<String, dynamic> map) {
    return Voyage(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: (map['sync'] as int?) ?? 0,
      numeroVoyage: map['numero_voyage'] as String?,
      dateVoyage: map['date_voyage'] as String?,
      lieuDepart: map['lieu_depart'] as String?,
      lieuDestination: map['lieu_destination'] as String?,
      montantConvenu: (map['montant_convenu'] as num?)?.toDouble(),
      monnaieUuid: map['monnaie_uuid'] as String?,
      statut: map['statut'] as String?,
      camionUuid: map['camion_uuid'] as String?,
      chauffeurUuid: map['chauffeur_uuid'] as String?,
      convoyeurUuid: map['convoyeur_uuid'] as String?,
    );
  }
}
