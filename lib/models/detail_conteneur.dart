class DetailConteneur {
  final String uuid;
  final int? id;
  final int? sync;
  final String? conteneurUuid;
  final String? nomArticle;
  final double? quantite;
  final String? uniteMesure;

  const DetailConteneur({
    required this.uuid,
    this.id,
    this.sync,
    this.conteneurUuid,
    this.nomArticle,
    this.quantite,
    this.uniteMesure,
  });

  factory DetailConteneur.fromMap(Map<String, Object?> map) {
    return DetailConteneur(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: map['sync'] as int?,
      conteneurUuid: map['conteneur_uuid'] as String?,
      nomArticle: map['nom_article'] as String?,
      quantite: (map['quantite'] as num?)?.toDouble(),
      uniteMesure: map['unite_mesure'] as String?,
    );
  }
}