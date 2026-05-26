import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;
import 'package:uuid/uuid.dart';

import '../models/utilisateur.dart';
import '../models/client.dart';
import '../models/camion.dart';
import '../models/chauffeur_convoyeur.dart';
import '../models/conteneur.dart';
import '../models/depot_argent.dart';
import '../models/depense.dart';
import '../models/detail_conteneur.dart';
import '../models/dossier.dart';
import '../models/interchange.dart';
import '../models/scan_bl.dart';
import '../models/scan_voyage.dart';
import '../models/monnaie.dart';
import '../models/solde.dart';
import '../models/voyage.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const List<String> syncTables = [
    'utilisateurs',
    'monnaies',
    'clients',
    'dossiers',
    'conteneurs',
    'detail_conteneurs',
    'interchange',
    'depot_argent_makoso',
    'depot_argent_marina_trans',
    'depenses_makoso',
    'depenses_marina_trans',
    'camions',
    'chauffeurs_convoyeurs',
    'voyages',
    'scan_bl',
    'scan_voyage',
    'solde',
  ];

  sqflite.Database? _database;
  final Map<String, Set<String>> _tableColumnsCache = {};

  Future<void> initializeIfSupported() async {
    if (kIsWeb) {
      debugPrint('SQLite n\'est pas pris en charge sur le Web.');
      return;
    }

    await initialize();
  }

  Future<sqflite.Database> initialize() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite n\'est pas pris en charge sur le Web.');
    }

    if (_database != null) {
      return _database!;
    }

    final databasePath = await _databasePath();
    debugPrint('[AppDatabase] chemin de la base de données : $databasePath');

    if (Platform.isWindows || Platform.isLinux) {
      sqflite_ffi.sqfliteFfiInit();
      _database = await sqflite_ffi.databaseFactoryFfi.openDatabase(
        databasePath,
        options: sqflite_ffi.OpenDatabaseOptions(
          version: 1,
          onCreate: _onCreate,
          onOpen: (db) async => _ensureSchema(db),
        ),
      );

      return _database!;
    }

    _database = await sqflite.openDatabase(
      databasePath,
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async => _ensureSchema(db),
    );

    return _database!;
  }

  Future<String> _databasePath() async {
    final directory = await getApplicationSupportDirectory();
    return path.join(directory.path, 'makoso.db');
  }

  Future<void> _onCreate(sqflite.Database db, int version) async {
    await _ensureSchema(db);
  }

  Future<void> _ensureSchema(sqflite.DatabaseExecutor db) async {
    // ── Migrations: rename legacy tables ──────────────────────────────────────
    final legacyRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('depot_argent', 'depenses')",
    );
    final legacyNames = legacyRows.map((r) => r['name'] as String).toSet();
    if (legacyNames.contains('depot_argent')) {
      await db.execute('ALTER TABLE depot_argent RENAME TO depot_argent_makoso');
    }
    if (legacyNames.contains('depenses')) {
      await db.execute('ALTER TABLE depenses RENAME TO depenses_makoso');
    }
    // ──────────────────────────────────────────────────────────────────────────

    await db.execute('''
      CREATE TABLE IF NOT EXISTS utilisateurs (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        nom_complet TEXT,
        nom_utilisateur TEXT,
        mot_de_passe TEXT,
        adresse TEXT,
        telephone TEXT,
        email TEXT,
        role TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS monnaies (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        nom TEXT,
        sigle TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        nom TEXT,
        adresse TEXT,
        telephone TEXT,
        email TEXT,
        type_client TEXT
      )
    ''');
    await _ensureColumn(db, 'clients', 'type_client', 'TEXT');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS dossiers (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        client_uuid TEXT,
        numero_bl TEXT,
        port_chargement TEXT,
        port_destination TEXT,
        nature_marchandise TEXT,
        date_arrivee_pn DATE,
        date_arrivee_matadi DATE,
        date_paiement_30_draft DATE,
        date_paiement_30_pn DATE,
        date_paiement_40_matadi DATE,
        montant_convenu REAL,
        statut TEXT,
        type_bl TEXT,
        date_creation TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await _ensureColumn(db, 'dossiers', 'type_bl', 'TEXT');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS conteneurs (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        dossier_uuid TEXT,
        numero_conteneur TEXT,
        dimension TEXT,
        date_sorti_port DATE,
        nom_transporteur TEXT,
        marque_camion TEXT,
        numero_plaque TEXT,
        nom_chauffeur TEXT,
        numero_chauffeur TEXT,
        lieu_dechargement TEXT,
        date_arriver_lieu_dechargement DATE,
        date_dechargement DATE,
        date_depart_retour_port DATE,
        date_retour_port DATE
      )
    ''');

    await _ensureColumn(db, 'conteneurs', 'dimension', 'TEXT');
    await _ensureColumn(db, 'conteneurs', 'date_sorti_port', 'DATE');
    await _ensureColumn(db, 'conteneurs', 'nom_transporteur', 'TEXT');
    await _ensureColumn(db, 'conteneurs', 'marque_camion', 'TEXT');
    await _ensureColumn(db, 'conteneurs', 'numero_plaque', 'TEXT');
    await _ensureColumn(db, 'conteneurs', 'nom_chauffeur', 'TEXT');
    await _ensureColumn(db, 'conteneurs', 'numero_chauffeur', 'TEXT');
    await _ensureColumn(db, 'conteneurs', 'lieu_dechargement', 'TEXT');
    await _ensureColumn(db, 'conteneurs', 'date_arriver_lieu_dechargement', 'DATE');
    await _ensureColumn(db, 'conteneurs', 'date_dechargement', 'DATE');
    await _ensureColumn(db, 'conteneurs', 'date_depart_retour_port', 'DATE');
    await _ensureColumn(db, 'conteneurs', 'date_retour_port', 'DATE');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS detail_conteneurs (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        conteneur_uuid TEXT,
        nom_article TEXT,
        quantite REAL,
        unite_mesure TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS interchange (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        conteneur_uuid TEXT,
        scan BLOB,
        page INTEGER,
        nom_fichier TEXT
      )
    ''');

    await _ensureColumn(db, 'interchange', 'page', 'INTEGER');
    await _ensureColumn(db, 'interchange', 'nom_fichier', 'TEXT');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS scan_bl (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        dossier_uuid TEXT,
        scan BLOB,
        page INTEGER,
        nom_fichier TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS depot_argent_makoso (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        monnaie_uuid TEXT,
        montant REAL,
        libelle TEXT,
        observation TEXT,
        date_paiement DATE,
        source_uuid TEXT,
        agent TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS depot_argent_marina_trans (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        monnaie_uuid TEXT,
        montant REAL,
        libelle TEXT,
        observation TEXT,
        date_paiement DATE,
        source_uuid TEXT,
        agent TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS depenses_makoso (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        montant REAL,
        libelle TEXT,
        observation TEXT,
        date DATE,
        valide INTEGER,
        date_validation DATE,
        validateur_uuid TEXT,
        monnaie_uuid TEXT,
        deja_executer INTEGER DEFAULT 0,
        dossier_uuid TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS depenses_marina_trans (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        montant REAL,
        libelle TEXT,
        observation TEXT,
        date DATE,
        valide INTEGER,
        date_validation DATE,
        validateur_uuid TEXT,
        monnaie_uuid TEXT,
        type_depense TEXT,
        origine_uuid TEXT,
        deja_executer INTEGER DEFAULT 0
      )
    ''');

    await _ensureColumn(db, 'depenses_marina_trans', 'type_depense', 'TEXT');
    await _ensureColumn(db, 'depenses_marina_trans', 'origine_uuid', 'TEXT');
    await _ensureColumn(db, 'depenses_makoso', 'deja_executer', 'INTEGER DEFAULT 0');
    await _ensureColumn(db, 'depenses_makoso', 'dossier_uuid', 'TEXT');
    await _ensureColumn(db, 'depenses_marina_trans', 'deja_executer', 'INTEGER DEFAULT 0');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS camions (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        marque TEXT,
        plaque TEXT,
        modele TEXT,
        capacite TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS chauffeurs_convoyeurs (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        nom TEXT,
        telephone TEXT,
        adresse TEXT,
        date_engagement DATE,
        fonction TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS voyages (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        numero_voyage TEXT,
        date_voyage TEXT,
        lieu_depart TEXT,
        lieu_destination TEXT,
        montant_convenu REAL,
        monnaie_uuid TEXT,
        statut TEXT,
        camion_uuid TEXT,
        chauffeur_uuid TEXT,
        convoyeur_uuid TEXT,
        client_uuid TEXT,
        valide INTEGER DEFAULT 0
      )
    ''');
    await _ensureColumn(db, 'voyages', 'client_uuid', 'TEXT');
    await _ensureColumn(db, 'voyages', 'valide', 'INTEGER DEFAULT 0');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS scan_voyage (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        voyage_uuid TEXT,
        scan BLOB,
        page INTEGER,
        nom_fichier TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS solde (
        uuid TEXT PRIMARY KEY,
        id INTEGER,
        sync INTEGER DEFAULT 0,
        monnaie_uuid TEXT,
        montant FLOAT,
        date_cloture DATE,
        nom_company TEXT
      )
    ''');
    // await _ensureColumn(db, 'solde', 'monnaie_uuid', 'TEXT');
    // await _ensureColumn(db, 'solde', 'montant', 'FLOAT');
    // await _ensureColumn(db, 'solde', 'date_cloture', 'DATE');
    // await _ensureColumn(db, 'solde', 'nom_company', 'TEXT');

    await _seedAdminUser(db);
  }

  Future<void> _ensureColumn(
    sqflite.DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  // ── Password utilities ──────────────────────────────────────────────────────

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPassword(String password, String salt) {
    final combined = utf8.encode('$password$salt');
    return sha256.convert(combined).toString();
  }

  String _encodePassword(String plainText) {
    final salt = _generateSalt();
    return '${_hashPassword(plainText, salt)}:$salt';
  }

  bool _verifyPassword(String plainText, String encoded) {
    final colonIdx = encoded.indexOf(':');
    if (colonIdx < 0) return false;
    final hash = encoded.substring(0, colonIdx);
    final salt = encoded.substring(colonIdx + 1);
    return _hashPassword(plainText, salt) == hash;
  }

  // ── Write helpers ───────────────────────────────────────────────────────────

  /// Insert avec id = MAX(ABS(id))+1 et sync forcé à 0.
  Future<int> smartInsert(String table, Map<String, dynamic> values) async {
    final db = await initialize();
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(ABS(id)), 0) + 1 AS next_id FROM "$table"',
    );
    final nextId = result.first['next_id'] as int;
    final row = Map<String, dynamic>.from(values);
    row['id'] = nextId;
    row['sync'] = 0;
    return db.insert(table, row);
  }

  /// Update avec sync = -sync si sync > 0.
  Future<int> smartUpdate(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await initialize();
    final row = Map<String, dynamic>.from(values)..remove('sync');
    final setClauses =
        row.keys.map((k) => '"$k" = ?').toList()
          ..add('sync = CASE WHEN sync > 0 THEN -sync ELSE sync END');
    var sql = 'UPDATE "$table" SET ${setClauses.join(', ')}';
    if (where != null) sql += ' WHERE $where';
    return db.rawUpdate(sql, [...row.values, ...(whereArgs ?? [])]);
  }

  /// Select en excluant les enregistrements soft-deletés (id < 0).
  Future<List<Map<String, Object?>>> smartQuery(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await initialize();
    final activeWhere = where != null ? '(id > 0) AND ($where)' : 'id > 0';
    return db.query(
      table,
      columns: columns,
      where: activeWhere,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  /// Soft-delete : id = -id (si id > 0), sync = -sync (si sync > 0).
  Future<int> smartDelete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await initialize();
    var sql = 'UPDATE "$table" SET '
        'id = CASE WHEN id > 0 THEN -id ELSE id END, '
        'sync = CASE WHEN sync > 0 THEN -sync ELSE sync END';
    if (where != null) sql += ' WHERE $where';
    return db.rawUpdate(sql, whereArgs ?? []);
  }

  Future<List<Map<String, Object>>> getSyncTableStates() async {
    final db = await initialize();
    final states = <Map<String, Object>>[];

    for (final table in syncTables) {
      final result = await db.rawQuery(
        'SELECT COALESCE(MAX(ABS(sync)), 0) AS max_sync FROM "$table"',
      );
      final maxSync = ((result.first['max_sync'] as num?) ?? 0).toInt();
      states.add({
        'table_name': table,
        'sync': maxSync,
      });
    }

    return states;
  }

  Future<List<Map<String, Object?>>> getPendingSyncRecords(String table) async {
    final db = await initialize();
    final rows = await db.rawQuery(
      '''
      SELECT *
      FROM "$table"
      WHERE sync = 0
         OR (id > 0 AND sync < 0)
         OR id < 0
      ORDER BY
        CASE
          WHEN sync = 0 THEN 0
          WHEN id > 0 AND sync < 0 THEN 1
          WHEN id < 0 THEN 2
          ELSE 3
        END,
        ABS(COALESCE(id, 0)) ASC,
        uuid ASC
      ''',
    );
    return rows.map((row) => Map<String, Object?>.from(row)).toList();
  }

  Future<void> upsertSyncRecord(String table, Map<String, dynamic> record) async {
    final db = await initialize();
    final sanitized = await _sanitizeSyncRecord(table, record);
    if (sanitized.isEmpty) {
      return;
    }
    await db.insert(
      table,
      sanitized,
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<int> updateSyncRecordIfMatches(
    String table,
    Map<String, dynamic> record, {
    required int expectedSync,
  }) async {
    final db = await initialize();
    final sanitized = await _sanitizeSyncRecord(table, record);
    final uuid = sanitized.remove('uuid')?.toString();
    if (uuid == null || uuid.isEmpty || sanitized.isEmpty) {
      return 0;
    }

    final setClauses = sanitized.keys.map((key) => '"$key" = ?').join(', ');
    return db.rawUpdate(
      'UPDATE "$table" SET $setClauses WHERE uuid = ? AND ABS(sync) = ?',
      [...sanitized.values, uuid, expectedSync],
    );
  }

  Future<int> deleteSyncRecordIfMatches(
    String table, {
    required int expectedId,
    required int expectedSync,
    String? uuid,
  }) async {
    final db = await initialize();
    final whereParts = <String>[
      'ABS(id) = ?',
      'ABS(sync) = ?',
    ];
    final whereArgs = <Object?>[expectedId, expectedSync];

    if (uuid != null && uuid.isNotEmpty) {
      whereParts.add('uuid = ?');
      whereArgs.add(uuid);
    }

    return db.delete(
      table,
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
    );
  }

  Future<int> updateSyncValue(
    String table, {
    required String uuid,
    required int newSync,
  }) async {
    final db = await initialize();
    return db.update(
      table,
      {'sync': newSync},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<int> hardDeleteByUuid(String table, String uuid) async {
    final db = await initialize();
    return db.delete(table, where: 'uuid = ?', whereArgs: [uuid]);
  }

  Future<Map<String, Object?>?> getRawRecordByUuid(String table, String uuid) async {
    final db = await initialize();
    final rows = await db.query(
      table,
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, Object?>.from(rows.first);
  }

  Future<Map<String, Object?>> _sanitizeSyncRecord(
    String table,
    Map<String, dynamic> record,
  ) async {
    final allowedColumns = await _getTableColumns(table);
    final sanitized = <String, Object?>{};

    for (final entry in record.entries) {
      final key = entry.key;
      if (!allowedColumns.contains(key)) {
        continue;
      }
      sanitized[key] = _normalizeSyncValue(entry.value);
    }

    return sanitized;
  }

  Future<Set<String>> _getTableColumns(String table) async {
    final cached = _tableColumnsCache[table];
    if (cached != null) {
      return cached;
    }

    final db = await initialize();
    final rows = await db.rawQuery('PRAGMA table_info("$table")');
    final columns = rows
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();
    _tableColumnsCache[table] = columns;
    return columns;
  }

  Object? _normalizeSyncValue(Object? value) {
    if (value is bool) {
      return value ? 1 : 0;
    }
    if (value is Uint8List) {
      return value;
    }
    if (value is List || value is Map) {
      return jsonEncode(value);
    }
    return value;
  }

  // ── Seed ────────────────────────────────────────────────────────────────────

  Future<void> _seedAdminUser(sqflite.DatabaseExecutor db) async {
    final rows = await db.query(
      'utilisateurs',
      where: 'id > 0 AND nom_utilisateur = ?',
      whereArgs: ['admin'],
      limit: 1,
    );

    if (rows.isEmpty) {
      final idResult = await db.rawQuery(
        'SELECT COALESCE(MAX(ABS(id)), 0) + 1 AS next_id FROM utilisateurs',
      );
      final nextId = idResult.first['next_id'] as int;
      await db.insert('utilisateurs', {
        'uuid': const Uuid().v4(),
        'id': nextId,
        'sync': 0,
        'nom_complet': 'Administrateur',
        'nom_utilisateur': 'admin',
        'mot_de_passe': _encodePassword('Luap@25'),
        'role': 'admin',
      });
    }
  }

  // ── Authentication ──────────────────────────────────────────────────────────

  Future<Utilisateur?> authenticate(
    String nomUtilisateur,
    String motDePasse,
  ) async {
    final rows = await smartQuery(
      'utilisateurs',
      where: 'nom_utilisateur = ?',
      whereArgs: [nomUtilisateur],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final user = Utilisateur.fromMap(rows.first);
    return _verifyPassword(motDePasse, user.motDePasse) ? user : null;
  }

  Future<bool> verifyUserPassword(
    String nomUtilisateur,
    String motDePasse,
  ) async {
    final rows = await smartQuery(
      'utilisateurs',
      where: 'nom_utilisateur = ?',
      whereArgs: [nomUtilisateur],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final user = Utilisateur.fromMap(rows.first);
    return _verifyPassword(motDePasse, user.motDePasse);
  }

  Future<void> updatePassword(String uuid, String newPassword) async {
    await smartUpdate(
      'utilisateurs',
      {'mot_de_passe': _encodePassword(newPassword)},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // ── Utilisateurs CRUD ─────────────────────────────────────────────────────

  Future<List<Utilisateur>> getAllUtilisateurs() async {
    final rows = await smartQuery(
      'utilisateurs',
      orderBy: 'nom_complet ASC',
    );
    return rows.map(Utilisateur.fromMap).toList();
  }

  Future<void> createUtilisateur({
    required String nomUtilisateur,
    String? nomComplet,
    String plainPassword = '12345',
    String? adresse,
    String? telephone,
    String? email,
    String? role,
  }) async {
    await smartInsert('utilisateurs', {
      'uuid': const Uuid().v4(),
      'nom_complet': nomComplet,
      'nom_utilisateur': nomUtilisateur,
      'mot_de_passe': _encodePassword(plainPassword),
      'adresse': adresse,
      'telephone': telephone,
      'email': email,
      'role': role,
    });
  }

  Future<void> updateUtilisateurData({
    required String uuid,
    String? nomComplet,
    required String nomUtilisateur,
    String? plainPassword,
    String? adresse,
    String? telephone,
    String? email,
    String? role,
  }) async {
    final updates = <String, dynamic>{
      'nom_complet': nomComplet,
      'nom_utilisateur': nomUtilisateur,
      'adresse': adresse,
      'telephone': telephone,
      'email': email,
      'role': role,
    };
    if (plainPassword != null && plainPassword.isNotEmpty) {
      updates['mot_de_passe'] = _encodePassword(plainPassword);
    }
    await smartUpdate(
      'utilisateurs',
      updates,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> deleteUtilisateur(String uuid) async {
    await smartDelete(
      'utilisateurs',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // ── Clients CRUD ─────────────────────────────────────────────────────────────────

  Future<List<Client>> getAllClients() async {
    final rows = await smartQuery('clients', orderBy: 'nom ASC');
    return rows.map(Client.fromMap).toList();
  }

  Future<List<Client>> getClientsByType(String typeClient) async {
    final rows = await smartQuery(
      'clients',
      where: 'type_client = ?',
      whereArgs: [typeClient],
      orderBy: 'nom ASC',
    );
    return rows.map(Client.fromMap).toList();
  }

  Future<void> createClient({
    required String nom,
    String? adresse,
    String? telephone,
    String? email,
    String? typeClient,
  }) async {
    await smartInsert('clients', {
      'uuid': const Uuid().v4(),
      'nom': nom,
      'adresse': adresse,
      'telephone': telephone,
      'email': email,
      'type_client': typeClient,
    });
  }

  Future<void> updateClient({
    required String uuid,
    required String nom,
    String? adresse,
    String? telephone,
    String? email,
    String? typeClient,
  }) async {
    await smartUpdate(
      'clients',
      {'nom': nom, 'adresse': adresse, 'telephone': telephone, 'email': email, 'type_client': typeClient},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> deleteClient(String uuid) async {
    await smartDelete('clients', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── Camions CRUD ─────────────────────────────────────────────────────────────────

  Future<List<Camion>> getAllCamions() async {
    final rows = await smartQuery('camions', orderBy: 'marque ASC');
    return rows.map(Camion.fromMap).toList();
  }

  Future<void> createCamion({
    String? marque,
    String? plaque,
    String? modele,
    String? capacite,
  }) async {
    await smartInsert('camions', {
      'uuid': const Uuid().v4(),
      'marque': marque,
      'plaque': plaque,
      'modele': modele,
      'capacite': capacite,
    });
  }

  Future<void> updateCamion({
    required String uuid,
    String? marque,
    String? plaque,
    String? modele,
    String? capacite,
  }) async {
    await smartUpdate(
      'camions',
      {'marque': marque, 'plaque': plaque, 'modele': modele, 'capacite': capacite},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> deleteCamion(String uuid) async {
    await smartDelete('camions', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── Chauffeurs / Convoyeurs CRUD ───────────────────────────────────────

  Future<List<ChauffeurConvoyeur>> getAllChauffeursConvoyeurs() async {
    final rows = await smartQuery('chauffeurs_convoyeurs', orderBy: 'nom ASC');
    return rows.map(ChauffeurConvoyeur.fromMap).toList();
  }

  Future<void> createChauffeurConvoyeur({
    required String nom,
    String? telephone,
    String? adresse,
    String? dateEngagement,
    String? fonction,
  }) async {
    await smartInsert('chauffeurs_convoyeurs', {
      'uuid': const Uuid().v4(),
      'nom': nom,
      'telephone': telephone,
      'adresse': adresse,
      'date_engagement': dateEngagement,
      'fonction': fonction,
    });
  }

  Future<void> updateChauffeurConvoyeur({
    required String uuid,
    required String nom,
    String? telephone,
    String? adresse,
    String? dateEngagement,
    String? fonction,
  }) async {
    await smartUpdate(
      'chauffeurs_convoyeurs',
      {
        'nom': nom,
        'telephone': telephone,
        'adresse': adresse,
        'date_engagement': dateEngagement,
        'fonction': fonction,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> deleteChauffeurConvoyeur(String uuid) async {
    await smartDelete('chauffeurs_convoyeurs', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── Dossiers CRUD ─────────────────────────────────────────────────────────

  Future<List<Dossier>> getAllDossiers() async {
    final rows = await smartQuery('dossiers', orderBy: 'date_creation DESC');
    return rows.map(Dossier.fromMap).toList();
  }

  Future<void> createDossier({
    String? clientUuid,
    String? numeroBl,
    String? portChargement,
    String? portDestination,
    String? natureMarchandise,
    String? dateArriveePn,
    String? dateArriveeMatadi,
    String? datePaiement30Draft,
    String? datePaiement30Pn,
    String? datePaiement40Matadi,
    double? montantConvenu,
    String? statut,
    String? typeBl,
  }) async {
    await smartInsert('dossiers', {
      'uuid': const Uuid().v4(),
      'client_uuid': clientUuid,
      'numero_bl': numeroBl,
      'port_chargement': portChargement,
      'port_destination': portDestination,
      'nature_marchandise': natureMarchandise,
      'date_arrivee_pn': dateArriveePn,
      'date_arrivee_matadi': dateArriveeMatadi,
      'date_paiement_30_draft': datePaiement30Draft,
      'date_paiement_30_pn': datePaiement30Pn,
      'date_paiement_40_matadi': datePaiement40Matadi,
      'montant_convenu': montantConvenu,
      'statut': statut,
      'type_bl': typeBl,
    });
  }

  Future<void> updateDossier({
    required String uuid,
    String? clientUuid,
    String? numeroBl,
    String? portChargement,
    String? portDestination,
    String? natureMarchandise,
    String? dateArriveePn,
    String? dateArriveeMatadi,
    String? datePaiement30Draft,
    String? datePaiement30Pn,
    String? datePaiement40Matadi,
    double? montantConvenu,
    String? statut,
    String? typeBl,
  }) async {
    await smartUpdate(
      'dossiers',
      {
        'client_uuid': clientUuid,
        'numero_bl': numeroBl,
        'port_chargement': portChargement,
        'port_destination': portDestination,
        'nature_marchandise': natureMarchandise,
        'date_arrivee_pn': dateArriveePn,
        'date_arrivee_matadi': dateArriveeMatadi,
        'date_paiement_30_draft': datePaiement30Draft,
        'date_paiement_30_pn': datePaiement30Pn,
        'date_paiement_40_matadi': datePaiement40Matadi,
        'montant_convenu': montantConvenu,
        'statut': statut,
        'type_bl': typeBl,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> deleteDossier(String uuid) async {
    await smartDelete('dossiers', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── Conteneurs CRUD ───────────────────────────────────────────────────────

  Future<List<Conteneur>> getConteneursByDossier(String dossierUuid) async {
    final rows = await smartQuery(
      'conteneurs',
      where: 'dossier_uuid = ?',
      whereArgs: [dossierUuid],
      orderBy: 'numero_conteneur ASC',
    );
    return rows.map(Conteneur.fromMap).toList();
  }

  Future<Map<String, int>> getConteneurCountsByDossier() async {
    final db = await initialize();
    final rows = await db.rawQuery('''
      SELECT dossier_uuid, COUNT(*) AS total
      FROM conteneurs
      WHERE id > 0 AND dossier_uuid IS NOT NULL
      GROUP BY dossier_uuid
    ''');
    return {
      for (final row in rows)
        row['dossier_uuid'] as String: (row['total'] as num).toInt(),
    };
  }

  Future<List<Map<String, Object?>>> getAllActiveConteneurs() async {
    final db = await initialize();
    final rows = await db.rawQuery('''
      SELECT
        c.uuid, c.id, c.sync,
        c.dossier_uuid, c.numero_conteneur, c.dimension,
        c.date_sorti_port, c.nom_transporteur, c.marque_camion,
        c.numero_plaque, c.nom_chauffeur, c.numero_chauffeur,
        c.lieu_dechargement, c.date_arriver_lieu_dechargement,
        c.date_dechargement, c.date_depart_retour_port, c.date_retour_port,
        d.numero_bl, d.statut AS dossier_statut,
        cl.nom AS client_nom
      FROM conteneurs c
      LEFT JOIN dossiers d ON d.uuid = c.dossier_uuid
      LEFT JOIN clients cl ON cl.uuid = d.client_uuid
      WHERE c.id > 0
        AND d.id > 0
        AND LOWER(COALESCE(d.statut, '')) NOT IN ('clôturé', 'cloture', 'annulé', 'annule')
      ORDER BY c.numero_conteneur ASC
    ''');
    return rows.toList();
  }

  Future<List<Dossier>> getActiveDossiers() async {
    final rows = await smartQuery(
      'dossiers',
      where: "LOWER(COALESCE(statut, '')) NOT IN ('clôturé', 'cloture', 'annulé', 'annule')",
      orderBy: 'numero_bl ASC',
    );
    return rows.map(Dossier.fromMap).toList();
  }

  Future<void> createConteneur({
    required String dossierUuid,
    required String numeroConteneur,
    String? dimension,
    String? dateSortiPort,
    String? nomTransporteur,
    String? marqueCamion,
    String? numeroPlaque,
    String? nomChauffeur,
    String? numeroChauffeur,
    String? lieuDechargement,
    String? dateArriverLieuDechargement,
    String? dateDechargement,
    String? dateDepartRetourPort,
    String? dateRetourPort,
  }) async {
    await smartInsert('conteneurs', {
      'uuid': const Uuid().v4(),
      'dossier_uuid': dossierUuid,
      'numero_conteneur': numeroConteneur,
      'dimension': dimension,
      'date_sorti_port': dateSortiPort,
      'nom_transporteur': nomTransporteur,
      'marque_camion': marqueCamion,
      'numero_plaque': numeroPlaque,
      'nom_chauffeur': nomChauffeur,
      'numero_chauffeur': numeroChauffeur,
      'lieu_dechargement': lieuDechargement,
      'date_arriver_lieu_dechargement': dateArriverLieuDechargement,
      'date_dechargement': dateDechargement,
      'date_depart_retour_port': dateDepartRetourPort,
      'date_retour_port': dateRetourPort,
    });
  }

  Future<void> updateConteneur({
    required String uuid,
    String? dossierUuid,
    String? numeroConteneur,
    String? dimension,
    String? dateSortiPort,
    String? nomTransporteur,
    String? marqueCamion,
    String? numeroPlaque,
    String? nomChauffeur,
    String? numeroChauffeur,
    String? lieuDechargement,
    String? dateArriverLieuDechargement,
    String? dateDechargement,
    String? dateDepartRetourPort,
    String? dateRetourPort,
  }) async {
    await smartUpdate(
      'conteneurs',
      {
        'dossier_uuid': dossierUuid,
        'numero_conteneur': numeroConteneur,
        'dimension': dimension,
        'date_sorti_port': dateSortiPort,
        'nom_transporteur': nomTransporteur,
        'marque_camion': marqueCamion,
        'numero_plaque': numeroPlaque,
        'nom_chauffeur': nomChauffeur,
        'numero_chauffeur': numeroChauffeur,
        'lieu_dechargement': lieuDechargement,
        'date_arriver_lieu_dechargement': dateArriverLieuDechargement,
        'date_dechargement': dateDechargement,
        'date_depart_retour_port': dateDepartRetourPort,
        'date_retour_port': dateRetourPort,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> deleteConteneur(String uuid) async {
    await smartDelete('detail_conteneurs', where: 'conteneur_uuid = ?', whereArgs: [uuid]);
    await smartDelete('conteneurs', where: 'uuid = ?', whereArgs: [uuid]);
  }

  Future<List<DetailConteneur>> getDetailsByConteneur(String conteneurUuid) async {
    final rows = await smartQuery(
      'detail_conteneurs',
      where: 'conteneur_uuid = ?',
      whereArgs: [conteneurUuid],
      orderBy: 'nom_article ASC',
    );
    return rows.map(DetailConteneur.fromMap).toList();
  }

  Future<void> createDetailConteneur({
    required String conteneurUuid,
    required String nomArticle,
    double? quantite,
    String? uniteMesure,
  }) async {
    await smartInsert('detail_conteneurs', {
      'uuid': const Uuid().v4(),
      'conteneur_uuid': conteneurUuid,
      'nom_article': nomArticle,
      'quantite': quantite,
      'unite_mesure': uniteMesure,
    });
  }

  Future<void> deleteDetailConteneur(String uuid) async {
    await smartDelete('detail_conteneurs', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── Interchange CRUD ──────────────────────────────────────────────────────

  Future<List<Interchange>> getInterchangesByConteneur(String conteneurUuid) async {
    final rows = await smartQuery(
      'interchange',
      where: 'conteneur_uuid = ?',
      whereArgs: [conteneurUuid],
      orderBy: 'page ASC',
    );
    return rows.map(Interchange.fromMap).toList();
  }

  Future<Map<String, int>> getInterchangeCountsByConteneur() async {
    final db = await initialize();
    final rows = await db.rawQuery('''
      SELECT conteneur_uuid, COUNT(*) AS total
      FROM interchange
      WHERE id > 0 AND conteneur_uuid IS NOT NULL
      GROUP BY conteneur_uuid
    ''');
    return {
      for (final row in rows)
        row['conteneur_uuid'] as String: (row['total'] as num).toInt(),
    };
  }

  Future<void> createInterchange({
    required String conteneurUuid,
    required Uint8List scan,
    required String nomFichier,
    int? page,
  }) async {
    await smartInsert('interchange', {
      'uuid': const Uuid().v4(),
      'conteneur_uuid': conteneurUuid,
      'scan': scan,
      'nom_fichier': nomFichier,
      'page': page,
    });
  }

  Future<void> deleteInterchange(String uuid) async {
    await smartDelete('interchange', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── Scan BL CRUD ──────────────────────────────────────────────────────────

  Future<List<ScanBl>> getScanBlByDossier(String dossierUuid) async {
    final rows = await smartQuery(
      'scan_bl',
      where: 'dossier_uuid = ?',
      whereArgs: [dossierUuid],
      orderBy: 'page ASC',
    );
    return rows.map(ScanBl.fromMap).toList();
  }

  Future<void> createScanBl({
    required String dossierUuid,
    required Uint8List scan,
    required String nomFichier,
    int? page,
  }) async {
    await smartInsert('scan_bl', {
      'uuid': const Uuid().v4(),
      'dossier_uuid': dossierUuid,
      'scan': scan,
      'nom_fichier': nomFichier,
      'page': page,
    });
  }

  Future<void> deleteScanBl(String uuid) async {
    await smartDelete('scan_bl', where: 'uuid = ?', whereArgs: [uuid]);
  }

  void _appendDepotArgentFilters(
    List<String> whereClauses,
    List<Object?> args, {
    String? search,
    List<String>? sourceStatuses,
  }) {
    final normalizedSearch = search?.trim().toLowerCase();
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      final like = '%$normalizedSearch%';
      whereClauses.add('''
        (
          LOWER(COALESCE(da.libelle, '')) LIKE ?
          OR LOWER(COALESCE(da.observation, '')) LIKE ?
          OR LOWER(COALESCE(da.agent, '')) LIKE ?
          OR LOWER(COALESCE(v.numero_voyage, ds.numero_bl, '')) LIKE ?
          OR LOWER(COALESCE(v.statut, ds.statut, '')) LIKE ?
          OR CAST(COALESCE(da.montant, 0) AS TEXT) LIKE ?
        )
      ''');
      args.addAll([like, like, like, like, like, like]);
    }

    if (sourceStatuses != null && sourceStatuses.isNotEmpty) {
      final placeholders = sourceStatuses.map((_) => '?').join(', ');
      whereClauses.add("LOWER(COALESCE(v.statut, ds.statut, '')) IN ($placeholders)");
      args.addAll(sourceStatuses.map((status) => status.toLowerCase()));
    }
  }

  Future<bool> _depotArgentDuplicateExists({
    required String table,
    required String monnaieUuid,
    required double montant,
    required String libelle,
    required String sourceUuid,
    String? datePaiement,
    String? excludeUuid,
  }) async {
    final db = await initialize();
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM $table
      WHERE id > 0
        AND monnaie_uuid = ?
        AND libelle = ?
        AND source_uuid = ?
        AND COALESCE(date_paiement, '') = ?
        AND ABS(COALESCE(montant, 0) - ?) < 0.000001
        ${excludeUuid != null ? 'AND uuid <> ?' : ''}
      ''',
      [
        monnaieUuid,
        libelle,
        sourceUuid,
        datePaiement ?? '',
        montant,
        if (excludeUuid != null) excludeUuid,
      ],
    );
    return ((rows.first['total'] as num?) ?? 0) > 0;
  }

  // ── Dépôt argent CRUD ─────────────────────────────────────────────────────

  Future<List<DepotSourceOption>> getDepotSourceOptions(
    String libelle, {
    String? includeSourceUuid,
  }) async {
    final db = await initialize();
    final isVoyage = libelle == 'Voyage Camion' || libelle == 'Voyage camion' || libelle == 'Retour Camion avec Charge';
    final table = isVoyage ? 'voyages' : 'dossiers';
    final labelColumn = isVoyage ? 'numero_voyage' : 'numero_bl';

    final excludedStatuses = isVoyage
        ? <String>['annulé', 'annule', 'terminé', 'termine']
        : <String>['annulé', 'annule', 'terminé', 'termine', 'clôturé', 'cloturé', 'clôture', 'cloture'];

    final placeholders = excludedStatuses.map((_) => '?').join(', ');
    var sql = '''
      SELECT uuid, $labelColumn AS label, statut
      FROM $table
      WHERE id > 0
        AND (
          statut IS NULL
          OR LOWER(statut) NOT IN ($placeholders)
    ''';

    final args = <Object?>[...excludedStatuses];
    if (includeSourceUuid != null && includeSourceUuid.isNotEmpty) {
      sql += ' OR uuid = ?';
      args.add(includeSourceUuid);
    }
    sql += ' ) ORDER BY $labelColumn ASC';

    final rows = await db.rawQuery(sql, args);
    return rows
        .map(
          (row) => DepotSourceOption(
            uuid: row['uuid'] as String,
            label: (row['label'] as String?) ?? '-',
            statut: row['statut'] as String?,
          ),
        )
        .toList();
  }

  Future<List<DepotArgentRecord>> getDepotArgentRecords({
    required String table,
    String? search,
    List<String>? sourceStatuses,
    int? limit = 250,
    int offset = 0,
  }) async {
    final db = await initialize();
    final whereClauses = <String>['da.id > 0'];
    final args = <Object?>[];
    _appendDepotArgentFilters(whereClauses, args, search: search, sourceStatuses: sourceStatuses);

    var sql = '''
      SELECT
        da.*, 
        m.nom AS monnaie_nom,
        m.sigle AS monnaie_sigle,
        CASE WHEN da.libelle = 'Voyage camion' THEN v.numero_voyage ELSE ds.numero_bl END AS source_label,
        COALESCE(v.statut, ds.statut) AS source_statut
      FROM $table da
      LEFT JOIN monnaies m ON m.uuid = da.monnaie_uuid AND m.id > 0
      LEFT JOIN voyages v ON v.uuid = da.source_uuid AND v.id > 0
      LEFT JOIN dossiers ds ON ds.uuid = da.source_uuid AND ds.id > 0
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY COALESCE(da.date_paiement, '') DESC, ABS(da.id) DESC
    ''';

    if (limit != null) {
      sql += ' LIMIT ? OFFSET ?';
      args.add(limit);
      args.add(offset);
    } else if (offset > 0) {
      sql += ' LIMIT -1 OFFSET ?';
      args.add(offset);
    }

    final rows = await db.rawQuery(sql, args);
    return rows.map(DepotArgentRecord.fromMap).toList();
  }

  Future<int> getDepotArgentCount({
    required String table,
    String? search,
    List<String>? sourceStatuses,
  }) async {
    final db = await initialize();
    final whereClauses = <String>['da.id > 0'];
    final args = <Object?>[];
    _appendDepotArgentFilters(whereClauses, args, search: search, sourceStatuses: sourceStatuses);

    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM $table da
      LEFT JOIN voyages v ON v.uuid = da.source_uuid AND v.id > 0
      LEFT JOIN dossiers ds ON ds.uuid = da.source_uuid AND ds.id > 0
      WHERE ${whereClauses.join(' AND ')}
      ''',
      args,
    );
    return ((rows.first['total'] as num?) ?? 0).toInt();
  }

  Future<void> createDepotArgent({
    required String table,
    required String monnaieUuid,
    required double montant,
    required String libelle,
    String? observation,
    String? datePaiement,
    required String sourceUuid,
    String? agent,
  }) async {
    final hasDuplicate = await _depotArgentDuplicateExists(
      table: table,
      monnaieUuid: monnaieUuid,
      montant: montant,
      libelle: libelle,
      sourceUuid: sourceUuid,
      datePaiement: datePaiement,
    );
    if (hasDuplicate) {
      throw StateError('Un dépôt identique existe déjà.');
    }

    await smartInsert(table, {
      'uuid': const Uuid().v4(),
      'monnaie_uuid': monnaieUuid,
      'montant': montant,
      'libelle': libelle,
      'observation': observation,
      'date_paiement': datePaiement,
      'source_uuid': sourceUuid,
      'agent': agent,
    });
  }

  Future<void> updateDepotArgent({
    required String table,
    required String uuid,
    required String monnaieUuid,
    required double montant,
    required String libelle,
    String? observation,
    String? datePaiement,
    required String sourceUuid,
    String? agent,
  }) async {
    final hasDuplicate = await _depotArgentDuplicateExists(
      table: table,
      monnaieUuid: monnaieUuid,
      montant: montant,
      libelle: libelle,
      sourceUuid: sourceUuid,
      datePaiement: datePaiement,
      excludeUuid: uuid,
    );
    if (hasDuplicate) {
      throw StateError('Un dépôt identique existe déjà.');
    }

    await smartUpdate(
      table,
      {
        'monnaie_uuid': monnaieUuid,
        'montant': montant,
        'libelle': libelle,
        'observation': observation,
        'date_paiement': datePaiement,
        'source_uuid': sourceUuid,
        'agent': agent,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> deleteDepotArgent(String uuid, {required String table}) async {
    await smartDelete(table, where: 'uuid = ?', whereArgs: [uuid]);
  }

  void _appendDepenseFilters(
    List<String> whereClauses,
    List<Object?> args, {
    String? search,
    bool? valideOnly,
  }) {
    final normalizedSearch = search?.trim().toLowerCase();
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      final like = '%$normalizedSearch%';
      whereClauses.add('''
        (
          LOWER(COALESCE(d.libelle, '')) LIKE ?
          OR LOWER(COALESCE(d.observation, '')) LIKE ?
          OR LOWER(COALESCE(d.date, '')) LIKE ?
          OR LOWER(COALESCE(m.nom, '')) LIKE ?
          OR LOWER(COALESCE(m.sigle, '')) LIKE ?
          OR CAST(COALESCE(d.montant, 0) AS TEXT) LIKE ?
        )
      ''');
      args.addAll([like, like, like, like, like, like]);
    }

    if (valideOnly != null) {
      whereClauses.add('COALESCE(d.valide, 0) = ?');
      args.add(valideOnly ? 1 : 0);
    }
  }

  Future<bool> _depenseDuplicateExists({
    required String table,
    required String monnaieUuid,
    required double montant,
    required String libelle,
    String? date,
    String? excludeUuid,
  }) async {
    final db = await initialize();
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM $table
      WHERE id > 0
        AND monnaie_uuid = ?
        AND libelle = ?
        AND COALESCE(date, '') = ?
        AND ABS(COALESCE(montant, 0) - ?) < 0.000001
        ${excludeUuid != null ? 'AND uuid <> ?' : ''}
      ''',
      [
        monnaieUuid,
        libelle,
        date ?? '',
        montant,
        if (excludeUuid != null) excludeUuid,
      ],
    );
    return ((rows.first['total'] as num?) ?? 0) > 0;
  }

  // ── Dépenses CRUD ────────────────────────────────────────────────────────

  Future<List<DepenseRecord>> getDepenses({
    required String table,
    String? search,
    bool? valideOnly,
    int? limit = 250,
    int offset = 0,
  }) async {
    final db = await initialize();
    final whereClauses = <String>['d.id > 0'];
    final args = <Object?>[];
    _appendDepenseFilters(whereClauses, args, search: search, valideOnly: valideOnly);

    var sql = '''
      SELECT
        d.*,
        m.nom AS monnaie_nom,
        m.sigle AS monnaie_sigle,
        COALESCE(u.nom_complet, u.nom_utilisateur) AS validateur_nom
      FROM $table d
      LEFT JOIN monnaies m ON m.uuid = d.monnaie_uuid AND m.id > 0
      LEFT JOIN utilisateurs u ON u.uuid = d.validateur_uuid AND u.id > 0
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY COALESCE(d.date, '') DESC, ABS(d.id) DESC
    ''';

    if (limit != null) {
      sql += ' LIMIT ? OFFSET ?';
      args.add(limit);
      args.add(offset);
    } else if (offset > 0) {
      sql += ' LIMIT -1 OFFSET ?';
      args.add(offset);
    }

    final rows = await db.rawQuery(sql, args);
    return rows.map(DepenseRecord.fromMap).toList();
  }

  Future<int> getDepenseCount({
    required String table,
    String? search,
    bool? valideOnly,
  }) async {
    final db = await initialize();
    final whereClauses = <String>['d.id > 0'];
    final args = <Object?>[];
    _appendDepenseFilters(whereClauses, args, search: search, valideOnly: valideOnly);

    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM $table d
      LEFT JOIN monnaies m ON m.uuid = d.monnaie_uuid AND m.id > 0
      WHERE ${whereClauses.join(' AND ')}
      ''',
      args,
    );
    return ((rows.first['total'] as num?) ?? 0).toInt();
  }

  Future<void> createDepense({
    required String table,
    required String monnaieUuid,
    required double montant,
    required String libelle,
    String? observation,
    String? date,
    int? valide,
    String? dateValidation,
    String? validateurUuid,
    String? typeDepense,
    String? origineUuid,
    int? dejaExecuter,
    String? dossierUuid,
  }) async {
    final hasDuplicate = await _depenseDuplicateExists(
      table: table,
      monnaieUuid: monnaieUuid,
      montant: montant,
      libelle: libelle,
      date: date,
    );
    if (hasDuplicate) {
      throw StateError('Une dépense identique existe déjà.');
    }

    final row = <String, dynamic>{
      'uuid': const Uuid().v4(),
      'montant': montant,
      'libelle': libelle,
      'observation': observation,
      'date': date,
      'valide': valide ?? 0,
      'date_validation': dateValidation,
      'validateur_uuid': validateurUuid,
      'monnaie_uuid': monnaieUuid,
      'deja_executer': dejaExecuter ?? 0,
    };
    if (table == 'depenses_marina_trans') {
      row['type_depense'] = typeDepense;
      row['origine_uuid'] = origineUuid;
    }
    if (table == 'depenses_makoso') {
      row['dossier_uuid'] = dossierUuid;
    }
    await smartInsert(table, row);
  }

  Future<void> updateDepense({
    required String table,
    required String uuid,
    required String monnaieUuid,
    required double montant,
    required String libelle,
    String? observation,
    String? date,
    int? valide,
    String? dateValidation,
    String? validateurUuid,
    String? typeDepense,
    String? origineUuid,
    int? dejaExecuter,
    String? dossierUuid,
  }) async {
    final hasDuplicate = await _depenseDuplicateExists(
      table: table,
      monnaieUuid: monnaieUuid,
      montant: montant,
      libelle: libelle,
      date: date,
      excludeUuid: uuid,
    );
    if (hasDuplicate) {
      throw StateError('Une dépense identique existe déjà.');
    }

    final row = <String, dynamic>{
      'montant': montant,
      'libelle': libelle,
      'observation': observation,
      'date': date,
      'valide': valide ?? 0,
      'date_validation': dateValidation,
      'validateur_uuid': validateurUuid,
      'monnaie_uuid': monnaieUuid,
      'deja_executer': dejaExecuter ?? 0,
    };
    if (table == 'depenses_marina_trans') {
      row['type_depense'] = typeDepense;
      row['origine_uuid'] = origineUuid;
    }
    if (table == 'depenses_makoso') {
      row['dossier_uuid'] = dossierUuid;
    }
    await smartUpdate(
      table,
      row,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> deleteDepense(String uuid, {required String table}) async {
    await smartDelete(table, where: 'uuid = ?', whereArgs: [uuid]);
  }

  /// Returns the total validated depenses per dossier_uuid for depenses_makoso.
  Future<Map<String, double>> getDepenseTotalsByDossier() async {
    final db = await initialize();
    final rows = await db.rawQuery('''
      SELECT dossier_uuid, SUM(montant) AS total
      FROM depenses_makoso
      WHERE id > 0
        AND dossier_uuid IS NOT NULL
        AND valide = 1
      GROUP BY dossier_uuid
    ''');
    return {
      for (final row in rows)
        row['dossier_uuid'] as String: (row['total'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // ── Monnaies ──────────────────────────────────────────────────────────────

  Future<List<Monnaie>> getAllMonnaies() async {
    final rows = await smartQuery('monnaies', orderBy: 'nom ASC');
    return rows.map(Monnaie.fromMap).toList();
  }

  // ── Voyages CRUD ──────────────────────────────────────────────────────────

  Future<List<Voyage>> getAllVoyages() async {
    final rows = await smartQuery('voyages', orderBy: 'date_voyage DESC');
    return rows.map(Voyage.fromMap).toList();
  }

  Future<void> createVoyage({
    String? numeroVoyage,
    String? dateVoyage,
    String? lieuDepart,
    String? lieuDestination,
    double? montantConvenu,
    String? monnaieUuid,
    String? statut,
    String? camionUuid,
    String? chauffeurUuid,
    String? convoyeurUuid,
    String? clientUuid,
    int? valide,
  }) async {
    await smartInsert('voyages', {
      'uuid': const Uuid().v4(),
      'numero_voyage': numeroVoyage,
      'date_voyage': dateVoyage,
      'lieu_depart': lieuDepart,
      'lieu_destination': lieuDestination,
      'montant_convenu': montantConvenu,
      'monnaie_uuid': monnaieUuid,
      'statut': statut,
      'camion_uuid': camionUuid,
      'chauffeur_uuid': chauffeurUuid,
      'convoyeur_uuid': convoyeurUuid,
      'client_uuid': clientUuid,
      'valide': valide ?? 0,
    });
  }

  Future<void> updateVoyage({
    required String uuid,
    String? numeroVoyage,
    String? dateVoyage,
    String? lieuDepart,
    String? lieuDestination,
    double? montantConvenu,
    String? monnaieUuid,
    String? statut,
    String? camionUuid,
    String? chauffeurUuid,
    String? convoyeurUuid,
    String? clientUuid,
    int? valide,
  }) async {
    await smartUpdate(
      'voyages',
      {
        'numero_voyage': numeroVoyage,
        'date_voyage': dateVoyage,
        'lieu_depart': lieuDepart,
        'lieu_destination': lieuDestination,
        'montant_convenu': montantConvenu,
        'monnaie_uuid': monnaieUuid,
        'statut': statut,
        'camion_uuid': camionUuid,
        'chauffeur_uuid': chauffeurUuid,
        'convoyeur_uuid': convoyeurUuid,
        'client_uuid': clientUuid,
        if (valide != null) 'valide': valide,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<String> getNextVoyageNumber() async {
    final db = await initialize();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM voyages WHERE id > 0 AND valide = 1',
    );
    final count = (result.first['cnt'] as int?) ?? 0;
    final next = count + 1;
    return 'V-${next.toString().padLeft(3, '0')}';
  }

  Future<void> validateVoyage(String uuid, String numeroVoyage) async {
    final db = await initialize();
    await db.rawUpdate(
      'UPDATE voyages SET valide = 1, numero_voyage = ?, sync = CASE WHEN sync > 0 THEN -sync ELSE sync END WHERE uuid = ?',
      [numeroVoyage, uuid],
    );
  }

  Future<List<ScanVoyage>> getScanVoyageByVoyage(String voyageUuid) async {
    final rows = await smartQuery(
      'scan_voyage',
      where: 'voyage_uuid = ?',
      whereArgs: [voyageUuid],
      orderBy: 'page ASC',
    );
    return rows.map(ScanVoyage.fromMap).toList();
  }

  Future<void> createScanVoyage({
    required String voyageUuid,
    required Uint8List scan,
    required String nomFichier,
    int? page,
  }) async {
    await smartInsert('scan_voyage', {
      'uuid': const Uuid().v4(),
      'voyage_uuid': voyageUuid,
      'scan': scan,
      'nom_fichier': nomFichier,
      'page': page,
    });
  }

  Future<void> deleteScanVoyage(String uuid) async {
    await smartDelete('scan_voyage', where: 'uuid = ?', whereArgs: [uuid]);
  }

  Future<void> deleteVoyage(String uuid) async {
    await smartDelete('voyages', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ─── Dashboard helpers ────────────────────────────────────────────────────

  /// Returns one row per currency with totals:
  /// sigle, nom, total_depot, total_depense (validated), solde.
  /// Also returns the count of pending (non-validated) depenses as a
  /// separate single-row query via [getPendingDepenseCount].
  Future<List<Map<String, Object?>>> getDashboardFinancialRows({
    required String depotTable,
    required String depenseTable,
    String? fromDate, // exclude cloture date itself: uses date_paiement > fromDate
    String? toDate,   // inclusive: uses date_paiement <= toDate
  }) async {
    final db = await initialize();

    final dArgs = <Object?>[];
    var dCond = '';
    if (fromDate != null) { dCond += ' AND d.date_paiement > ?'; dArgs.add(fromDate); }
    if (toDate != null)   { dCond += ' AND d.date_paiement <= ?'; dArgs.add(toDate); }

    final eArgs = <Object?>[];
    var eCond = '';
    if (fromDate != null) { eCond += ' AND e.date > ?'; eArgs.add(fromDate); }
    if (toDate != null)   { eCond += ' AND e.date <= ?'; eArgs.add(toDate); }

    final rows = await db.rawQuery('''
      SELECT
        m.uuid        AS monnaie_uuid,
        m.nom         AS nom,
        m.sigle       AS sigle,
        COALESCE((
          SELECT SUM(d.montant)
          FROM $depotTable d
          WHERE d.monnaie_uuid = m.uuid AND d.id > 0$dCond
        ), 0) AS total_depot,
        COALESCE((
          SELECT SUM(e.montant)
          FROM $depenseTable e
          WHERE e.monnaie_uuid = m.uuid AND e.id > 0
            AND e.valide = 1$eCond
        ), 0) AS total_depense
      FROM monnaies m
      WHERE m.id > 0
        AND m.uuid IN (
          SELECT DISTINCT monnaie_uuid FROM $depotTable WHERE monnaie_uuid IS NOT NULL AND id > 0
          UNION
          SELECT DISTINCT monnaie_uuid FROM $depenseTable WHERE monnaie_uuid IS NOT NULL AND id > 0
        )
      ORDER BY m.nom ASC
    ''', [...dArgs, ...eArgs]);
    return rows.toList();
  }

  Future<int> getPendingDepenseCount({required String table}) async {
    final db = await initialize();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $table WHERE valide = 0 OR valide IS NULL',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<Map<String, int>> getDashboardVoyageStats() async {
    final db = await initialize();
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN statut = 'En cours' THEN 1 ELSE 0 END) AS en_cours,
        SUM(CASE WHEN statut = 'En attente' THEN 1 ELSE 0 END) AS en_attente
      FROM voyages
    ''');
    final row = rows.first;
    return {
      'total': (row['total'] as int?) ?? 0,
      'en_cours': (row['en_cours'] as int?) ?? 0,
      'en_attente': (row['en_attente'] as int?) ?? 0,
    };
  }

  /// Dossiers where at least one payment date is set, is past today,
  /// and the dossier is not yet clôturé or annulé.
  Future<List<Map<String, Object?>>> getDossiersEnRetard() async {
    final db = await initialize();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery('''
      SELECT
        dos.uuid,
        dos.numero_bl,
        dos.statut,
        dos.date_paiement_30_draft,
        dos.date_paiement_30_pn,
        dos.date_paiement_40_matadi,
        dos.date_creation,
        c.nom AS client_nom
      FROM dossiers dos
      LEFT JOIN clients c ON c.uuid = dos.client_uuid
      WHERE LOWER(COALESCE(dos.statut, '')) NOT IN ('clôturé', 'cloture', 'annulé', 'annule')
        AND (
          (dos.date_paiement_30_draft IS NOT NULL AND dos.date_paiement_30_draft < ?)
          OR (dos.date_paiement_30_pn IS NOT NULL AND dos.date_paiement_30_pn < ?)
          OR (dos.date_paiement_40_matadi IS NOT NULL AND dos.date_paiement_40_matadi < ?)
        )
      ORDER BY
        MIN(dos.date_paiement_30_draft, dos.date_paiement_30_pn, dos.date_paiement_40_matadi) ASC
    ''', [today, today, today]);
    return rows.toList();
  }

  /// Dossiers dont les paiements sont en souffrance selon trois conditions :
  /// 1. Statut 'en cours' sans paiement 30% draft suffisant.
  /// 2. Arrivée PN enregistrée sans paiement 30% PN suffisant.
  /// 3. Arrivée Matadi enregistrée sans paiement 40% Matadi suffisant.
  Future<List<Map<String, Object?>>> getDossiersSouffrancePaiement() async {
    final db = await initialize();
    final rows = await db.rawQuery('''
      SELECT DISTINCT
        d.uuid,
        d.numero_bl,
        d.statut,
        d.montant_convenu,
        d.date_arrivee_pn,
        d.date_arrivee_matadi,
        d.date_creation,
        c.nom AS client_nom,
        CASE WHEN (
          LOWER(COALESCE(d.statut, '')) = 'en cours'
          AND COALESCE((
            SELECT SUM(da.montant) FROM depot_argent_makoso da
            WHERE da.source_uuid = d.uuid AND da.id > 0
              AND LOWER(TRIM(da.libelle)) IN ('paiement 30% draft', 'paiement 100% du montant')
          ), 0) < COALESCE(d.montant_convenu, 0) * 0.3
        ) THEN 1 ELSE 0 END AS souffrance_draft,
        CASE WHEN (
          d.date_arrivee_pn IS NOT NULL AND d.date_arrivee_pn != ''
          AND COALESCE((
            SELECT SUM(da.montant) FROM depot_argent_makoso da
            WHERE da.source_uuid = d.uuid AND da.id > 0
              AND LOWER(TRIM(da.libelle)) IN ('paiement 30% pointe noir', 'paiement 100% du montant')
          ), 0) < COALESCE(d.montant_convenu, 0) * 0.3
        ) THEN 1 ELSE 0 END AS souffrance_pn,
        CASE WHEN (
          d.date_arrivee_matadi IS NOT NULL AND d.date_arrivee_matadi != ''
          AND COALESCE((
            SELECT SUM(da.montant) FROM depot_argent_makoso da
            WHERE da.source_uuid = d.uuid AND da.id > 0
              AND LOWER(TRIM(da.libelle)) IN ('paiement 40% matadi', 'paiement 100% du montant')
          ), 0) < COALESCE(d.montant_convenu, 0) * 0.4
        ) THEN 1 ELSE 0 END AS souffrance_matadi
      FROM dossiers d
      LEFT JOIN clients c ON c.uuid = d.client_uuid
      WHERE d.id > 0
        AND COALESCE(d.montant_convenu, 0) > 0
        AND LOWER(COALESCE(d.statut, '')) NOT IN ('clôturé', 'cloture', 'annulé', 'annule')
        AND (
          (
            LOWER(COALESCE(d.statut, '')) = 'en cours'
            AND COALESCE((
              SELECT SUM(da.montant) FROM depot_argent_makoso da
              WHERE da.source_uuid = d.uuid AND da.id > 0
                AND LOWER(TRIM(da.libelle)) IN ('paiement 30% draft', 'paiement 100% du montant')
            ), 0) < COALESCE(d.montant_convenu, 0) * 0.3
          )
          OR (
            d.date_arrivee_pn IS NOT NULL AND d.date_arrivee_pn != ''
            AND COALESCE((
              SELECT SUM(da.montant) FROM depot_argent_makoso da
              WHERE da.source_uuid = d.uuid AND da.id > 0
                AND LOWER(TRIM(da.libelle)) IN ('paiement 30% pointe noir', 'paiement 100% du montant')
            ), 0) < COALESCE(d.montant_convenu, 0) * 0.3
          )
          OR (
            d.date_arrivee_matadi IS NOT NULL AND d.date_arrivee_matadi != ''
            AND COALESCE((
              SELECT SUM(da.montant) FROM depot_argent_makoso da
              WHERE da.source_uuid = d.uuid AND da.id > 0
                AND LOWER(TRIM(da.libelle)) IN ('paiement 40% matadi', 'paiement 100% du montant')
            ), 0) < COALESCE(d.montant_convenu, 0) * 0.4
          )
        )
      ORDER BY d.date_creation DESC
    ''');
    return rows.toList();
  }

  // ─── Camions dashboard (Marina Trans) ────────────────────────────────────

  /// Returns one row per (camion × monnaie) with:
  /// camion_uuid, marque, plaque, modele, nb_voyages,
  /// monnaie_uuid, sigle, monnaie_nom,
  /// total_depot, total_depense_voyage, total_depense_panne.
  Future<List<Map<String, Object?>>> getCamionsDashboardRows({
    String? fromDate,
    String? toDate,
  }) async {
    final db = await initialize();

    final dArgs = <Object?>[];
    var dCond = '';
    if (fromDate != null) { dCond += ' AND da.date_paiement > ?'; dArgs.add(fromDate); }
    if (toDate != null)   { dCond += ' AND da.date_paiement <= ?'; dArgs.add(toDate); }

    final eArgs = <Object?>[];
    var eCond = '';
    if (fromDate != null) { eCond += ' AND dep.date > ?'; eArgs.add(fromDate); }
    if (toDate != null)   { eCond += ' AND dep.date <= ?'; eArgs.add(toDate); }

    // Args order: total_depot(dArgs), total_depense_voyage(eArgs),
    //             total_depense_retour(eArgs), total_depense_panne(eArgs)
    final allArgs = [...dArgs, ...eArgs, ...eArgs, ...eArgs];

    final rows = await db.rawQuery('''
      SELECT
        c.uuid        AS camion_uuid,
        c.marque      AS marque,
        c.plaque      AS plaque,
        c.modele      AS modele,
        (SELECT COUNT(*) FROM voyages v WHERE v.camion_uuid = c.uuid AND v.id > 0) AS nb_voyages,
        m.uuid        AS monnaie_uuid,
        m.sigle       AS sigle,
        m.nom         AS monnaie_nom,
        COALESCE((
          SELECT SUM(da.montant)
          FROM depot_argent_marina_trans da
          WHERE da.id > 0
            AND da.monnaie_uuid = m.uuid
            AND da.source_uuid IN (
              SELECT v.uuid FROM voyages v WHERE v.camion_uuid = c.uuid AND v.id > 0
            )$dCond
        ), 0) AS total_depot,
        COALESCE((
          SELECT SUM(dep.montant)
          FROM depenses_marina_trans dep
          WHERE dep.id > 0
            AND dep.valide = 1
            AND dep.monnaie_uuid = m.uuid
            AND dep.type_depense = 'Voyage Camion'
            AND dep.origine_uuid IN (
              SELECT v.uuid FROM voyages v WHERE v.camion_uuid = c.uuid AND v.id > 0
            )$eCond
        ), 0) AS total_depense_voyage,
        COALESCE((
          SELECT SUM(dep.montant)
          FROM depenses_marina_trans dep
          WHERE dep.id > 0
            AND dep.valide = 1
            AND dep.monnaie_uuid = m.uuid
            AND dep.type_depense = 'Retour Camion avec Charge'
            AND dep.origine_uuid = c.uuid$eCond
        ), 0) AS total_depense_retour,
        COALESCE((
          SELECT SUM(dep.montant)
          FROM depenses_marina_trans dep
          WHERE dep.id > 0
            AND dep.valide = 1
            AND dep.monnaie_uuid = m.uuid
            AND dep.type_depense IN ('Panne Camion', 'Entretien Camion')
            AND dep.origine_uuid = c.uuid$eCond
        ), 0) AS total_depense_panne
      FROM camions c
      CROSS JOIN monnaies m
      WHERE c.id > 0
      ORDER BY c.marque ASC, c.plaque ASC, m.sigle ASC
    ''', allArgs);
    return rows.toList();
  }

  // ── Solde CRUD ────────────────────────────────────────────────────────────

  /// Retourne tous les soldes actifs avec le nom et sigle de la monnaie,
  /// triés par date_cloture DESC, company ASC.
  Future<List<Solde>> getAllSoldes() async {
    final db = await initialize();
    final rows = await db.rawQuery('''
      SELECT s.*, m.nom AS monnaie_nom, m.sigle AS monnaie_sigle
      FROM solde s
      LEFT JOIN monnaies m ON m.uuid = s.monnaie_uuid AND m.id > 0
      WHERE s.id > 0
      ORDER BY s.nom_company ASC, s.date_cloture DESC, m.sigle ASC
    ''');
    return rows.map((r) => Solde.fromMap(Map<String, Object?>.from(r))).toList();
  }

  /// Insère un solde manuellement.
  Future<void> createSoldeManuel({
    required String monnaieUuid,
    required double montant,
    required String dateCloture,
    required String nomCompany,
  }) async {
    await smartInsert('solde', {
      'uuid': const Uuid().v4(),
      'monnaie_uuid': monnaieUuid,
      'montant': montant,
      'date_cloture': dateCloture,
      'nom_company': nomCompany,
    });
  }

  Future<void> deleteSolde(String uuid) async {
    await smartDelete('solde', where: 'uuid = ?', whereArgs: [uuid]);
  }

  /// Calcule et insère un solde de clôture pour chaque combinaison
  /// (company × monnaie) en se basant sur le dernier solde connu.
  ///
  /// Formule :  nouveau_solde = dernier_solde
  ///              + SUM(dépôt argent depuis la dernière date de clôture)
  ///              - SUM(dépenses validées depuis la dernière date de clôture)
  ///
  /// Si aucun solde antérieur n'existe pour la combinaison, toutes les lignes
  /// jusqu'à aujourd'hui sont agrégées (somme totale).
  Future<List<Solde>> calculerEtInsererSoldes() async {
    final db = await initialize();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final companies = <String, String>{
      'makoso': 'MAKOSO Services',
      'marina_trans': 'MARINA Trans',
    };

    final monnaiesRows = await db.rawQuery(
      'SELECT uuid, nom, sigle FROM monnaies WHERE id > 0 ORDER BY sigle ASC',
    );

    final inserted = <Solde>[];

    for (final entry in companies.entries) {
      final tableKey = entry.key;
      final companyLabel = entry.value;
      final depotTable = 'depot_argent_$tableKey';
      final depenseTable = 'depenses_$tableKey';

      for (final monnaieRow in monnaiesRows) {
        final monnaieUuid = monnaieRow['uuid'] as String;
        final monnaieNom = monnaieRow['nom'] as String;
        final monnaieSigle = monnaieRow['sigle'] as String?;

        // Dernier solde pour cette combinaison
        final lastRows = await db.rawQuery('''
          SELECT montant, date_cloture
          FROM solde
          WHERE id > 0
            AND nom_company = ?
            AND monnaie_uuid = ?
          ORDER BY date_cloture DESC
          LIMIT 1
        ''', [companyLabel, monnaieUuid]);

        final lastMontant = lastRows.isNotEmpty
            ? ((lastRows.first['montant'] as num?) ?? 0.0).toDouble()
            : 0.0;
        final lastDate = lastRows.isNotEmpty
            ? lastRows.first['date_cloture'] as String?
            : null;

        // Somme des dépôts depuis la dernière date (incluse)
        final depotRows = await db.rawQuery(
          lastDate != null
              ? '''
                SELECT COALESCE(SUM(montant), 0) AS total
                FROM "$depotTable"
                WHERE id > 0 AND monnaie_uuid = ? AND date_paiement > ?
              '''
              : '''
                SELECT COALESCE(SUM(montant), 0) AS total
                FROM "$depotTable"
                WHERE id > 0 AND monnaie_uuid = ?
              ''',
          lastDate != null ? [monnaieUuid, lastDate] : [monnaieUuid],
        );
        final sumDepot =
            ((depotRows.first['total'] as num?) ?? 0.0).toDouble();

        // Somme des dépenses validées depuis la dernière date (incluse)
        final depenseRows = await db.rawQuery(
          lastDate != null
              ? '''
                SELECT COALESCE(SUM(montant), 0) AS total
                FROM "$depenseTable"
                WHERE id > 0 AND monnaie_uuid = ? AND date > ? AND valide = 1
              '''
              : '''
                SELECT COALESCE(SUM(montant), 0) AS total
                FROM "$depenseTable"
                WHERE id > 0 AND monnaie_uuid = ? AND valide = 1
              ''',
          lastDate != null ? [monnaieUuid, lastDate] : [monnaieUuid],
        );
        final sumDepense =
            ((depenseRows.first['total'] as num?) ?? 0.0).toDouble();

        final nouveauMontant = lastMontant + sumDepot - sumDepense;

        final uuid = const Uuid().v4();
        await smartInsert('solde', {
          'uuid': uuid,
          'monnaie_uuid': monnaieUuid,
          'montant': nouveauMontant,
          'date_cloture': today,
          'nom_company': companyLabel,
        });

        inserted.add(Solde(
          uuid: uuid,
          monnaieUuid: monnaieUuid,
          montant: nouveauMontant,
          dateCloture: today,
          nomCompany: companyLabel,
          monnaieNom: monnaieNom,
          monnaieSigle: monnaieSigle,
        ));
      }
    }

    return inserted;
  }

  /// Returns per-monnaie totals for 'Retour Camion avec Charge':
  /// sigle, monnaie_nom, total_depot (depots with that libelle), total_depense (validated depenses with that type).
  Future<List<Map<String, Object?>>> getRetourCamionDashboard({
    String? fromDate,
    String? toDate,
  }) async {
    final db = await initialize();

    final dArgs = <Object?>[];
    var dCond = '';
    if (fromDate != null) { dCond += ' AND da.date_paiement > ?'; dArgs.add(fromDate); }
    if (toDate != null)   { dCond += ' AND da.date_paiement <= ?'; dArgs.add(toDate); }

    final eArgs = <Object?>[];
    var eCond = '';
    if (fromDate != null) { eCond += ' AND dep.date > ?'; eArgs.add(fromDate); }
    if (toDate != null)   { eCond += ' AND dep.date <= ?'; eArgs.add(toDate); }

    final rows = await db.rawQuery('''
      SELECT
        m.sigle AS sigle,
        m.nom   AS monnaie_nom,
        COALESCE((
          SELECT SUM(da.montant)
          FROM depot_argent_marina_trans da
          WHERE da.id > 0
            AND da.monnaie_uuid = m.uuid
            AND da.libelle = 'Retour Camion avec Charge'$dCond
        ), 0) AS total_depot,
        COALESCE((
          SELECT SUM(dep.montant)
          FROM depenses_marina_trans dep
          WHERE dep.id > 0
            AND dep.valide = 1
            AND dep.monnaie_uuid = m.uuid
            AND dep.type_depense = 'Retour Camion avec Charge'$eCond
        ), 0) AS total_depense
      FROM monnaies m
      WHERE m.id > 0
      ORDER BY m.sigle ASC
    ''', [...dArgs, ...eArgs]);
    return rows.toList();
  }

  // ─── Période / solde reporté ──────────────────────────────────────────────

  /// Retourne toutes les dates de clôture distinctes pour une company (ordre ASC).
  Future<List<String>> getClotureDatesForCompany(String nomCompany) async {
    final db = await initialize();
    final rows = await db.rawQuery('''
      SELECT DISTINCT date_cloture
      FROM solde
      WHERE id > 0 AND nom_company = ? AND date_cloture IS NOT NULL
      ORDER BY date_cloture ASC
    ''', [nomCompany]);
    return rows.map((r) => r['date_cloture'] as String).toList();
  }

  /// Retourne le solde reporté (dernier solde de clôture) par monnaie pour une company.
  /// Si [avantStricte] est fourni, ne prend que les clôtures dont la date < avantStricte.
  /// Si null, prend la dernière clôture toutes dates confondues.
  Future<List<Map<String, Object?>>> getSoldeReporteParMonnaie(
    String nomCompany, {
    String? avantStricte,
  }) async {
    final db = await initialize();
    final dateWhere = avantStricte != null ? 'AND date_cloture < ?' : '';
    final args = avantStricte != null ? [nomCompany, avantStricte] : [nomCompany];

    final maxRows = await db.rawQuery('''
      SELECT monnaie_uuid, MAX(date_cloture) AS max_date
      FROM solde
      WHERE id > 0 AND nom_company = ? $dateWhere
      GROUP BY monnaie_uuid
    ''', args);

    if (maxRows.isEmpty) return [];

    final results = <Map<String, Object?>>[];
    for (final mr in maxRows) {
      final monnaieUuid = mr['monnaie_uuid'] as String?;
      final maxDate = mr['max_date'] as String?;
      if (monnaieUuid == null || maxDate == null) continue;
      final soldeRows = await db.rawQuery('''
        SELECT s.monnaie_uuid, s.montant, s.date_cloture,
               m.nom AS monnaie_nom, m.sigle AS monnaie_sigle
        FROM solde s
        LEFT JOIN monnaies m ON m.uuid = s.monnaie_uuid AND m.id > 0
        WHERE s.id > 0 AND s.nom_company = ?
          AND s.monnaie_uuid = ? AND s.date_cloture = ?
        LIMIT 1
      ''', [nomCompany, monnaieUuid, maxDate]);
      results.addAll(soldeRows);
    }
    return results;
  }

  /// Rapport Makoso : totaux dépôts/dépenses par (dossier × monnaie)
  /// pour une période donnée. Retourne uniquement les combinaisons actives.
  Future<List<Map<String, Object?>>> getRapportMakosoParDossier({
    String? fromDate,
    String? toDate,
  }) async {
    final db = await initialize();

    final dArgs = <Object?>[];
    var dCond = '';
    if (fromDate != null) { dCond += ' AND da.date_paiement > ?'; dArgs.add(fromDate); }
    if (toDate != null)   { dCond += ' AND da.date_paiement <= ?'; dArgs.add(toDate); }

    final eArgs = <Object?>[];
    var eCond = '';
    if (fromDate != null) { eCond += ' AND dep.date > ?'; eArgs.add(fromDate); }
    if (toDate != null)   { eCond += ' AND dep.date <= ?'; eArgs.add(toDate); }

    // Arg order: total_depot(dArgs), total_depense(eArgs), EXISTS depot(dArgs), EXISTS depense(eArgs)
    final allArgs = [...dArgs, ...eArgs, ...dArgs, ...eArgs];

    final rows = await db.rawQuery('''
      SELECT
        d.uuid        AS dossier_uuid,
        d.numero_bl,
        d.statut,
        d.montant_convenu,
        d.date_creation,
        c.nom         AS client_nom,
        m.uuid        AS monnaie_uuid,
        m.sigle       AS monnaie_sigle,
        m.nom         AS monnaie_nom,
        COALESCE((
          SELECT SUM(da.montant)
          FROM depot_argent_makoso da
          WHERE da.source_uuid = d.uuid AND da.id > 0 AND da.monnaie_uuid = m.uuid$dCond
        ), 0) AS total_depot,
        COALESCE((
          SELECT SUM(dep.montant)
          FROM depenses_makoso dep
          WHERE dep.dossier_uuid = d.uuid AND dep.id > 0 AND dep.valide = 1
            AND dep.monnaie_uuid = m.uuid$eCond
        ), 0) AS total_depense
      FROM dossiers d
      LEFT JOIN clients c ON c.uuid = d.client_uuid
      CROSS JOIN monnaies m
      WHERE d.id > 0 AND m.id > 0
        AND (
          EXISTS (
            SELECT 1 FROM depot_argent_makoso da
            WHERE da.source_uuid = d.uuid AND da.id > 0 AND da.monnaie_uuid = m.uuid$dCond
          )
          OR EXISTS (
            SELECT 1 FROM depenses_makoso dep
            WHERE dep.dossier_uuid = d.uuid AND dep.id > 0 AND dep.valide = 1
              AND dep.monnaie_uuid = m.uuid$eCond
          )
        )
      ORDER BY d.date_creation ASC, d.numero_bl ASC, m.sigle ASC
    ''', allArgs);
    return rows.toList();
  }
}