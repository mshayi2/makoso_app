class Conteneur {
  final String uuid;
  final int? id;
  final int? sync;
  final String? dossierUuid;
  final String? numeroConteneur;
  final String? dimension;
  final String? dateSortiPort;
  final String? nomTransporteur;
  final String? marqueCamion;
  final String? numeroPlaque;
  final String? nomChauffeur;
  final String? numeroChauffeur;
  final String? lieuDechargement;
  final String? dateArriverLieuDechargement;
  final String? dateDechargement;
  final String? dateDepartRetourPort;
  final String? dateRetourPort;

  const Conteneur({
    required this.uuid,
    this.id,
    this.sync,
    this.dossierUuid,
    this.numeroConteneur,
    this.dimension,
    this.dateSortiPort,
    this.nomTransporteur,
    this.marqueCamion,
    this.numeroPlaque,
    this.nomChauffeur,
    this.numeroChauffeur,
    this.lieuDechargement,
    this.dateArriverLieuDechargement,
    this.dateDechargement,
    this.dateDepartRetourPort,
    this.dateRetourPort,
  });

  factory Conteneur.fromMap(Map<String, Object?> map) {
    return Conteneur(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: map['sync'] as int?,
      dossierUuid: map['dossier_uuid'] as String?,
      numeroConteneur: map['numero_conteneur'] as String?,
      dimension: map['dimension'] as String?,
      dateSortiPort: map['date_sorti_port'] as String?,
      nomTransporteur: map['nom_transporteur'] as String?,
      marqueCamion: map['marque_camion'] as String?,
      numeroPlaque: map['numero_plaque'] as String?,
      nomChauffeur: map['nom_chauffeur'] as String?,
      numeroChauffeur: map['numero_chauffeur'] as String?,
      lieuDechargement: map['lieu_dechargement'] as String?,
      dateArriverLieuDechargement: map['date_arriver_lieu_dechargement'] as String?,
      dateDechargement: map['date_dechargement'] as String?,
      dateDepartRetourPort: map['date_depart_retour_port'] as String?,
      dateRetourPort: map['date_retour_port'] as String?,
    );
  }
}