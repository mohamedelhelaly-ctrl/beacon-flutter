import 'package:flutter/material.dart';
import 'host_networkdashboard.dart';
import 'client_networkdashboard.dart';
import '../services/p2p_permissions.dart';

class LandingPageUI extends StatelessWidget {
  const LandingPageUI({Key? key}) : super(key: key);

  static const Color _bgColor = Color(0xFF0F1724);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentOrange = Color(0xFFFF8A4B);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isLarge = width > 600;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTopSection(context, isLarge),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isLarge ? 520 : 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionButton(
                          context,
                          label: 'START HOSTING',
                          icon: Icons.router,
                          colorA: const Color(0xFF263244),
                          colorB: const Color(0xFF0F1724),
                          onPressed: () async {
                            final ok = await PermissionService.requestP2PPermissions();
                            if (!ok) {
                              _showPermissionError(context);
                              return;
                            }
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const HostNetworkDashboard(),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        _actionButton(
                          context,
                          label: 'JOIN COMMUNICATION',
                          icon: Icons.group_add,
                          colorA: const Color(0xFF263244),
                          colorB: const Color(0xFF0F1724),
                          onPressed: () async {
                            final ok = await PermissionService.requestP2PPermissions();
                            if (!ok) {
                              _showPermissionError(context);
                              return;
                            }
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ClientNetworkDashboard(),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Powered by Peer-to-Peer Technology',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please grant the required permissions'),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context, bool isLarge) {
    return Column(
      children: [
        Container(
          width: isLarge ? 110 : 88,
          height: isLarge ? 110 : 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF263244), Color(0xFF0F1724)],
            ),
            border: Border.all(color: Colors.white12, width: 1.5),
          ),
          child: Center(
            child: Text(
              'BEACON',
              style: TextStyle(
                color: Colors.white,
                fontSize: isLarge ? 20 : 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'BEACON',
          style: TextStyle(
            color: Colors.white,
            fontSize: isLarge ? 36 : 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Stay Connected When the Network Fails',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: isLarge ? 16 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color colorA,
    required Color colorB,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 6,
          backgroundColor: Colors.transparent,
        ).copyWith(
          backgroundColor: MaterialStateProperty.resolveWith((states) => null),
        ),
      ),
    );
  }
}