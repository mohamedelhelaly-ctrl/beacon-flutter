import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// DatabaseProvider is a wrapper around DatabaseHelper that exposes only
/// the necessary functions for pages to use.
/// Pages should use this provider instead of directly accessing DatabaseHelper.
/// This provides a clean separation of concerns and makes it easy to manage
/// database operations across the app.
class DatabaseProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // =====================================================
  //                     DEVICES OPERATIONS
  // =====================================================

  /// Registers a new device in the database.
  /// Parameters:
  ///   - deviceName: The unique name of the device
  ///   - uuid: The device's UUID
  ///   - isHost: Whether this device is the host
  /// Throws: Exception if device creation fails
  Future<void> registerDevice(String deviceName, String uuid, bool isHost) async {
    try {
      await _db.insertDevice(deviceName, uuid, isHost);
      notifyListeners();
    } catch (e) {
      debugPrint('Error registering device: $e');
      rethrow;
    }
  }

  /// Retrieves a device by its unique name.
  /// Parameters:
  ///   - deviceName: The device's name
  /// Returns: Map containing device data, or null if not found
  Future<Map<String, dynamic>?> fetchDeviceByName(String deviceName) async {
    try {
      return await _db.getDeviceByName(deviceName);
    } catch (e) {
      debugPrint('Error fetching device by name: $e');
      rethrow;
    }
  }

  /// Retrieves a device by its UUID.
  /// Parameters:
  ///   - uuid: The device's UUID
  /// Returns: Map containing device data, or null if not found
  Future<Map<String, dynamic>?> fetchDeviceByUUID(String uuid) async {
    try {
      return await _db.getDeviceByUUID(uuid);
    } catch (e) {
      debugPrint('Error fetching device by UUID: $e');
      rethrow;
    }
  }

  /// Retrieves all devices from the database.
  /// Returns: List of maps containing device data
  Future<List<Map<String, dynamic>>> fetchAllDevices() async {
    try {
      return await _db.getAllDevices();
    } catch (e) {
      debugPrint('Error fetching all devices: $e');
      rethrow;
    }
  }

  /// Removes a device from the database.
  /// Parameters:
  ///   - deviceName: The device's name to delete
  /// Throws: Exception if deletion fails
  Future<void> removeDevice(String deviceName) async {
    try {
      await _db.deleteDevice(deviceName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing device: $e');
      rethrow;
    }
  }

  // =====================================================
  //                     EVENTS OPERATIONS
  // =====================================================

  /// Creates a new event session hosted by a device.
  /// Parameters:
  ///   - eventName: The unique name of the event
  ///   - hostName: The device name of the host
  ///   - ssid: WiFi SSID for the event
  ///   - password: WiFi password
  ///   - ip: Host device's IP address
  /// Throws: Exception if event creation fails
  Future<void> createNewEvent(
    String eventName,
    String hostName,
    String ssid,
    String password,
    String ip,
  ) async {
    try {
      await _db.createEvent(eventName, hostName, ssid, password, ip);
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating event: $e');
      rethrow;
    }
  }

  /// Marks the current event as ended.
  /// Parameters:
  ///   - eventName: The name of the event to end
  /// Throws: Exception if operation fails
  Future<void> finishEvent(String eventName) async {
    try {
      await _db.endEvent(eventName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error finishing event: $e');
      rethrow;
    }
  }

  /// Retrieves the currently active (ongoing) event.
  /// Returns: Map containing event data, or null if no active event
  Future<Map<String, dynamic>?> fetchActiveEvent() async {
    try {
      return await _db.getActiveEvent();
    } catch (e) {
      debugPrint('Error fetching active event: $e');
      rethrow;
    }
  }

  /// Retrieves an event by its name.
  /// Parameters:
  ///   - eventName: The name of the event
  /// Returns: Map containing event data, or null if not found
  Future<Map<String, dynamic>?> fetchEventByName(String eventName) async {
    try {
      return await _db.getEventByName(eventName);
    } catch (e) {
      debugPrint('Error fetching event by name: $e');
      rethrow;
    }
  }

  /// Retrieves all events from the database.
  /// Returns: List of maps containing event data
  Future<List<Map<String, dynamic>>> fetchAllEvents() async {
    try {
      return await _db.getAllEvents();
    } catch (e) {
      debugPrint('Error fetching all events: $e');
      rethrow;
    }
  }

  /// Deletes an event from the database.
  /// Parameters:
  ///   - eventName: The name of the event to delete
  /// Throws: Exception if deletion fails
  Future<void> removeEvent(String eventName) async {
    try {
      await _db.deleteEvent(eventName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing event: $e');
      rethrow;
    }
  }

  // =====================================================
  //              EVENT CONNECTIONS OPERATIONS
  // =====================================================

  /// Records that a device joined an event.
  /// Parameters:
  ///   - eventName: The name of the event
  ///   - deviceName: The name of the device that joined
  /// Throws: Exception if operation fails
  Future<void> connectDeviceToEvent(String eventName, String deviceName) async {
    try {
      await _db.addDeviceConnection(eventName, deviceName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error connecting device to event: $e');
      rethrow;
    }
  }

  /// Updates the last activity timestamp for a device in an event.
  /// Parameters:
  ///   - eventName: The name of the event
  ///   - deviceName: The name of the device
  /// Throws: Exception if operation fails
  Future<void> updateDeviceLastSeen(String eventName, String deviceName) async {
    try {
      await _db.updateLastSeen(eventName, deviceName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating device last seen: $e');
      rethrow;
    }
  }

  /// Marks a device as disconnected from an event.
  /// Parameters:
  ///   - eventName: The name of the event
  ///   - deviceName: The name of the device to disconnect
  /// Throws: Exception if operation fails
  Future<void> disconnectDeviceFromEvent(
    String eventName,
    String deviceName,
  ) async {
    try {
      await _db.disconnectDevice(eventName, deviceName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error disconnecting device from event: $e');
      rethrow;
    }
  }

  /// Retrieves all currently connected devices in an event.
  /// Parameters:
  ///   - eventName: The name of the event
  /// Returns: List of maps with connection details for active devices
  Future<List<Map<String, dynamic>>> fetchActiveConnections(
    String eventName,
  ) async {
    try {
      return await _db.getActiveEventConnections(eventName);
    } catch (e) {
      debugPrint('Error fetching active connections: $e');
      rethrow;
    }
  }

  /// Retrieves all devices that joined an event (including disconnected ones).
  /// Parameters:
  ///   - eventName: The name of the event
  /// Returns: List of maps with device information
  Future<List<Map<String, dynamic>>> fetchAllDevicesInEvent(
    String eventName,
  ) async {
    try {
      return await _db.getAllConnectedDevicesInEvent(eventName);
    } catch (e) {
      debugPrint('Error fetching all devices in event: $e');
      rethrow;
    }
  }

  /// Checks if a device is currently connected to an event.
  /// Parameters:
  ///   - eventName: The name of the event
  ///   - deviceName: The name of the device
  /// Returns: true if device is currently connected, false otherwise
  Future<bool> isDeviceConnected(String eventName, String deviceName) async {
    try {
      return await _db.isDeviceConnectedToEvent(eventName, deviceName);
    } catch (e) {
      debugPrint('Error checking device connection status: $e');
      rethrow;
    }
  }

  // =====================================================
  //                     LOGS OPERATIONS
  // =====================================================

  /// Adds a log entry for an event.
  /// Parameters:
  ///   - eventName: The name of the event
  ///   - deviceName: The name of the device that generated the log
  ///   - message: The log message
  /// Throws: Exception if operation fails
  Future<void> addEventLog(
    String eventName,
    String deviceName,
    String message,
  ) async {
    try {
      await _db.insertLog(eventName, deviceName, message);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding event log: $e');
      rethrow;
    }
  }

  /// Retrieves all logs for a specific event.
  /// Parameters:
  ///   - eventName: The name of the event
  /// Returns: List of maps containing log entries (newest first)
  Future<List<Map<String, dynamic>>> fetchEventLogs(String eventName) async {
    try {
      return await _db.getEventLogs(eventName);
    } catch (e) {
      debugPrint('Error fetching event logs: $e');
      rethrow;
    }
  }

  /// Retrieves all logs from a specific device.
  /// Parameters:
  ///   - deviceName: The name of the device
  /// Returns: List of maps containing log entries (newest first)
  Future<List<Map<String, dynamic>>> fetchDeviceLogs(String deviceName) async {
    try {
      return await _db.getDeviceLogs(deviceName);
    } catch (e) {
      debugPrint('Error fetching device logs: $e');
      rethrow;
    }
  }

  /// Deletes all logs for a specific event.
  /// Parameters:
  ///   - eventName: The name of the event
  /// Throws: Exception if operation fails
  Future<void> clearEventLogs(String eventName) async {
    try {
      await _db.deleteEventLogs(eventName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing event logs: $e');
      rethrow;
    }
  }

  // =====================================================
  //              SYNC OPERATIONS
  // =====================================================

  /// Completely syncs the local database with the host.
  /// Clears all existing data and repopulates with fresh data from host.
  /// Parameters:
  ///   - syncData: Map containing 'devices', 'events', 'connections', and 'logs' lists
  /// Throws: Exception if sync operation fails
  Future<void> syncDatabaseWithHost(Map<String, dynamic> syncData) async {
    try {
      await _db.clearAndRepopulateFromSync(syncData);
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing database with host: $e');
      rethrow;
    }
  }

  /// Generates a complete sync object from the current database state.
  /// Returns: Map with all devices, events, connections, and logs, or null if empty
  Future<Map<String, dynamic>?> generateFullSyncData() async {
    try {
      return await _db.buildFullSync();
    } catch (e) {
      debugPrint('Error generating full sync data: $e');
      rethrow;
    }
  }

  /// Clears all data from the database.
  /// Used for complete reset or emergency cleanup.
  /// Throws: Exception if operation fails
  Future<void> clearAllDatabaseData() async {
    try {
      await _db.clearAllData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing all database data: $e');
      rethrow;
    }
  }
}
