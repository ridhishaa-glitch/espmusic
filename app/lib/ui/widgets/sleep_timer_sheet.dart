import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';

class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SleepTimerSheet(),
    );
  }

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final int remainingSec = player.espStatus.sleepTimerSeconds;
    final bool isActive = remainingSec > 0;

    String formatRemaining(int seconds) {
      final int m = seconds ~/ 60;
      final int s = seconds % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bedtime_outlined, color: Color(0xFF89B4FA), size: 28),
              const SizedBox(width: 12),
              const Text(
                'Sleep Timer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF89B4FA).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formatRemaining(remainingSec),
                    style: const TextStyle(
                      color: Color(0xFF89B4FA),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The ESP will automatically stop audio playback after the selected duration.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildPresetButton(context, 15, player),
              _buildPresetButton(context, 30, player),
              _buildPresetButton(context, 45, player),
              _buildPresetButton(context, 60, player),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Custom minutes (e.g. 20)',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF181825),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final int? mins = int.tryParse(_customController.text);
                  if (mins != null && mins > 0) {
                    player.setSleepTimer(mins);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF89B4FA),
                  foregroundColor: const Color(0xFF11111B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                child: const Text('Set'),
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                player.cancelSleepTimer();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.timer_off_outlined, color: Colors.redAccent),
              label: const Text('Cancel Sleep Timer', style: TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetButton(BuildContext context, int minutes, PlayerProvider player) {
    return ElevatedButton(
      onPressed: () {
        player.setSleepTimer(minutes);
        Navigator.pop(context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF313244),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text('$minutes min'),
    );
  }
}
