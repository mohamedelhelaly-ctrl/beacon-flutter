import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/database_provider.dart';
import 'dart:math';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _bgColor = Color(0xFF0F1724);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentOrange = Color(0xFFFF8A4B);

  late String _generatedPhoneNumber;

  @override
  void initState() {
    super.initState();
    _generatedPhoneNumber = _generatePhoneNumber();
  }

  /// Generate a random phone number in format: +1 (XXX) XXX-XXXX
  String _generatePhoneNumber() {
    final random = Random();
    final areaCode = 200 + random.nextInt(800); // 200-999
    final exchange = 200 + random.nextInt(800); // 200-999
    final lineNumber = random.nextInt(10000).toString().padLeft(4, '0');
    
    return '+1 ($areaCode) $exchange-$lineNumber';
  }

  /// Fetches the first device from the database.
  /// Returns the first registered device, or null if no devices exist.
  Future<Map<String, dynamic>?> _fetchFirstDevice() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final devices = await dbProvider.fetchAllDevices();
    return devices.isNotEmpty ? devices.first : null;
  }

  Widget _buildProfileField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF263244), Color(0xFF1A2332)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accentRed, _accentOrange],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchFirstDevice(),
        builder: (context, snapshot) {
          String deviceName = 'Unknown Device';
          
          if (snapshot.hasData && snapshot.data != null) {
            deviceName = snapshot.data!['device_name'] as String;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Profile Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_accentRed, _accentOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white24, width: 3),
                  ),
                  child: const Icon(
                    Icons.devices,
                    color: Colors.white,
                    size: 60,
                  ),
                ),

                const SizedBox(height: 40),

                // Device Name Field
                _buildProfileField(
                  label: 'DEVICE NAME',
                  value: deviceName,
                  icon: Icons.devices_other,
                ),

                // Phone Number Field (Randomly Generated)
                _buildProfileField(
                  label: 'PHONE NUMBER',
                  value: _generatedPhoneNumber,
                  icon: Icons.phone_outlined,
                ),

                const SizedBox(height: 40),

                // Regenerate Phone Number Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _generatedPhoneNumber = _generatePhoneNumber();
                      });
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Generate New Phone Number',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: _accentRed, width: 2),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Medical Information Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Medical information feature coming soon')),
                      );
                    },
                    icon: const Icon(Icons.medical_services, color: Colors.white),
                    label: const Text(
                      'Medical Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: _accentRed, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}