class Client {
  final String uuid;
  final int? id;
  final int sync;
  final String nom;
  final String? adresse;
  final String? telephone;
  final String? email;

  const Client({
    required this.uuid,
    this.id,
    this.sync = 0,
    required this.nom,
    this.adresse,
    this.telephone,
    this.email,
  });

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: (map['sync'] as int?) ?? 0,
      nom: map['nom'] as String,
      adresse: map['adresse'] as String?,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
    );
  }
}
