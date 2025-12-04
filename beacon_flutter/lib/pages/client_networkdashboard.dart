import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'chatPage.dart';
import 'debugDatabasePage.dart';
import 'profilePage.dart';
import '../services/p2p_client_service.dart';
import '../services/p2p_permissions.dart';
import '../providers/database_provider.dart';

/// ClientNetworkDashboard is the main page for connecting to P2P hosts as a client.
/// Manages BLE scanning, host discovery, P2P connection, and database synchronization.
class ClientNetworkDashboard extends StatefulWidget {
  const ClientNetworkDashboard({Key? key}) : super(key: key);

  @override
  State<ClientNetworkDashboard> createState() => _ClientNetworkDashboardState();
}

class _ClientNetworkDashboardState extends State<ClientNetworkDashboard> {
  // =====================================================
  //                     SERVICES & PROVIDERS
  // =====================================================
  late P2PClientService _clientService;
  late DatabaseProvider _dbProvider;

  // =====================================================
  //                     CLIENT STATE
  // =====================================================
  bool _isScanning = false;
  bool _isConnected = false;
  List<BleDiscoveredDevice> _discoveredDevices = [];
  String? _connectedHostName;
  String? _connectedHostIP;

  // =====================================================
  //                     DEVICE INFO
  // =====================================================
  String? _deviceUUID;
  String? _deviceName;

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
  Stream<String>? _clientMessageStream;

  @override
  void initState() {
    super.initState();
    _dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    _clientService = P2PClientService();
    _initializeClient();
  }

