import 'dart:async';
import 'dart:convert';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';

/// P2PHostService manages Wi-Fi Direct hosting and client connections.
/// Allows the device to create a hotspot and broadcast data to connected clients.
class P2PHostService {
  final FlutterP2pHost _host = FlutterP2pHost();
  bool _initialized = false;

  /// Initializes the P2P host service.
  /// Must be called before creating groups or sending messages.
  Future<void> initialize() async {
    if (_initialized) return;
    await _host.initialize();
    _initialized = true;
  }

  /// Creates a Wi-Fi Direct hotspot group and starts advertising.
  /// Returns: HotspotHostState containing group information
  /// Throws: Exception if group creation fails
  Future<HotspotHostState> createGroup() async {
    return await _host.createGroup(advertise: true);
  }

  /// Listens for changes in connected client list.
  /// Returns: Stream of P2pClientInfo lists
  Stream<List<P2pClientInfo>> clientStream() {
    return _host.streamClientList();
  }

  /// Listens for incoming text messages from any connected client.
  /// Returns: Stream of raw text messages
  Stream<String> messageStream() {
    return _host.streamReceivedTexts();
  }

  /// Sends a text message to all connected clients.
  /// Parameters:
  ///   - text: The message text to broadcast
  /// Throws: Exception if broadcast fails
  Future<void> sendMessage(String text) async {
    await _host.broadcastText(text);
  }

  /// Sends event sync data (as JSON) to all connected clients.
  /// Parameters:
  ///   - syncData: Map containing event, devices, connections, and logs data
  /// Throws: Exception if encoding or broadcast fails
  Future<void> sendEventSync(Map<String, dynamic> syncData) async {
    try {
      final jsonStr = jsonEncode(syncData);
      await _host.broadcastText(jsonStr);
    } catch (e) {
      rethrow;
    }
  }

  /// Cleans up resources and closes the host service.
  void dispose() {
    _host.dispose();
    _initialized = false;
  }
}
