import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../models/esp_status.dart';

class EspService {
  static const String defaultHost = 'http://192.168.0.59';
  static const String fallbackHost = 'http://espmusic.local';
  static const String prefKeyHost = 'esp_host_url';
  static const String prefKeyQuality = 'preferred_quality';
  static const int udpDiscoveryPort = 4210;

  String _host = defaultHost;
  String _preferredQuality = '160kbps';
  final http.Client _client = http.Client();
  bool _isDiscovering = false;

  String get host => _host;
  String get preferredQuality => _preferredQuality;
  bool get isDiscovering => _isDiscovering;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(prefKeyHost) ?? defaultHost;
    _preferredQuality = prefs.getString(prefKeyQuality) ?? '160kbps';

    // Auto-discover if default or current is unreachable
    final status = await getStatus();
    if (status == null) {
      await autoDiscoverEsp();
    }
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

  /// Multi-strategy Auto-Discovery for ESP32 on local Wi-Fi:
  /// 1. UDP Broadcast query on port 4210
  /// 2. Local subnet fast sweep
  /// 3. Hostname fallback
  Future<String?> autoDiscoverEsp() async {
    if (_isDiscovering) return null;
    _isDiscovering = true;

    try {
      // 1. Try UDP broadcast query
      final String? udpFound = await _discoverViaUdp();
      if (udpFound != null) {
        await setHost('http://$udpFound');
        _isDiscovering = false;
        return _host;
      }

      // 2. Try subnet fast sweep
      final String? sweepFound = await _discoverViaSubnetSweep();
      if (sweepFound != null) {
        await setHost('http://$sweepFound');
        _isDiscovering = false;
        return _host;
      }

      // 3. Try standard mDNS http://espmusic.local
      final status = await _testHost('http://espmusic.local');
      if (status != null) {
        await setHost('http://espmusic.local');
        _isDiscovering = false;
        return _host;
      }
    } catch (_) {
      // Ignore
    } finally {
      _isDiscovering = false;
    }

    return null;
  }

  /// Strategy 1: UDP Broadcast on port 4210
  Future<String?> _discoverViaUdp() async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final completer = Completer<String?>();
      final timer = Timer(const Duration(milliseconds: 1200), () {
        if (!completer.isCompleted) completer.complete(null);
      });

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            final msg = utf8.decode(datagram.data, allowMalformed: true);
            if (msg.contains('ESPMUSIC_IP:')) {
              final ip = msg.replaceAll('ESPMUSIC_IP:', '').trim();
              if (!completer.isCompleted) {
                timer.cancel();
                completer.complete(ip);
              }
            }
          }
        }
      });

      // Send discovery broadcast
      final data = utf8.encode('ESPMUSIC_DISCOVER');
      socket.send(data, InternetAddress('255.255.255.255'), udpDiscoveryPort);

      final result = await completer.future;
      socket.close();
      return result;
    } catch (_) {
      socket?.close();
      return null;
    }
  }

  /// Strategy 2: Probe local subnet in parallel (e.g. 192.168.0.X)
  Future<String?> _discoverViaSubnetSweep() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (var iface in interfaces) {
        for (var addr in iface.addresses) {
          final ip = addr.address;
          // Filter private subnets
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';

              // Prioritize common fixed ranges and known probe
              List<String> probeIps = [
                '$prefix.59', // recently allocated IP
                '$prefix.50',
                '$prefix.100',
              ];

              for (int i = 1; i < 255; i++) {
                final target = '$prefix.$i';
                if (!probeIps.contains(target)) {
                  probeIps.add(target);
                }
              }

              // Probe in chunks of 25 parallel requests for high speed
              for (int c = 0; c < probeIps.length; c += 25) {
                final chunk = probeIps.sublist(c, (c + 25 < probeIps.length) ? c + 25 : probeIps.length);
                final results = await Future.wait(
                  chunk.map((targetIp) => _testHost('http://$targetIp')),
                );

                for (int r = 0; r < results.length; r++) {
                  if (results[r] != null) {
                    return chunk[r];
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<EspStatus?> _testHost(String url) async {
    try {
      final uri = Uri.parse('$url/api/status');
      final response = await _client.get(uri).timeout(const Duration(milliseconds: 350));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return EspStatus.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  /// Fetch live status from active ESP endpoint
  Future<EspStatus?> getStatus() async {
    try {
      final uri = Uri.parse('$_host/api/status');
      final response = await _client.get(uri).timeout(const Duration(milliseconds: 2000));
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
