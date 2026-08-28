class Voyage {
  final String uuid;
  final int? id;
  final int sync;
  final String? numeroVoyage;
  final String? dateVoyage;
  final String? lieuDepart;
  final String? lieuDestination;
  final String? dimensionConteneur;
  final double? poidsConteneur;
  final String? natureMarchandise;
  final String? dateDepartOrigine;
  final String? dateArriverDestination;
  final String? dateDepartRetour;
  final String? dateArriverRetour;
  final String? natureMarchandiseRetour;
  final String? nomClientRetour;
  final double? montantConvenuRetour;
  final double? montantConvenu;
  final String? monnaieUuid;
  final String? statut;
  final String? camionUuid;
  final String? chauffeurUuid;
  final String? convoyeurUuid;
  final String? clientUuid;
  final int valide;

  const Voyage({
    required this.uuid,
    this.id,
    this.sync = 0,
    this.numeroVoyage,
    this.dateVoyage,
    this.lieuDepart,
    this.lieuDestination,
    this.dimensionConteneur,
    this.poidsConteneur,
    this.natureMarchandise,
    this.dateDepartOrigine,
    this.dateArriverDestination,
    this.dateDepartRetour,
    this.dateArriverRetour,
    this.natureMarchandiseRetour,
    this.nomClientRetour,
    this.montantConvenuRetour,
    this.montantConvenu,
    this.monnaieUuid,
    this.statut,
    this.camionUuid,
    this.chauffeurUuid,
    this.convoyeurUuid,
    this.clientUuid,
    this.valide = 0,
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
      dimensionConteneur: map['dimension_conteneur'] as String?,
      poidsConteneur: (map['poids_conteneur'] as num?)?.toDouble(),
      natureMarchandise: map['nature_marchandise'] as String?,
      dateDepartOrigine: map['date_depart_origine'] as String?,
      dateArriverDestination: map['date_arriver_destination'] as String?,
      dateDepartRetour: map['date_depart_retour'] as String?,
      dateArriverRetour: map['date_arriver_retour'] as String?,
      natureMarchandiseRetour: map['nature_marchandise_retour'] as String?,
      nomClientRetour: map['nom_client_retour'] as String?,
      montantConvenuRetour: (map['montant_convenu_retour'] as num?)?.toDouble(),
      montantConvenu: (map['montant_convenu'] as num?)?.toDouble(),
      monnaieUuid: map['monnaie_uuid'] as String?,
      statut: map['statut'] as String?,
      camionUuid: map['camion_uuid'] as String?,
      chauffeurUuid: map['chauffeur_uuid'] as String?,
      convoyeurUuid: map['convoyeur_uuid'] as String?,
      clientUuid: map['client_uuid'] as String?,
      valide: (map['valide'] as int?) ?? 0,
    );
  }
}
