class Utilisateur {
  final String uuid;
  final int? id;
  final int sync;
  final String? nomComplet;
  final String nomUtilisateur;
  final String motDePasse;
  final String? adresse;
  final String? telephone;
  final String? email;
  final String? role;

  const Utilisateur({
    required this.uuid,
    this.id,
    this.sync = 0,
    this.nomComplet,
    required this.nomUtilisateur,
    required this.motDePasse,
    this.adresse,
    this.telephone,
    this.email,
    this.role,
  });

  factory Utilisateur.fromMap(Map<String, dynamic> map) {
    return Utilisateur(
      uuid: map['uuid'] as String,
      id: map['id'] as int?,
      sync: (map['sync'] as int?) ?? 0,
      nomComplet: map['nom_complet'] as String?,
      nomUtilisateur: map['nom_utilisateur'] as String,
      motDePasse: map['mot_de_passe'] as String,
      adresse: map['adresse'] as String?,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      role: map['role'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'id': id,
      'sync': sync,
      'nom_complet': nomComplet,
      'nom_utilisateur': nomUtilisateur,
      'mot_de_passe': motDePasse,
      'adresse': adresse,
      'telephone': telephone,
      'email': email,
      'role': role,
    };
  }
}
