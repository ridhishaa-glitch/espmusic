import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../screens/settings_screen.dart';

class EspBadge extends StatelessWidget {
  const EspBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isConnected = player.isEspConnected;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isConnected ? const Color(0xFF1E3A2F) : const Color(0xFF3B2D2F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConnected ? const Color(0xFFA6E3A1) : Colors.redAccent.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? const Color(0xFFA6E3A1) : Colors.redAccent,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isConnected ? 'ESP Online' : 'ESP Offline',
              style: TextStyle(
                color: isConnected ? const Color(0xFFA6E3A1) : Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
