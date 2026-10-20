class EspStatus {
  final String status; // "idle", "playing", "paused", "buffering"
  final String? currentTrackId;
  final String? currentTrackName;
  final String? currentTrackArtist;
  final int duration;
  final int elapsed;
  final int volume;
  final int queueCount;
  final int queueIndex;
  final int sleepTimerSeconds; // 0 if inactive
  final int wifiRssi;
  final int bufferPercent;

  EspStatus({
    required this.status,
    this.currentTrackId,
    this.currentTrackName,
    this.currentTrackArtist,
    required this.duration,
    required this.elapsed,
    required this.volume,
    required this.queueCount,
    required this.queueIndex,
    required this.sleepTimerSeconds,
    required this.wifiRssi,
    required this.bufferPercent,
  });

  bool get isPlaying => status == 'playing';
  bool get isPaused => status == 'paused';
  bool get isBuffering => status == 'buffering';
  bool get isSleepTimerActive => sleepTimerSeconds > 0;

  factory EspStatus.fromJson(Map<String, dynamic> json) {
    final track = json['current_track'] as Map<String, dynamic>?;

    return EspStatus(
      status: json['status']?.toString() ?? 'idle',
      currentTrackId: track?['id']?.toString(),
      currentTrackName: track?['name']?.toString(),
      currentTrackArtist: track?['artist']?.toString(),
      duration: int.tryParse(track?['duration']?.toString() ?? '') ?? 0,
      elapsed: int.tryParse(track?['elapsed']?.toString() ?? '') ?? 0,
      volume: int.tryParse(json['volume']?.toString() ?? '') ?? 70,
      queueCount: int.tryParse(json['queue_count']?.toString() ?? '') ?? 0,
      queueIndex: int.tryParse(json['queue_index']?.toString() ?? '') ?? 0,
      sleepTimerSeconds: int.tryParse(json['sleep_timer_seconds']?.toString() ?? '') ?? 0,
      wifiRssi: int.tryParse(json['wifi_rssi']?.toString() ?? '') ?? 0,
      bufferPercent: int.tryParse(json['buffer_percent']?.toString() ?? '') ?? 0,
    );
  }

  factory EspStatus.idle() {
    return EspStatus(
      status: 'idle',
      duration: 0,
      elapsed: 0,
      volume: 70,
      queueCount: 0,
      queueIndex: 0,
      sleepTimerSeconds: 0,
      wifiRssi: 0,
      bufferPercent: 0,
    );
  }
}
