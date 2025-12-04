import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// DatabaseHelper manages all local database operations for the Beacon app.
/// Uses device_name as the primary key for devices table.
/// Uses event_name as the primary key for events table.
/// All other tables reference these using foreign keys based on names.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Returns the singleton database instance.
  /// Initializes the database on first access.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// Initializes the database by opening it from the app documents directory.
  /// Sets up encryption with a fixed password.
  Future<Database> _initDB() async {
    Directory dir = await getApplicationDocumentsDirectory();
    String dbPath = join(dir.path, "beacon_secure.db");

    return await openDatabase(
      dbPath,
      password: "12345",
      version: 1,
      onCreate: _createDB
    );
  }

  /// Creates all database tables on first initialization.
  /// Tables: devices, events, event_connections, logs.
  /// Uses device_name and event_name as primary keys instead of auto-increment IDs.
  Future _createDB(Database db, int version) async {
    await db.execute("PRAGMA foreign_keys = ON");

    // ============= DEVICES TABLE =============
    /// Stores all connected devices. Primary key is device_name.
    await db.execute('''
      CREATE TABLE devices (
        device_name TEXT PRIMARY KEY,
        device_uuid TEXT UNIQUE,
        is_host INTEGER,
        created_at TEXT
      )
    ''');

    // ============= EVENTS TABLE =============
    /// Stores event sessions. Primary key is event_name.
    /// References the host device using host_name (device_name from devices).
    await db.execute('''
      CREATE TABLE events (
        event_name TEXT PRIMARY KEY,
        host_name TEXT NOT NULL,
        ssid TEXT,
        password TEXT,
        host_ip TEXT,
        started_at TEXT,
        ended_at TEXT,
        FOREIGN KEY(host_name) REFERENCES devices(device_name)
      )
    ''');

    // ============= EVENT_CONNECTIONS TABLE =============
    /// Tracks which devices joined which events.
    /// Composite primary key: (event_name, device_name).
    await db.execute('''
      CREATE TABLE event_connections (
        event_name TEXT NOT NULL,
        device_name TEXT NOT NULL,
        joined_at TEXT,
        last_seen TEXT,
        is_current INTEGER,
        PRIMARY KEY(event_name, device_name),
        FOREIGN KEY(event_name) REFERENCES events(event_name),
        FOREIGN KEY(device_name) REFERENCES devices(device_name)
      )
    ''');

    // ============= LOGS TABLE =============
    /// Stores event activity logs. Primary key is auto-increment id.
    /// References events and devices using their names.
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_name TEXT NOT NULL,
        device_name TEXT NOT NULL,
        message TEXT,
        timestamp TEXT,
        FOREIGN KEY(event_name) REFERENCES events(event_name),
        FOREIGN KEY(device_name) REFERENCES devices(device_name)
      )
    ''');
  }

  // =====================================================
  //                     DEVICES CRUD
  // =====================================================

  /// Inserts a new device into the database.
  /// Parameters:
  ///   - deviceName: The unique name of the device
  ///   - uuid: The device's UUID
  ///   - isHost: Whether this device is the host
  /// Returns: 1 if successful, throws exception on error
  Future<int> insertDevice(String deviceName, String uuid, bool isHost) async {
    final db = await database;

    return await db.insert(
      "devices",
      {
        'device_name': deviceName,
        'device_uuid': uuid,
        'is_host': isHost ? 1 : 0,
        'created_at': DateTime.now().toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves a device by its unique name.
  /// Parameters:
  ///   - deviceName: The device's name (primary key)
  /// Returns: Map containing device data, or null if not found
  Future<Map<String, dynamic>?> getDeviceByName(String deviceName) async {
    final db = await database;
    final res = await db.query(
      "devices",
      where: "device_name = ?",
      whereArgs: [deviceName],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  /// Retrieves a device by its UUID.
  /// Parameters:
  ///   - uuid: The device's UUID
  /// Returns: Map containing device data, or null if not found
  Future<Map<String, dynamic>?> getDeviceByUUID(String uuid) async {
    final db = await database;
    final res = await db.query(
      "devices",
      where: "device_uuid = ?",
      whereArgs: [uuid],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  /// Retrieves all devices from the database.
  /// Returns: List of maps containing device data
  Future<List<Map<String, dynamic>>> getAllDevices() async {
    final db = await database;
    return await db.query("devices");
  }

  /// Deletes a device by its name.
  /// Parameters:
  ///   - deviceName: The device's name to delete
  Future<void> deleteDevice(String deviceName) async {
    final db = await database;
    await db.delete(
      "devices",
      where: "device_name = ?",
      whereArgs: [deviceName],
    );
  }

  // =====================================================
  //                     EVENTS CRUD
  // =====================================================

  /// Creates a new event session hosted by a device.
  /// Parameters:
  ///   - eventName: The unique name of the event
  ///   - hostName: The device name of the host
  ///   - ssid: WiFi SSID for the event
  ///   - password: WiFi password
  ///   - ip: Host device's IP address
  /// Returns: 1 if successful
  Future<int> createEvent(
    String eventName,
    String hostName,
    String ssid,
    String password,
    String ip,
  ) async {
    final db = await database;

    return await db.insert(
      "events",
      {
        "event_name": eventName,
        "host_name": hostName,
        "ssid": ssid,
        "password": password,
        "host_ip": ip,
        "started_at": DateTime.now().toString(),
        "ended_at": null,
      },
    );
  }

  /// Marks an event as ended by setting the ended_at timestamp.
  /// Parameters:
  ///   - eventName: The name of the event to end
  Future<void> endEvent(String eventName) async {
    final db = await database;

    await db.update(
      "events",
      {"ended_at": DateTime.now().toString()},
      where: "event_name = ?",
      whereArgs: [eventName],
    );
  }

  /// Retrieves the active (ongoing) event.
  /// Returns: Map containing event data, or null if no active event
  Future<Map<String, dynamic>?> getActiveEvent() async {
    final db = await database;

    final res = await db.query(
      "events",
      where: "ended_at IS NULL",
      limit: 1,
    );

    return res.isNotEmpty ? res.first : null;
  }

  /// Retrieves an event by its name.
  /// Parameters:
  ///   - eventName: The name of the event
  /// Returns: Map containing event data, or null if not found
  Future<Map<String, dynamic>?> getEventByName(String eventName) async {
    final db = await database;

    final res = await db.query(
      "events",
      where: "event_name = ?",
      whereArgs: [eventName],
      limit: 1,
    );

    return res.isNotEmpty ? res.first : null;
  }

  /// Retrieves all events from the database.
  /// Returns: List of maps containing event data
  Future<List<Map<String, dynamic>>> getAllEvents() async {
    final db = await database;
    return await db.query("events");
  }

  /// Deletes an event by its name.
  /// Parameters:
  ///   - eventName: The name of the event to delete
  Future<void> deleteEvent(String eventName) async {
    final db = await database;
    await db.delete(
      "events",
      where: "event_name = ?",
      whereArgs: [eventName],
    );
  }

  // =====================================================
  //              EVENT CONNECTIONS CRUD
  // =====================================================

  /// Records that a device joined an event.
  /// Parameters:
  ///   - eventName: The name of the event
  ///   - deviceName: The name of the device that joined
  /// Returns: 1 if successful
  Future<int> addDeviceConnection(String eventName, String deviceName) async {
    final db = await database;

    return await db.insert(
      "event_connections",
      {
        "event_name": eventName,
        "device_name": deviceName,
        "joined_at": DateTime.now().toString(),
        "last_seen": DateTime.now().toString(),
        "is_current": 1,
      },
    );
  }

  /// Updates the last_seen timestamp for a device in an event connection.
  /// Parameters:
  ///   - eventName: The name of the event
  ///   - deviceName: The name of the device
  Future<void> updateLastSeen(String eventName, String deviceName) async {
    final db = await database;
    await db.update(
      "event_connections",
      {"last_seen": DateTime.now().toString()},
      where: "event_name = ? AND device_name = ?",
      whereArgs: [eventName, deviceName],
    );
  }

  /// Marks a device as disconnected from an event.
  /// Parameters:
  ///   - eventName: The name of the event
  ///   - deviceName: The name of the device to disconnect
  Future<void> disconnectDevice(String eventName, String deviceName) async {
    final db = await database;
    await db.update(
      "event_connections",
      {"is_current": 0},
      where: "event_name = ? AND device_name = ?",
      whereArgs: [eventName, deviceName],
    );
  }

  /// Retrieves all currently connected devices in an event.
  /// Parameters:
  ///   - eventName: The name of the event
  /// Returns: List of maps with connection details for active devices
  Future<List<Map<String, dynamic>>> getActiveEventConnections(
    String eventName,
  ) async {
    final db = await database;

    return await db.query(
      "event_connections",
      where: "event_name = ? AND is_current = 1",
      whereArgs: [eventName],
    );
  }

  /// Retrieves all devices that joined an event (including disconnected ones).
  /// Parameters:
  ///   - eventName: The name of the event
  /// Returns: List of maps with device information for all devices in the event
  Future<List<Map<String, dynamic>>> getAllConnectedDevicesInEvent(
    String eventName,
  ) async {
    final db = await database;

    return await db.rawQuery('''
      SELECT DISTINCT devices.device_name, devices.device_uuid, devices.is_host, devices.created_at
      FROM devices
      JOIN event_connections
      ON devices.device_name = event_connections.device_name
      WHERE event_connections.event_name = ?
    ''', [eventName]);
  }

  /// Checks if a device is currently connected to an event.
  /// Parameters:
  ///   - eventName: The name of the event
  ///   - deviceName: The name of the device
  /// Returns: true if device is currently connected, false otherwise
  Future<bool> isDeviceConnectedToEvent(
    String eventName,
    String deviceName,
  ) async {
    final db = await database;

    final res = await db.query(
      "event_connections",
      where: "event_name = ? AND device_name = ? AND is_current = 1",
      whereArgs: [eventName, deviceName],
      limit: 1,
    );

    return res.isNotEmpty;
  }

  // =====================================================
  //                     LOGS CRUD
  // =====================================================

  /// Inserts a log entry for an event.
  /// Parameters:
  ///   - eventName: The name of the event
  ///   - deviceName: The name of the device that generated the log
  ///   - message: The log message
  /// Returns: The ID of the inserted log entry
  Future<int> insertLog(
    String eventName,
    String deviceName,
    String message,
  ) async {
    final db = await database;

    return await db.insert(
      "logs",
      {
        "event_name": eventName,
        "device_name": deviceName,
        "message": message,
        "timestamp": DateTime.now().toString(),
      },
    );
  }

  /// Retrieves all logs for a specific event, ordered by timestamp (newest first).
  /// Parameters:
  ///   - eventName: The name of the event
  /// Returns: List of maps containing log entries
  Future<List<Map<String, dynamic>>> getEventLogs(String eventName) async {
    final db = await database;

    return await db.query(
      "logs",
      where: "event_name = ?",
      whereArgs: [eventName],
      orderBy: "timestamp DESC",
    );
  }

  /// Retrieves all logs from a specific device.
  /// Parameters:
  ///   - deviceName: The name of the device
  /// Returns: List of maps containing log entries
  Future<List<Map<String, dynamic>>> getDeviceLogs(String deviceName) async {
    final db = await database;

    return await db.query(
      "logs",
      where: "device_name = ?",
      whereArgs: [deviceName],
      orderBy: "timestamp DESC",
    );
  }

  /// Deletes all logs for a specific event.
  /// Parameters:
  ///   - eventName: The name of the event
  Future<void> deleteEventLogs(String eventName) async {
    final db = await database;

    await db.delete(
      "logs",
      where: "event_name = ?",
      whereArgs: [eventName],
    );
  }

  // =====================================================
  //                CLEAR & SYNC UTILITIES
  // =====================================================

  /// Clears all data from all tables.
  /// Deletes in order to respect foreign key constraints.
  /// Used for client sync to clear stale data.
  Future<void> clearAllData() async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // Clear in order to respect foreign keys
        await txn.delete('logs');
        await txn.delete('event_connections');
        await txn.delete('events');
        await txn.delete('devices');
        debugPrint('All database data cleared');
      });
    } catch (e) {
      debugPrint('Error clearing database: $e');
      rethrow;
    }
  }

  /// Clears all data and repopulates with data from host sync.
  /// Ensures client has the exact same state as the host.
  /// Parameters:
  ///   - syncData: Map containing 'devices', 'events', 'connections', and 'logs' lists
  Future<void> clearAndRepopulateFromSync(Map<String, dynamic> syncData) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // Clear all tables first
        await txn.delete('logs');
        await txn.delete('event_connections');
        await txn.delete('events');
        await txn.delete('devices');
        debugPrint('Database cleared, preparing to import host data');

        // Import devices first (no foreign key dependencies)
        if (syncData['devices'] != null) {
          final devices = syncData['devices'] as List<dynamic>;
          debugPrint('Importing ${devices.length} devices from host...');
          for (final device in devices) {
            final deviceMap = device as Map<String, dynamic>;
            try {
              await txn.insert(
                "devices",
                {
                  'device_name': deviceMap['device_name'],
                  'device_uuid': deviceMap['device_uuid'],
                  'is_host': deviceMap['is_host'],
                  'created_at': deviceMap['created_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              debugPrint('Error importing device ${deviceMap['device_name']}: $e');
            }
          }
        }

        // Import events
        if (syncData['events'] != null) {
          final events = syncData['events'] as List<dynamic>;
          debugPrint('Importing ${events.length} events from host...');
          for (final event in events) {
            final eventMap = event as Map<String, dynamic>;
            try {
              await txn.insert(
                "events",
                {
                  'event_name': eventMap['event_name'],
                  'host_name': eventMap['host_name'],
                  'ssid': eventMap['ssid'],
                  'password': eventMap['password'],
                  'host_ip': eventMap['host_ip'],
                  'started_at': eventMap['started_at'],
                  'ended_at': eventMap['ended_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              debugPrint('Error importing event ${eventMap['event_name']}: $e');
            }
          }
        }

        // Import event connections
        if (syncData['connections'] != null) {
          final connections = syncData['connections'] as List<dynamic>;
          debugPrint('Importing ${connections.length} connections from host...');
          for (final conn in connections) {
            final connMap = conn as Map<String, dynamic>;
            try {
              await txn.insert(
                "event_connections",
                {
                  'event_name': connMap['event_name'],
                  'device_name': connMap['device_name'],
                  'joined_at': connMap['joined_at'],
                  'last_seen': connMap['last_seen'],
                  'is_current': connMap['is_current'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              debugPrint(
                'Error importing connection ${connMap['event_name']}-${connMap['device_name']}: $e'
              );
            }
          }
        }

        // Import logs
        if (syncData['logs'] != null) {
          final logs = syncData['logs'] as List<dynamic>;
          debugPrint('Importing ${logs.length} logs from host...');
          for (final log in logs) {
            final logMap = log as Map<String, dynamic>;
            try {
              await txn.insert(
                "logs",
                {
                  'event_name': logMap['event_name'],
                  'device_name': logMap['device_name'],
                  'message': logMap['message'],
                  'timestamp': logMap['timestamp'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              debugPrint('Error importing log: $e');
            }
          }
        }

        debugPrint('Database sync complete - now matches host');
      });
    } catch (e) {
      debugPrint('Transaction failed during sync: $e');
      rethrow;
    }
  }

  /// Builds a complete sync object from the current state of all data.
  /// Includes all devices, events, connections, and logs.
  /// Returns: Map with 'type' = 'FULL_SYNC' and data arrays, or null if no data
  Future<Map<String, dynamic>?> buildFullSync() async {
    final devices = await getAllDevices();
    final events = await getAllEvents();
    
    if (devices.isEmpty && events.isEmpty) return null;

    // Collect all connections and logs
    final allConnections = <Map<String, dynamic>>[];
    final allLogs = <Map<String, dynamic>>[];

    for (final event in events) {
      final eventName = event['event_name'] as String;
      final connections = await getActiveEventConnections(eventName);
      final logs = await getEventLogs(eventName);
      
      allConnections.addAll(connections);
      allLogs.addAll(logs);
    }

    return {
      'type': 'FULL_SYNC',
      'devices': devices,
      'events': events,
      'connections': allConnections,
      'logs': allLogs,
    };
  }

}
