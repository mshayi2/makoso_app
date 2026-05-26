class Solde {
  final String uuid;
  final int? id;
  final int sync;
  final String? monnaieUuid;
  final double? montant;
  final String? dateCloture;
  final String? nomCompany;

  // Joined from monnaies
  final String? monnaieNom;
  final String? monnaieSigle;

  const Solde({
    required this.uuid,
    this.id,
    this.sync = 0,
    this.monnaieUuid,
    this.montant,
    this.dateCloture,
    this.nomCompany,
    this.monnaieNom,
    this.monnaieSigle,
  });

  String get monnaieLabel {
    if ((monnaieNom ?? '').isEmpty) return '-';
    if ((monnaieSigle ?? '').isEmpty) return monnaieNom!;
    return '${monnaieNom!} (${monnaieSigle!})';
  }

  factory Solde.fromMap(Map<String, Object?> map) {
    return Solde(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: (map['sync'] as int?) ?? 0,
      monnaieUuid: map['monnaie_uuid'] as String?,
      montant: (map['montant'] as num?)?.toDouble(),
      dateCloture: map['date_cloture'] as String?,
      nomCompany: map['nom_company'] as String?,
      monnaieNom: map['monnaie_nom'] as String?,
      monnaieSigle: map['monnaie_sigle'] as String?,
    );
  }
}
