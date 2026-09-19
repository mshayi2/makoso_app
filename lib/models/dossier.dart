class Dossier {
  final String uuid;
  final int? id;
  final int? sync;
  final String? clientUuid;
  final String? numeroBl;
  final String? portChargement;
  final String? portDestination;
  final String? natureMarchandise;
  final String? dateReceptionBl;
  final String? dateArriveePn;
  final String? dateArriveeMatadi;
  final String? datePaiement30Draft;
  final String? datePaiement30Pn;
  final String? datePaiement40Matadi;
  final double? montantConvenu;
  final String? statut;
  final String? typeBl;
  final String? nomDeclarant;
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
    this.dateReceptionBl,
    this.dateArriveePn,
    this.dateArriveeMatadi,
    this.datePaiement30Draft,
    this.datePaiement30Pn,
    this.datePaiement40Matadi,
    this.montantConvenu,
    this.statut,
    this.typeBl,
    this.nomDeclarant,
    this.dateCreation,
  });

  factory Dossier.fromMap(Map<String, Object?> m) {
    final storedTypeBl = (m['type_bl'] as String?)?.trim();
    final separatorIndex = storedTypeBl?.indexOf('|') ?? -1;
    final typeBl = separatorIndex < 0
        ? storedTypeBl
        : storedTypeBl!.substring(0, separatorIndex).trim();
    final nomDeclarant = separatorIndex < 0
        ? null
        : storedTypeBl!.substring(separatorIndex + 1).trim();

    return Dossier(
      uuid: m['uuid'] as String,
      id: m['id'] as int?,
      sync: m['sync'] as int?,
      clientUuid: m['client_uuid'] as String?,
      numeroBl: m['numero_bl'] as String?,
      portChargement: m['port_chargement'] as String?,
      portDestination: m['port_destination'] as String?,
      natureMarchandise: m['nature_marchandise'] as String?,
      dateReceptionBl: m['date_reception_bl'] as String?,
      dateArriveePn: m['date_arrivee_pn'] as String?,
      dateArriveeMatadi: m['date_arrivee_matadi'] as String?,
      datePaiement30Draft: m['date_paiement_30_draft'] as String?,
      datePaiement30Pn: m['date_paiement_30_pn'] as String?,
      datePaiement40Matadi: m['date_paiement_40_matadi'] as String?,
      montantConvenu: (m['montant_convenu'] as num?)?.toDouble(),
      statut: m['statut'] as String?,
      typeBl: typeBl == null || typeBl.isEmpty ? null : typeBl,
      nomDeclarant: nomDeclarant == null || nomDeclarant.isEmpty
          ? null
          : nomDeclarant,
      dateCreation: m['date_creation'] as String?,
    );
  }
}
