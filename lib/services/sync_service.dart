import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database/app_database.dart';
import 'api_config.dart';

class SyncResult {
  final bool success;
  final bool skipped;
  final String message;
  final int pulledCount;
  final int pushedCount;
  final int deletedCount;
  final DateTime completedAt;
  final Object? error;

  const SyncResult._({
    required this.success,
    required this.skipped,
    required this.message,
    required this.pulledCount,
    required this.pushedCount,
    required this.deletedCount,
    required this.completedAt,
    this.error,
  });

  factory SyncResult.success({
    required int pulledCount,
    required int pushedCount,
    required int deletedCount,
  }) {
    return SyncResult._(
      success: true,
      skipped: false,
      message: 'Synchronisation terminée.',
      pulledCount: pulledCount,
      pushedCount: pushedCount,
      deletedCount: deletedCount,
      completedAt: DateTime.now(),
    );
  }

  factory SyncResult.failure(Object error) {
    return SyncResult._(
      success: false,
      skipped: false,
      message: 'La synchronisation a échoué.',
      pulledCount: 0,
      pushedCount: 0,
      deletedCount: 0,
      completedAt: DateTime.now(),
      error: error,
    );
  }

  factory SyncResult.skipped(String message) {
    return SyncResult._(
      success: true,
      skipped: true,
      message: message,
      pulledCount: 0,
      pushedCount: 0,
      deletedCount: 0,
      completedAt: DateTime.now(),
    );
  }
}

class SyncNotification {
  final SyncResult result;

  const SyncNotification(this.result);

  bool get hasDataChanges => result.pulledCount > 0 || result.deletedCount > 0;
}

class AppSyncService {
  AppSyncService._({http.Client? client}) : _client = client ?? http.Client();

  static final AppSyncService instance = AppSyncService._();
  static const Duration _requestTimeout = Duration(seconds: 30);

  final AppDatabase _database = AppDatabase.instance;
  final http.Client _client;
  final StreamController<SyncNotification> _notificationsController =
      StreamController<SyncNotification>.broadcast();

  bool _isRunning = false;
  DateTime? _lastCompletedAt;
  String? _lastError;

  bool get isRunning => _isRunning;
  DateTime? get lastCompletedAt => _lastCompletedAt;
  String? get lastError => _lastError;
  Stream<SyncNotification> get notifications => _notificationsController.stream;

  Future<SyncResult> synchronize() async {
    if (_isRunning) {
      final result = SyncResult.skipped('Une synchronisation est déjà en cours.');
      _emitNotification(result);
      return result;
    }

    _isRunning = true;
    try {
      final pulledCount = await _runPullPhase();
      final pushResult = await _runPushPhase();
      _lastCompletedAt = DateTime.now();
      _lastError = null;

      final result = SyncResult.success(
        pulledCount: pulledCount,
        pushedCount: pushResult.updatedCount,
        deletedCount: pushResult.deletedCount,
      );
      _emitNotification(result);
      return result;
    } catch (error, stackTrace) {
      _lastError = error.toString();
      debugPrint('[Sync] $error');
      debugPrintStack(stackTrace: stackTrace);
      final result = SyncResult.failure(error);
      _emitNotification(result);
      return result;
    } finally {
      _isRunning = false;
    }
  }

  void _emitNotification(SyncResult result) {
    _notificationsController.add(SyncNotification(result));
  }

  Future<int> _runPullPhase() async {
    final payload = {
      'tables': await _database.getSyncTableStates(),
    };
    final response = await _postJsonMap('/get_data', payload);

    var appliedChanges = 0;
    for (final table in AppDatabase.syncTables) {
      final records = response[table];
      if (records is! List) {
        continue;
      }

      for (final rawRecord in records) {
        if (rawRecord is! Map) {
          continue;
        }

        final record = Map<String, dynamic>.from(
          rawRecord.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );

        if (table == 'interchange') {
          final action = record['action']?.toString().trim() ?? '';
          if (!action.startsWith('D') && record['scan'] == null) {
            final scanBytes = await _fetchInterchangeScan(
              conteneurUuid: record['conteneur_uuid']?.toString() ?? '',
              sync: record['sync']?.toString() ?? '0',
              page: record['page']?.toString() ?? '0',
            );
            if (scanBytes != null) {
              record['scan'] = scanBytes;
            }
          }
        }

        appliedChanges += await _applyPullRecord(table, record);
      }
    }

    return appliedChanges;
  }

