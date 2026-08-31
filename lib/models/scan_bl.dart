import 'dart:convert';
import 'dart:typed_data';

Uint8List? decodeScanBlBytes(Object? value) {
  if (value is Uint8List) return value;
  if (value is List) {
    try {
      return Uint8List.fromList(value.cast<num>().map((item) => item.toInt()).toList());
    } catch (_) {
      return null;
    }
  }
  if (value is Map) return decodeScanBlBytes(value['data']);
  if (value is! String || value.trim().isEmpty) return null;

  final encoded = value.trim();
  if (RegExp(r'^(?:[0-9a-fA-F]{2})+$').hasMatch(encoded)) {
    return Uint8List.fromList([
      for (var index = 0; index < encoded.length; index += 2)
        int.parse(encoded.substring(index, index + 2), radix: 16),
    ]);
  }

  try {
    final decodedJson = jsonDecode(encoded);
    final bytes = decodeScanBlBytes(decodedJson);
    if (bytes != null) return bytes;
  } catch (_) {}

  try {
    final payload = encoded.contains(',') && encoded.startsWith('data:')
        ? encoded.substring(encoded.indexOf(',') + 1)
        : encoded;
    return base64Decode(payload);
  } catch (_) {
    return null;
  }
}

class ScanBl {
  final String uuid;
  final int? id;
  final int? sync;
  final String? dossierUuid;
  final Uint8List? scan;
  final int? page;
  final String? nomFichier;

  const ScanBl({
    required this.uuid,
    this.id,
    this.sync,
    this.dossierUuid,
    this.scan,
    this.page,
    this.nomFichier,
  });

  factory ScanBl.fromMap(Map<String, Object?> map) {
    return ScanBl(
      uuid: map['uuid'] as String,
      id: (map['id'] as num?)?.toInt(),
      sync: (map['sync'] as num?)?.toInt(),
      dossierUuid: map['dossier_uuid'] as String?,
      scan: decodeScanBlBytes(map['scan']),
      page: (map['page'] as num?)?.toInt(),
      nomFichier: map['nom_fichier'] as String?,
    );
  }
}
