import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'chatPage.dart';
import 'debugDatabasePage.dart';
import 'profilePage.dart';
import '../services/p2p_host_service.dart';
import '../services/p2p_permissions.dart';
import '../providers/database_provider.dart';

/// HostNetworkDashboard is the main page for hosting P2P connections.
/// Manages Wi-Fi Direct group creation, client connections, and database synchronization.
class HostNetworkDashboard extends StatefulWidget {
  const HostNetworkDashboard({Key? key}) : super(key: key);

  @override
  State<HostNetworkDashboard> createState() => _HostNetworkDashboardState();
}

class _HostNetworkDashboardState extends State<HostNetworkDashboard> {
  // =====================================================
  //                     SERVICES & PROVIDERS
  // =====================================================
  late P2PHostService _hostService;
  late DatabaseProvider _dbProvider;

  // =====================================================
  //                     HOST STATE
  // =====================================================
  String? _hotspotSSID;
  String? _hotspotPassword;
  String? _hostIP;
  List<P2pClientInfo> _connectedClients = [];
  Set<String> _lastSyncedClientIds = {};

  // =====================================================
  //                     DEVICE INFO
  // =====================================================
  String? _deviceUUID;
  String? _deviceName;
  String? _activeEventName;

  // =====================================================
  //                     UI STYLING
  // =====================================================
  static const Color _bgColor = Color(0xFF0F1724);
  static const Color _cardColor = Color(0xFF16202B);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentGreen = Color(0xFF10B981);

  // =====================================================
  //                     STREAMS
  // =====================================================
  Stream<List<P2pClientInfo>>? _clientListStream;
  Stream<String>? _hostMessageStream;

  @override
  void initState() {
    super.initState();
    _dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    _hostService = P2PHostService();
    _initializeHost();
  }

  /// Initializes the host dashboard by:
  /// 1. Clearing all database data
  /// 2. Requesting permissions
  /// 3. Getting device information
  /// 4. Registering the device as host
  /// 5. Creating a P2P group
  Future<void> _initializeHost() async {
    try {
      // Clear database for fresh start
      await _dbProvider.clearAllDatabaseData();

      // Request required permissions
      final permissionsGranted = await PermissionService.requestP2PPermissions();
      if (!permissionsGranted) {
        _showErrorDialog('Required permissions not granted');
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // Get device information
      await _initializeDeviceInfo();
      if (_deviceUUID == null || _deviceName == null) {
        _showErrorDialog('Failed to get device information');
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // Register device as host in database
      await _dbProvider.registerDevice(_deviceUUID!, _deviceName!, true);

      // Initialize and start P2P host
      await _startP2PHost();

      // Listen to P2P events
      _listenToClientConnections();
      _listenToIncomingMessages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Host initialized successfully')),
        );
      }
    } catch (e) {
      debugPrint('Host initialization error: $e');
      _showErrorDialog('Initialization failed: $e');
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Retrieves device information from DeviceInfoPlugin.
  /// Sets _deviceUUID and _deviceName from Android device info.
  /// Falls back to default values if retrieval fails.
  Future<void> _initializeDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceUUID = androidInfo.id;
        _deviceName = androidInfo.model;
        debugPrint('Device info - UUID: $_deviceUUID, Name: $_deviceName');
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
      // Use fallback values
      _deviceUUID = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      _deviceName = 'Unknown Device';
    }
  }

  /// Initializes and starts the P2P host service.
  /// Creates a Wi-Fi Direct group and creates a new event in the database.
  Future<void> _startP2PHost() async {
    try {
      // Initialize P2P host service
      await _hostService.initialize();
      debugPrint('P2P Host service initialized');

      // Create Wi-Fi Direct group
      final groupState = await _hostService.createGroup();
      setState(() {
        _hotspotSSID = groupState.ssid;
        _hotspotPassword = groupState.preSharedKey;
        _hostIP = groupState.hostIpAddress;
      });
      debugPrint(
        'Wi-Fi Direct group created - SSID: $_hotspotSSID, IP: $_hostIP'
      );

      // Create event in database
      final eventName = 'Event Created by $_deviceName at ${DateTime.now()}';
      await _dbProvider.createNewEvent(
        eventName,
        _deviceName!,
        _hotspotSSID ?? 'Unknown',
        _hotspotPassword ?? 'Unknown',
        _hostIP ?? 'Unknown',
      );
      await _dbProvider.addEventLog(
            _activeEventName!,
            _deviceName!,
            'Device $_deviceName created the event: $eventName',
          );
      setState(() => _activeEventName = eventName);
      debugPrint('Event created in database: $eventName');
    } catch (e) {
      debugPrint('Error starting P2P host: $e');
      rethrow;
    }
  }

