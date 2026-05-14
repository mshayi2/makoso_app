class Dossier {
  final String uuid;
  final int? id;
  final int? sync;
  final String? clientUuid;
  final String? numeroBl;
  final String? portChargement;
  final String? portDestination;
  final String? natureMarchandise;
  final String? dateArriveePn;
  final String? dateArriveeMatadi;
  final String? datePaiement30Draft;
  final String? datePaiement30Pn;
  final String? datePaiement40Matadi;
  final double? montantConvenu;
  final String? statut;
  final String? dateCreation;

  const Dossier({
    required this.uuid,
    this.id,
    this.sync,
    this.clientUuid,
    this.numeroBl,
    this.portChargement,
    this.portDestination,
    this.natureMarchandise,
    this.dateArriveePn,
    this.dateArriveeMatadi,
    this.datePaiement30Draft,
    this.datePaiement30Pn,
    this.datePaiement40Matadi,
    this.montantConvenu,
    this.statut,
    this.dateCreation,
  });

  factory Dossier.fromMap(Map<String, Object?> m) {
    return Dossier(
      uuid: m['uuid'] as String,
      id: m['id'] as int?,
      sync: m['sync'] as int?,
      clientUuid: m['client_uuid'] as String?,
      numeroBl: m['numero_bl'] as String?,
      portChargement: m['port_chargement'] as String?,
      portDestination: m['port_destination'] as String?,
      natureMarchandise: m['nature_marchandise'] as String?,
      dateArriveePn: m['date_arrivee_pn'] as String?,
      dateArriveeMatadi: m['date_arrivee_matadi'] as String?,
      datePaiement30Draft: m['date_paiement_30_draft'] as String?,
      datePaiement30Pn: m['date_paiement_30_pn'] as String?,
      datePaiement40Matadi: m['date_paiement_40_matadi'] as String?,
      montantConvenu: (m['montant_convenu'] as num?)?.toDouble(),
      statut: m['statut'] as String?,
      dateCreation: m['date_creation'] as String?,
    );
  }
}
