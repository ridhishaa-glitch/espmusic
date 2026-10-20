import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../models/esp_status.dart';
import '../services/saavn_api_service.dart';
import '../services/esp_service.dart';

class PlayerProvider extends ChangeNotifier {
  final SaavnApiService apiService = SaavnApiService();
  final EspService espService = EspService();

  Song? _currentSong;
  List<Song> _queue = [];
  int _queueIndex = 0;
  bool _isShuffle = false;
  bool _isRepeat = false;

  bool _isEspConnected = false;
  EspStatus _espStatus = EspStatus.idle();
  Timer? _statusPollTimer;
  bool _isBusy = false;

  Song? get currentSong => _currentSong;
  List<Song> get queue => _queue;
  int get queueIndex => _queueIndex;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;
  bool get isEspConnected => _isEspConnected;
  EspStatus get espStatus => _espStatus;
  bool get isBusy => _isBusy;

  PlayerProvider() {
    _init();
  }

  Future<void> _init() async {
    await espService.init();
    await checkEspConnection();
    _startStatusPolling();
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) async {
      await pollEspStatus();
    });
  }

  Future<void> checkEspConnection() async {
    final status = await espService.getStatus();
    if (status != null) {
      _isEspConnected = true;
      _espStatus = status;
    } else {
      _isEspConnected = false;
    }
    notifyListeners();
  }

  int _failedPollCount = 0;

  Future<void> pollEspStatus() async {
    final status = await espService.getStatus();
    if (status != null) {
      _failedPollCount = 0;
      _isEspConnected = true;
      _espStatus = status;

      // Sync current song from queue if ESP transitioned to next track
      if (status.currentTrackId != null &&
          _currentSong?.id != status.currentTrackId &&
          _queue.isNotEmpty) {
        final matchIdx = _queue.indexWhere((s) => s.id == status.currentTrackId);
        if (matchIdx != -1) {
          _queueIndex = matchIdx;
          _currentSong = _queue[matchIdx];
        }
      }
      notifyListeners();
    } else {
      _failedPollCount++;
      if (_isEspConnected) {
        _isEspConnected = false;
        notifyListeners();
      }
      // Periodically attempt auto-discovery when disconnected (every ~6-8s)
      if (_failedPollCount % 4 == 0) {
        final found = await espService.autoDiscoverEsp();
        if (found != null) {
          await checkEspConnection();
        }
      }
    }
  }

  /// Play a specific song immediately (optionally with surrounding queue context)
  Future<void> playSong(Song song, [List<Song>? queueContext, int index = 0]) async {
    _currentSong = song;
    if (queueContext != null && queueContext.isNotEmpty) {
      _queue = List.from(queueContext);
      _queueIndex = index;
    } else {
      _queue = [song];
      _queueIndex = 0;
    }

    _isBusy = true;
    notifyListeners();

    final success = await espService.playSong(song);
    _isBusy = false;
    if (success) {
      _isEspConnected = true;
    }
    await pollEspStatus();
    notifyListeners();
  }

  /// Play a whole queue / playlist
  Future<void> playQueue(List<Song> songs, {int startIndex = 0, bool shuffle = false}) async {
    if (songs.isEmpty) return;
    _queue = List.from(songs);
    _queueIndex = startIndex.clamp(0, songs.length - 1);
    _isShuffle = shuffle;
    _currentSong = _queue[_queueIndex];

    _isBusy = true;
    notifyListeners();

    final success = await espService.playQueue(_queue, startIndex: _queueIndex, shuffle: shuffle);
    _isBusy = false;
    if (success) {
      _isEspConnected = true;
    }
    await pollEspStatus();
    notifyListeners();
  }

  /// Play random / radio starting with suggestions from a base song
  Future<void> playRandomSuggestions(Song baseSong) async {
    _isBusy = true;
    notifyListeners();

    final suggestions = await apiService.getSongSuggestions(baseSong.id, limit: 20);
    List<Song> radioQueue = [baseSong];
    if (suggestions.isNotEmpty) {
      radioQueue.addAll(suggestions);
    }

    await playQueue(radioQueue, startIndex: 0, shuffle: true);
    _isBusy = false;
    notifyListeners();
  }

  /// Playback controls
  Future<void> togglePlayPause() async {
    if (_espStatus.isPlaying) {
      await espService.sendControl('pause');
    } else {
      await espService.sendControl('resume');
    }
    await pollEspStatus();
  }

  Future<void> next() async {
    if (_queue.isNotEmpty && _queueIndex < _queue.length - 1) {
      _queueIndex++;
      _currentSong = _queue[_queueIndex];
      notifyListeners();
      await espService.sendControl('next');
    } else if (_currentSong != null) {
      // Infinite playback fallback: fetch suggestions!
      final suggestions = await apiService.getSongSuggestions(_currentSong!.id, limit: 10);
      if (suggestions.isNotEmpty) {
        _queue.addAll(suggestions);
        _queueIndex++;
        _currentSong = _queue[_queueIndex];
        notifyListeners();
        await espService.playSong(_currentSong!);
      }
    }
    await pollEspStatus();
  }

  Future<void> previous() async {
    if (_queue.isNotEmpty && _queueIndex > 0) {
      _queueIndex--;
      _currentSong = _queue[_queueIndex];
      notifyListeners();
      await espService.sendControl('prev');
    }
    await pollEspStatus();
  }

  Future<void> setVolume(int volume) async {
    await espService.setVolume(volume);
    await pollEspStatus();
  }

  Future<void> setSleepTimer(int minutes) async {
    await espService.setSleepTimer(minutes);
    await pollEspStatus();
  }

  Future<void> cancelSleepTimer() async {
    await espService.cancelSleepTimer();
    await pollEspStatus();
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    super.dispose();
  }
}
