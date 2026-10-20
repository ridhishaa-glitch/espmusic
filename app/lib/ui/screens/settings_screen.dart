import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _hostController;
  bool _isTesting = false;
  bool _isAutoScanning = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    final player = context.read<PlayerProvider>();
    _hostController = TextEditingController(text: player.espService.host);
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final player = context.read<PlayerProvider>();
    await player.espService.setHost(_hostController.text);
    final status = await player.espService.getStatus();

    if (mounted) {
      setState(() {
        _isTesting = false;
        if (status != null) {
          _testSuccess = true;
          _testResult = 'Connected successfully!\n'
              'Host: ${_hostController.text}\n'
              'Status: ${status.status}\n'
              'Wi-Fi RSSI: ${status.wifiRssi} dBm\n'
              'Buffer: ${status.bufferPercent}%\n'
              'Volume: ${status.volume}%\n'
              'Sleep Timer: ${status.sleepTimerSeconds}s';
        } else {
          _testSuccess = false;
          _testResult = 'Connection failed to ${_hostController.text}.\n'
              'Note: Android blocks .local mDNS on most phones.\n'
              'Tap "Auto-Detect ESP32" below or enter your ESP IP (e.g. http://192.168.0.59)';
        }
      });
      await player.checkEspConnection();
    }
  }

  Future<void> _runAutoDiscovery() async {
    setState(() {
      _isAutoScanning = true;
      _testResult = 'Scanning local network for ESP32...';
      _testSuccess = false;
    });

    final player = context.read<PlayerProvider>();
    final foundHost = await player.espService.autoDiscoverEsp();

    if (mounted) {
      setState(() {
        _isAutoScanning = false;
        if (foundHost != null) {
          _hostController.text = foundHost;
          _testSuccess = true;
          _testResult = 'ESP32 Discovered Successfully!\nEndpoint: $foundHost';
        } else {
          _testSuccess = false;
          _testResult = 'Auto-discovery timed out.\n'
              'You can directly tap "Use http://192.168.0.59" below.';
        }
      });
      await player.checkEspConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('ESP Settings', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const Text(
            'ESP Device Endpoint',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Android often does not resolve .local mDNS domains. You can use Auto-Detect or enter your ESP32 IP directly (e.g. http://192.168.0.59).',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hostController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF313244),
              hintText: 'http://192.168.0.59 or http://espmusic.local',
              hintStyle: const TextStyle(color: Colors.white38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Preset Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.flash_on, size: 16, color: Color(0xFFA6E3A1)),
                label: const Text('Use http://192.168.0.59', style: TextStyle(fontSize: 12)),
                backgroundColor: const Color(0xFF1E3A2F),
                labelStyle: const TextStyle(color: Color(0xFFA6E3A1)),
                onPressed: () {
                  _hostController.text = 'http://192.168.0.59';
                  _testConnection();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.wifi, size: 16, color: Colors.white70),
                label: const Text('Use http://espmusic.local', style: TextStyle(fontSize: 12)),
                backgroundColor: const Color(0xFF313244),
                labelStyle: const TextStyle(color: Colors.white70),
                onPressed: () {
                  _hostController.text = 'http://espmusic.local';
                  _testConnection();
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isTesting || _isAutoScanning) ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF89B4FA),
                    foregroundColor: const Color(0xFF11111B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: (_isTesting || _isAutoScanning) ? null : _runAutoDiscovery,
                icon: _isAutoScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.radar_rounded, color: Colors.white),
                label: const Text('Auto-Detect', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF45475A),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _testSuccess ? const Color(0xFF1E3A2F) : const Color(0xFF3B2D2F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _testSuccess ? const Color(0xFFA6E3A1) : Colors.redAccent,
                  width: 1,
                ),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testSuccess ? const Color(0xFFA6E3A1) : Colors.redAccent,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
          const Divider(color: Color(0xFF313244)),
          const SizedBox(height: 16),

          const Text(
            'Streaming Audio Quality',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose the audio stream bitrate sent to the ESP32. 160kbps offers the ideal balance of fidelity and instant buffer speed.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ...['160kbps', '320kbps', '96kbps'].map((quality) {
            return RadioListTile<String>(
              value: quality,
              groupValue: player.espService.preferredQuality,
              title: Text(
                quality == '160kbps'
                    ? '160 kbps (Recommended)'
                    : quality == '320kbps'
                        ? '320 kbps (High Fidelity)'
                        : '96 kbps (Fast / Weak Wi-Fi)',
                style: const TextStyle(color: Colors.white),
              ),
              activeColor: const Color(0xFF89B4FA),
              onChanged: (val) {
                if (val != null) {
                  player.espService.setPreferredQuality(val);
                  setState(() {});
                }
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}