  Future<int> _applyPullRecord(String table, Map<String, dynamic> record) async {
    final action = record['action']?.toString().trim();
    if (action == null || action.isEmpty || action == 'I') {
      await _database.upsertSyncRecord(table, record);
      return 1;
    }

    final parts = action.split('|');
    switch (parts.first) {
      case 'U':
        if (parts.length < 2) {
          return 0;
        }
        final expectedSync = _toInt(parts[1]);
        if (expectedSync == null) {
          return 0;
        }
        return await _database.updateSyncRecordIfMatches(
          table,
          record,
          expectedSync: expectedSync,
        );
      case 'D':
        if (parts.length < 3) {
          return 0;
        }
        final expectedId = _toInt(parts[1]);
        final expectedSync = _toInt(parts[2]);
        if (expectedId == null || expectedSync == null) {
          return 0;
        }
        return _database.deleteSyncRecordIfMatches(
          table,
          expectedId: expectedId,
          expectedSync: expectedSync,
          uuid: record['uuid']?.toString(),
        );
      default:
        await _database.upsertSyncRecord(table, record);
        return 1;
    }
  }

  Future<_PushPhaseResult> _runPushPhase() async {
    var updatedCount = 0;
    var deletedCount = 0;

    for (final table in AppDatabase.syncTables) {
      if (table == 'interchange') continue; // handled separately after other tables

      final pendingRecords = await _database.getPendingSyncRecords(table);
      if (pendingRecords.isEmpty) {
        continue;
      }

      final outboundRecords = pendingRecords
          .map((record) => Map<String, Object?>.from(record))
          .toList();
      final payload = {
        'table_name': table,
        'records': outboundRecords,
      };
      debugPrint('[Sync][POST_DATA][$table] ${jsonEncode(payload)}');
      final response = await _postJsonList('/post_data', payload);
      final sentByUuid = <String, Map<String, Object?>>{
        for (var index = 0; index < pendingRecords.length; index++)
          if ((pendingRecords[index]['uuid']?.toString().isNotEmpty ?? false))
            pendingRecords[index]['uuid']!.toString(): pendingRecords[index],
      };

      for (final rawRecord in response) {
        if (rawRecord is! Map) {
          continue;
        }

        final record = Map<String, dynamic>.from(
          rawRecord.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
        final uuid = record['uuid']?.toString();
        if (uuid == null || uuid.isEmpty) {
          continue;
        }

        final sentRecord = sentByUuid[uuid];
        if (sentRecord == null) {
          continue;
        }

        final localId = _toInt(sentRecord['id']) ?? 0;
        final localSync = _toInt(sentRecord['sync']) ?? 0;
        if (localId < 0 && localSync <= 0) {
          deletedCount += await _database.hardDeleteByUuid(table, uuid);
          continue;
        }

        final newSync = _toInt(record['new_sync']);
        final shouldUpdateSync =
            localSync == 0 || (localId > 0 && localSync < 0);
        if (shouldUpdateSync && newSync != null) {
          updatedCount += await _database.updateSyncValue(
            table,
            uuid: uuid,
            newSync: newSync,
          );
        }
      }
    }

    final interchangeResult = await _runInterchangePushPhase();
    updatedCount += interchangeResult.updatedCount;
    deletedCount += interchangeResult.deletedCount;

    return _PushPhaseResult(
      updatedCount: updatedCount,
      deletedCount: deletedCount,
    );
  }
  Future<Map<String, dynamic>> _postJsonMap(
    String endpoint,
    Map<String, Object?> payload,
  ) async {
    final decoded = await _postJson(endpoint, payload);
    if (decoded is! Map) {
      throw const FormatException('Réponse JSON attendue au format objet.');
    }
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  Future<List<dynamic>> _postJsonList(
    String endpoint,
    Map<String, Object?> payload,
  ) async {
    final decoded = await _postJson(endpoint, payload);
    if (decoded is! List) {
      throw const FormatException('Réponse JSON attendue au format tableau.');
    }
    return decoded;
  }

  Future<Object?> _postJson(String endpoint, Map<String, Object?> payload) async {
    final response = await _client
        .post(
          ApiConfig.uri(endpoint),
          headers: ApiConfig.defaultHeaders,
          body: jsonEncode(payload),
        )
        .timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'HTTP ${response.statusCode} sur $endpoint: ${response.body}',
      );
    }

    if (response.body.trim().isEmpty) {
      return null;
    }

    return jsonDecode(response.body);
  }

