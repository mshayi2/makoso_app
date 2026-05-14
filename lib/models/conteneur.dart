class Conteneur {
  final String uuid;
  final int? id;
  final int? sync;
  final String? dossierUuid;
  final String? numeroConteneur;
  final String? dimension;

  const Conteneur({
    required this.uuid,
    this.id,
    this.sync,
    this.dossierUuid,
    this.numeroConteneur,
    this.dimension,
  });

  factory Conteneur.fromMap(Map<String, Object?> map) {
    return Conteneur(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: map['sync'] as int?,
      dossierUuid: map['dossier_uuid'] as String?,
      numeroConteneur: map['numero_conteneur'] as String?,
      dimension: map['dimension'] as String?,
    );
  }
}