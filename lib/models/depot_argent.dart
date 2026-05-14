class DepotArgentRecord {
  final String uuid;
  final int? id;
  final int? sync;
  final String? monnaieUuid;
  final double? montant;
  final String? libelle;
  final String? observation;
  final String? datePaiement;
  final String? sourceUuid;
  final String? agent;
  final String? monnaieNom;
  final String? monnaieSigle;
  final String? sourceLabel;
  final String? sourceStatut;

  const DepotArgentRecord({
    required this.uuid,
    this.id,
    this.sync,
    this.monnaieUuid,
    this.montant,
    this.libelle,
    this.observation,
    this.datePaiement,
    this.sourceUuid,
    this.agent,
    this.monnaieNom,
    this.monnaieSigle,
    this.sourceLabel,
    this.sourceStatut,
  });

  String get monnaieLabel {
    if ((monnaieNom ?? '').isEmpty) return '-';
    if ((monnaieSigle ?? '').isEmpty) return monnaieNom!;
    return '${monnaieNom!} (${monnaieSigle!})';
  }

  factory DepotArgentRecord.fromMap(Map<String, Object?> map) {
    return DepotArgentRecord(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: map['sync'] as int?,
      monnaieUuid: map['monnaie_uuid'] as String?,
      montant: (map['montant'] as num?)?.toDouble(),
      libelle: map['libelle'] as String?,
      observation: map['observation'] as String?,
      datePaiement: map['date_paiement'] as String?,
      sourceUuid: map['source_uuid'] as String?,
      agent: map['agent'] as String?,
      monnaieNom: map['monnaie_nom'] as String?,
      monnaieSigle: map['monnaie_sigle'] as String?,
      sourceLabel: map['source_label'] as String?,
      sourceStatut: map['source_statut'] as String?,
    );
  }
}

class DepotSourceOption {
  final String uuid;
  final String label;
  final String? statut;

  const DepotSourceOption({
    required this.uuid,
    required this.label,
    this.statut,
  });
}