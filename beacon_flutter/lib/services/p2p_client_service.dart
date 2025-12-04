import 'dart:async';
import 'dart:convert';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';

/// P2PClientService manages Wi-Fi Direct client connections and communication.
/// Allows the device to discover, connect to, and communicate with a P2P host.
class P2PClientService {
  final FlutterP2pClient _client = FlutterP2pClient();
  bool _initialized = false;

  /// Initializes the P2P client service.
  /// Must be called before scanning or connecting to hosts.
  Future<void> initialize() async {
    if (_initialized) return;
    await _client.initialize();
    _initialized = true;
  }

  /// Starts a BLE scan to discover available P2P hosts.
  /// Parameters:
  ///   - onDevices: Callback function that receives list of discovered BLE devices
  /// Throws: Exception if scan initialization fails
  Future<void> startScan(Function(List<BleDiscoveredDevice>) onDevices) async {
    await _client.startScan(onDevices);
  }

  /// Stops the active BLE scan.
  /// Throws: Exception if stopping the scan fails
  Future<void> stopScan() async {
    await _client.stopScan();
  }

  /// Connects to a discovered P2P host device.
  /// Parameters:
  ///   - device: The BleDiscoveredDevice to connect to
  /// Throws: Exception if connection fails
  Future<void> connect(BleDiscoveredDevice device) async {
    await _client.connectWithDevice(device);
  }

  /// Disconnects from the currently connected P2P host.
  /// Throws: Exception if disconnection fails
  Future<void> disconnect() async {
    await _client.disconnect();
  }

  /// Listens for incoming text messages from the connected host.
  /// Returns: Stream of raw text messages
  Stream<String> messageStream() {
    return _client.streamReceivedTexts();
  }

  /// Sends a text message to the connected P2P host.
  /// Parameters:
  ///   - text: The message text to send
  /// Throws: Exception if sending fails
  Future<void> sendMessage(String text) async {
    await _client.broadcastText(text);
  }

  /// Parses an incoming message and extracts sync data if present.
  /// Attempts to decode the message as JSON and checks for 'type' = 'EVENT_SYNC'.
  /// Parameters:
  ///   - rawMessage: The raw message string received from the host
  /// Returns: Map containing sync data if message is an EVENT_SYNC, null otherwise
  Map<String, dynamic>? parseMessage(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage) as Map<String, dynamic>;
      if (decoded['type'] == 'EVENT_SYNC') {
        return decoded;
      }
    } catch (e) {
      // Not JSON or not a sync message, return null
    }
    return null;
  }

  /// Cleans up resources and closes the client service.
  void dispose() {
    _client.dispose();
    _initialized = false;
  }
}
