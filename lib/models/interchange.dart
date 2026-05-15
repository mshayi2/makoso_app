import 'dart:typed_data';

class Interchange {
  final String uuid;
  final int? id;
  final int? sync;
  final String? conteneurUuid;
  final Uint8List? scan;
  final int? page;
  final String? nomFichier;

  const Interchange({
    required this.uuid,
    this.id,
    this.sync,
    this.conteneurUuid,
    this.scan,
    this.page,
    this.nomFichier,
  });

  factory Interchange.fromMap(Map<String, Object?> map) {
    final scanRaw = map['scan'];
    Uint8List? scanBytes;
    if (scanRaw is Uint8List) {
      scanBytes = scanRaw;
    } else if (scanRaw is List) {
      scanBytes = Uint8List.fromList(List<int>.from(scanRaw));
    }

    return Interchange(
      uuid: map['uuid'] as String,
      id: (map['id'] as num?)?.toInt(),
      sync: (map['sync'] as num?)?.toInt(),
      conteneurUuid: map['conteneur_uuid'] as String?,
      scan: scanBytes,
      page: (map['page'] as num?)?.toInt(),
      nomFichier: map['nom_fichier'] as String?,
    );
  }
}