  Future<Uint8List?> _fetchInterchangeScan({
    required String conteneurUuid,
    required String sync,
    required String page,
  }) async {
    try {
      final uri = ApiConfig.uri('/get_interchange').replace(
        queryParameters: {
          'conteneur_uuid': conteneurUuid,
          'sync': sync,
          'page': page,
        },
      );
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[Sync][GET_INTERCHANGE] HTTP ${response.statusCode}');
        return null;
      }
      return response.bodyBytes;
    } catch (e) {
      debugPrint('[Sync][GET_INTERCHANGE] Error: $e');
      return null;
    }
  }

  Future<_PushPhaseResult> _runInterchangePushPhase() async {
    var updatedCount = 0;
    var deletedCount = 0;

    final pendingRecords = await _database.getPendingSyncRecords('interchange');
    for (final sentRecord in pendingRecords) {
      final uuid = sentRecord['uuid']?.toString();
      if (uuid == null || uuid.isEmpty) continue;

      final localId = _toInt(sentRecord['id']) ?? 0;
      final localSync = _toInt(sentRecord['sync']) ?? 0;

      try {
        final request = http.MultipartRequest(
          'POST',
          ApiConfig.uri('/post_interchange'),
        )..headers['Accept'] = 'application/json';

        for (final entry in sentRecord.entries) {
          if (entry.key == 'scan') continue;
          if (entry.value != null) {
            request.fields[entry.key] = entry.value.toString();
          }
        }

        final scanValue = sentRecord['scan'];
        if (scanValue != null) {
          final scanBytes = scanValue is Uint8List
              ? scanValue
              : Uint8List.fromList(List<int>.from(scanValue as List));
          request.files.add(
            http.MultipartFile.fromBytes(
              'scan',
              scanBytes,
              filename: sentRecord['nom_fichier']?.toString() ?? 'scan',
            ),
          );
        }

        debugPrint('[Sync][POST_INTERCHANGE][$uuid]');
        final streamed = await _client.send(request).timeout(_requestTimeout);
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          debugPrint('[Sync][POST_INTERCHANGE][$uuid] HTTP ${response.statusCode}: ${response.body}');
          continue;
        }

        if (localId < 0 && localSync <= 0) {
          deletedCount += await _database.hardDeleteByUuid('interchange', uuid);
          continue;
        }

        final shouldUpdateSync = localSync == 0 || (localId > 0 && localSync < 0);
        if (shouldUpdateSync) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            final newSync = _toInt(decoded['new_sync']);
            if (newSync != null) {
              updatedCount += await _database.updateSyncValue(
                'interchange',
                uuid: uuid,
                newSync: newSync,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[Sync][POST_INTERCHANGE][$uuid] Error: $e');
      }
    }

    return _PushPhaseResult(
      updatedCount: updatedCount,
      deletedCount: deletedCount,
    );
  }

  int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}

class _PushPhaseResult {
  final int updatedCount;
  final int deletedCount;

  const _PushPhaseResult({
    required this.updatedCount,
    required this.deletedCount,
  });
}

class HttpException implements Exception {
  final String message;

  const HttpException(this.message);

  @override
  String toString() => message;
}