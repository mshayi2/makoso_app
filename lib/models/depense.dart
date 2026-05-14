class DepenseRecord {
  final String uuid;
  final int? id;
  final int? sync;
  final double? montant;
  final String? libelle;
  final String? observation;
  final String? date;
  final int? valide;
  final String? dateValidation;
  final String? validateurUuid;
  final String? monnaieUuid;
  final String? monnaieNom;
  final String? monnaieSigle;
  final String? validateurNom;

  const DepenseRecord({
    required this.uuid,
    this.id,
    this.sync,
    this.montant,
    this.libelle,
    this.observation,
    this.date,
    this.valide,
    this.dateValidation,
    this.validateurUuid,
    this.monnaieUuid,
    this.monnaieNom,
    this.monnaieSigle,
    this.validateurNom,
  });

  int get valideValue => valide ?? 0;

  String get validationStatus => valideValue > 0 ? 'Validée' : 'En attente';

  String get monnaieLabel {
    if ((monnaieNom ?? '').isEmpty) return '-';
    if ((monnaieSigle ?? '').isEmpty) return monnaieNom!;
    return '${monnaieNom!} (${monnaieSigle!})';
  }

  factory DepenseRecord.fromMap(Map<String, Object?> map) {
    return DepenseRecord(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: map['sync'] as int?,
      montant: (map['montant'] as num?)?.toDouble(),
      libelle: map['libelle'] as String?,
      observation: map['observation'] as String?,
      date: map['date'] as String?,
      valide: (map['valide'] as num?)?.toInt(),
      dateValidation: map['date_validation'] as String?,
      validateurUuid: map['validateur_uuid'] as String?,
      monnaieUuid: map['monnaie_uuid'] as String?,
      monnaieNom: map['monnaie_nom'] as String?,
      monnaieSigle: map['monnaie_sigle'] as String?,
      validateurNom: map['validateur_nom'] as String?,
    );
  }
}