  /// Listens to client connection changes.
  /// Updates the UI and database when clients connect/disconnect.
  /// Broadcasts database sync to newly connected clients.
  void _listenToClientConnections() {
    _clientListStream = _hostService.clientStream();
    _clientListStream!.listen((clients) async {
      if (!mounted) return;

      setState(() => _connectedClients = clients);
      debugPrint('Clients connected: ${clients.length}');

      // Update database with current connections
      await _updateConnectedClientsInDatabase(clients);

      // Check if new clients joined
      final currentClientIds = clients.map((c) => c.id).toSet();
      final hasNewClient = currentClientIds.length > _lastSyncedClientIds.length;

      // Broadcast database to all connected clients
      if (hasNewClient) {
        await _broadcastSyncDataToClients();
        _lastSyncedClientIds = currentClientIds;
        debugPrint('New client detected, broadcasted sync data');
      }
    });
  }

  /// Listens to incoming messages from connected clients.
  /// Parses and displays received messages.
  void _listenToIncomingMessages() {
    _hostMessageStream = _hostService.messageStream();
    _hostMessageStream!.listen((message) {
      debugPrint('Host received message: $message');
      _handleReceivedMessage(message);
    });
  }

  /// Handles incoming messages from clients.
  /// Currently logs the message for debugging.
  /// Can be extended to handle different message types.
  /// Parameters:
  ///   - message: The raw message string from the client
  void _handleReceivedMessage(String message) {
    try {
      // Future: Parse message type and handle accordingly
      debugPrint('Processing message: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message from client: $message')),
      );
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }

  /// Updates the database with the current list of connected clients.
  /// Registers new clients as devices and adds event connections.
  /// Removes devices that have disconnected.
  /// Parameters:
  ///   - connectedClients: List of currently connected P2P clients
  Future<void> _updateConnectedClientsInDatabase(
    List<P2pClientInfo> connectedClients,
  ) async {
    if (_activeEventName == null) return;

    try {
      // Get current connected devices in event
      final existingConnections =
          await _dbProvider.fetchActiveConnections(_activeEventName!);
      final existingDeviceNames =
          existingConnections.map((c) => c['device_name'] as String).toSet();

      // Process each connected client
      for (final client in connectedClients) {
        // Check if client device already exists in database
        final existingDevice = await _dbProvider.fetchDeviceByUUID(client.id);

        String deviceName;
        if (existingDevice == null) {
          // Register new client as device
          await _dbProvider.registerDevice(client.id, client.username, false);
          deviceName = client.id;
          debugPrint('Registered new client device: $deviceName');
        } else {
          deviceName = existingDevice['device_name'] as String;
        }

        // Add connection if not already connected
        if (!existingDeviceNames.contains(deviceName)) {
          await _dbProvider.connectDeviceToEvent(_activeEventName!, deviceName);
          existingDeviceNames.add(deviceName);
          debugPrint('Connected device to event: $deviceName');

          // Log the connection
          await _dbProvider.addEventLog(
            _activeEventName!,
            _deviceName!,
            'Device $deviceName joined the event',
          );
        } else {
          // Update last seen timestamp for existing connection
          await _dbProvider.updateDeviceLastSeen(_activeEventName!, deviceName);
        }
      }

      // Detect and remove disconnected devices
      final connectedDeviceNames = connectedClients.map((c) => c.id).toSet();
      final disconnectedDevices = <String>[];

      for (final deviceName in existingDeviceNames) {
        if (!connectedDeviceNames.contains(deviceName)) {
          disconnectedDevices.add(deviceName);
        }
      }

      // Remove disconnected devices from database
      for (final deviceName in disconnectedDevices) {
        try {
          await _dbProvider.disconnectDeviceFromEvent(
            _activeEventName!,
            deviceName,
          );
          await _dbProvider.removeDevice(deviceName);
          debugPrint('Removed disconnected device: $deviceName');

          // Log the disconnection
          await _dbProvider.addEventLog(
            _activeEventName!,
            _deviceName!,
            'Device $deviceName left the event',
          );
        } catch (e) {
          debugPrint('Error removing device $deviceName: $e');
        }
      }
    } catch (e) {
      debugPrint('Error updating connected clients: $e');
    }
  }

  /// Broadcasts the complete database state to all connected clients.
  /// Sends sync data as JSON via P2P.
  Future<void> _broadcastSyncDataToClients() async {
    if (_connectedClients.isEmpty || _hostService == null) return;

    try {
      final syncData = await _dbProvider.generateFullSyncData();
      if (syncData != null) {
        await _hostService.sendEventSync(syncData);
        debugPrint('Broadcasted sync data to ${_connectedClients.length} clients');
      }
    } catch (e) {
      debugPrint('Error broadcasting sync data: $e');
    }
  }

  /// Shows an error dialog with the provided message.
  /// Parameters:
  ///   - message: The error message to display
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: _accentRed)),
          ),
        ],
      ),
    );
  }

  /// Builds an info row widget with label and value.
  /// Parameters:
  ///   - label: The label text (left side)
  ///   - value: The value text (right side)
  /// Returns: Formatted row widget
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          SelectableText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog with Wi-Fi Direct group information.
  /// Displays SSID, Password, and Host IP address.
  void _showWiFiInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text(
          'WiFi Direct Info',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mode: Host (Group Owner)',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              'SSID: ${_hotspotSSID ?? "N/A"}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Password: ${_hotspotPassword ?? "N/A"}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Host IP: ${_hostIP ?? "N/A"}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _accentRed)),
          ),
        ],
      ),
    );
  }

  /// Builds the connected devices list widget.
  /// Shows all currently connected P2P clients.
  /// Returns: ListView or empty state message
  Widget _buildConnectedDevicesList() {
    if (_connectedClients.isEmpty) {
      return Center(
        child: Text(
          'Waiting for devices to connect...',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      itemCount: _connectedClients.length,
      itemBuilder: (context, index) {
        final client = _connectedClients[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Card(
            color: _cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      client.isHost ? Icons.router : Icons.phone_android,
                      color: _accentGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.username,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          client.isHost ? 'Host' : 'Client',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle,
                    color: _accentGreen,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the Wi-Fi Direct group status card.
  /// Displays SSID, Password, and Host IP.
  /// Returns: Formatted card widget
  Widget _buildGroupStatusCard() {
    return Card(
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _accentGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.wifi, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Group Status',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hotspotSSID ?? 'Initializing...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Network', _hotspotSSID ?? 'N/A'),
            _buildInfoRow('Password', _hotspotPassword ?? 'N/A'),
            _buildInfoRow('Host IP', _hostIP ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // End event when leaving the page
    if (_activeEventName != null) {
      _dbProvider.finishEvent(_activeEventName!);
    }
    _hostService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Network Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'Hosting — waiting for clients',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DebugDatabasePage()),
              );
            },
            icon: const Icon(Icons.bug_report),
            tooltip: 'Database Debug',
          ),
          IconButton(
            onPressed: _showWiFiInfoDialog,
            icon: const Icon(Icons.info_outline),
            tooltip: 'WiFi Info',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'WiFi Direct Group',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildGroupStatusCard(),
                    const SizedBox(height: 20),
                    const Text(
                      'Connected Devices',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: _buildConnectedDevicesList()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                isHost: true,
                hostService: _hostService,
              ),
            ),
          );
        },
        backgroundColor: _accentRed,
        child: const Icon(Icons.chat, color: Colors.white),
        tooltip: 'Chat',
      ),
    );
  }
}