  /// Initializes the client dashboard by:
  /// 1. Clearing all database data
  /// 2. Requesting permissions
  /// 3. Getting device information
  /// 4. Registering the device as client
  /// 5. Initializing P2P client service
  Future<void> _initializeClient() async {
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

      // Register device as client in database
      await _dbProvider.registerDevice(_deviceUUID!, _deviceName!, false);

      // Initialize P2P client service
      await _initP2PClient();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client initialized successfully')),
        );
      }
    } catch (e) {
      debugPrint('Client initialization error: $e');
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

  /// Initializes the P2P client service and sets up message stream listener.
  /// Messages are checked for EVENT_SYNC data which triggers database synchronization.
  Future<void> _initP2PClient() async {
    try {
      await _clientService.initialize();
      debugPrint('P2P Client service initialized');

      // Listen to incoming messages
      _clientMessageStream = _clientService.messageStream();
      _clientMessageStream!.listen((message) {
        debugPrint('Client received message: $message');

        // Check if message is a sync event
        final syncData = _clientService.parseMessage(message);
        if (syncData != null) {
          _handleEventSync(syncData);
        } else {
          // Handle regular messages (for chat)
          _handleReceivedMessage(message);
        }
      });
    } catch (e) {
      debugPrint('Error initializing P2P client: $e');
      rethrow;
    }
  }

  /// Starts a BLE scan to discover available P2P hosts.
  /// Updates the UI with discovered devices.
  Future<void> _startScan() async {
    if (_isConnected) return; // Don't scan if already connected

    setState(() => _isScanning = true);
    _discoveredDevices.clear();

    try {
      await _clientService.startScan((devices) {
        if (mounted) {
          setState(() => _discoveredDevices = devices);
          debugPrint('Discovered ${devices.length} device(s)');
        }
      });
    } catch (e) {
      debugPrint('Scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
        setState(() => _isScanning = false);
      }
    }
  }

  /// Stops the active BLE scan.
  Future<void> _stopScan() async {
    try {
      await _clientService.stopScan();
      debugPrint('BLE scan stopped');
    } catch (e) {
      debugPrint('Stop scan error: $e');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  /// Connects to a discovered P2P host device.
  /// Updates UI state and database with connection status.
  /// Parameters:
  ///   - device: The BleDiscoveredDevice to connect to
  Future<void> _connectToHost(BleDiscoveredDevice device) async {
    try {
      await _clientService.connect(device);
      debugPrint('Client connected to ${device.deviceName}');

      if (mounted) {
        setState(() {
          _isConnected = true;
          _connectedHostName = device.deviceName;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${device.deviceName}')),
        );
      }

      // Wait for EVENT_SYNC from host
      debugPrint('Client waiting for EVENT_SYNC from host...');
    } catch (e) {
      debugPrint('Connection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connect failed: $e')),
        );
      }
    }
  }

  /// Disconnects from the currently connected host.
  Future<void> _disconnect() async {
    try {
      await _clientService.disconnect();
      debugPrint('Disconnected from host');

      if (mounted) {
        setState(() {
          _isConnected = false;
          _connectedHostName = null;
          _connectedHostIP = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnected from host')),
        );
      }
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  /// Handles incoming EVENT_SYNC messages from the host.
  /// Clears local database and repopulates with host's data to maintain consistency.
  /// Parameters:
  ///   - syncData: Map containing 'devices', 'events', 'connections', and 'logs' from host
  Future<void> _handleEventSync(Map<String, dynamic> syncData) async {
    try {
      // Sync database with host's data
      await _dbProvider.syncDatabaseWithHost(syncData);
      debugPrint('Client synced database with host');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database synced with host')),
        );
      }
    } catch (e) {
      debugPrint('Error handling event sync: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  /// Handles regular incoming messages from the host (for chat).
  /// Currently logs the message. Can be extended for chat UI integration.
  /// Parameters:
  ///   - message: The raw message string from the host
  void _handleReceivedMessage(String message) {
    try {
      debugPrint('Processing chat message: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message from host: $message')),
      );
    } catch (e) {
      debugPrint('Error handling message: $e');
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

  /// Shows a dialog with current connection information.
  void _showConnectionInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text(
          'Connection Info',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mode: Client', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text(
              'Status: ${_isConnected ? "Connected" : "Disconnected"}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Host: ${_connectedHostName ?? "N/A"}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'IP: ${_connectedHostIP ?? "N/A"}',
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

  /// Builds the list of discovered host devices.
  /// Shows connect/disconnect buttons based on connection state.
  /// Returns: ListView or empty state message
  Widget _buildDiscoveredDevicesList() {
    if (_discoveredDevices.isEmpty) {
      return Center(
        child: Text(
          _isScanning ? 'Scanning for hosts...' : 'Tap scan to find hosts',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      itemCount: _discoveredDevices.length,
      itemBuilder: (context, index) {
        final device = _discoveredDevices[index];
        final isConnectedToThis = _connectedHostName == device.deviceName && _isConnected;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Card(
            color: _cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Device icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.router,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Device name and MAC address
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.deviceName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'MAC: ${device.deviceAddress}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Connection button or status icon
                  if (isConnectedToThis)
                    Icon(
                      Icons.check_circle,
                      color: _accentGreen,
                      size: 28,
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _connectToHost(device),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentRed,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'Connect',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the connection status card when client is connected to a host.
  /// Shows connected host name and provides option to disconnect.
  /// Returns: Formatted card widget
  Widget _buildConnectionStatusCard() {
    return Card(
      color: _accentGreen.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _accentGreen, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: _accentGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connected',
                    style: TextStyle(
                      color: _accentGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_connectedHostName != null)
                    Text(
                      'Host: $_connectedHostName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  if (_connectedHostIP != null)
                    Text(
                      'IP: $_connectedHostIP',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _disconnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentRed,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text(
                'Disconnect',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_isConnected) {
      _clientService.disconnect();
    }
    _clientService.dispose();
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
            Text(
              _isScanning
                  ? 'Scanning for hosts...'
                  : (_isConnected ? 'Connected to host' : 'Ready to scan'),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
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
            onPressed: _showConnectionInfoDialog,
            icon: const Icon(Icons.info_outline),
            tooltip: 'Connection Info',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),

              // Connection status card (only shown when connected)
              if (_isConnected) ...[
                _buildConnectionStatusCard(),
                const SizedBox(height: 20),
              ] else ...[
                const Text(
                  'Available Hosts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Devices list or empty state
              Expanded(
                child: _isConnected
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: _accentGreen,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Connected to $_connectedHostName',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Go to Chat to start messaging',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : _buildDiscoveredDevicesList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scan/Stop button
          FloatingActionButton(
            onPressed: _isScanning ? _stopScan : _startScan,
            backgroundColor: Colors.blueGrey[800],
            mini: true,
            child: Icon(_isScanning ? Icons.stop : Icons.refresh),
            tooltip: _isScanning ? 'Stop scanning' : 'Start scan',
          ),
          const SizedBox(height: 10),

          // Chat button
          FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    isHost: false,
                    hostService: null,
                    clientService: _clientService,
                  ),
                ),
              );
            },
            backgroundColor: _accentRed,
            child: const Icon(Icons.chat, color: Colors.white),
            tooltip: 'Chat',
          ),
        ],
      ),
    );
  }
}
