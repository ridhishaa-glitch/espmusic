import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/esp_status.dart';

class EspService {
  static const String defaultHost = 'http://espmusic.local';
  static const String prefKeyHost = 'esp_host_url';
  static const String prefKeyQuality = 'preferred_quality';

  String _host = defaultHost;
  String _preferredQuality = '160kbps';
  final http.Client _client = http.Client();

  String get host => _host;
  String get preferredQuality => _preferredQuality;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(prefKeyHost) ?? defaultHost;
    _preferredQuality = prefs.getString(prefKeyQuality) ?? '160kbps';
  }

  Future<void> setHost(String newHost) async {
    String cleanHost = newHost.trim();
    if (!cleanHost.startsWith('http://') && !cleanHost.startsWith('https://')) {
      cleanHost = 'http://$cleanHost';
    }
    if (cleanHost.endsWith('/')) {
      cleanHost = cleanHost.substring(0, cleanHost.length - 1);
    }
    _host = cleanHost;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKeyHost, _host);
  }

  Future<void> setPreferredQuality(String quality) async {
    _preferredQuality = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKeyQuality, _preferredQuality);
  }

  /// Check connectivity and fetch live status from ESP
  Future<EspStatus?> getStatus() async {
    try {
      final uri = Uri.parse('$_host/api/status');
      final response = await _client.get(uri).timeout(const Duration(milliseconds: 2500));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return EspStatus.fromJson(json);
      }
    } catch (_) {
      // Offline / unreachable
    }
    return null;
  }

  /// Send immediate play command
  Future<bool> playSong(Song song) async {
    try {
      final uri = Uri.parse('$_host/api/play');
      final payload = song.toEspPayload(preferredQuality: _preferredQuality);
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send a full queue to ESP for autonomous playback
  Future<bool> playQueue(List<Song> songs, {int startIndex = 0, bool shuffle = false}) async {
    try {
      final uri = Uri.parse('$_host/api/queue');
      final tracks = songs.map((s) => s.toEspPayload(preferredQuality: _preferredQuality)).toList();
      final payload = {
        'tracks': tracks,
        'startIndex': startIndex,
        'shuffle': shuffle,
      };
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Playback controls: 'pause', 'resume', 'next', 'prev', 'stop'
  Future<bool> sendControl(String action) async {
    try {
      final uri = Uri.parse('$_host/api/control');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': action}),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Set ESP volume (0 - 100)
  Future<bool> setVolume(int volume) async {
    try {
      final uri = Uri.parse('$_host/api/volume');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'volume': volume.clamp(0, 100)}),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Configure Sleep Timer on ESP in minutes
  Future<bool> setSleepTimer(int minutes) async {
    try {
      final uri = Uri.parse('$_host/api/timer');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'set',
          'minutes': minutes,
        }),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Cancel active Sleep Timer
  Future<bool> cancelSleepTimer() async {
    try {
      final uri = Uri.parse('$_host/api/timer');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'cancel'}),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
