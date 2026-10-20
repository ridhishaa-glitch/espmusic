import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/player_provider.dart';
import '../widgets/sleep_timer_sheet.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  String _formatTime(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final currentSong = player.currentSong;

    if (currentSong == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF181825),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Text('No song playing', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final status = player.espStatus;
    final bool isPlaying = status.isPlaying;
    final int elapsed = status.elapsed;
    final int duration = status.duration > 0 ? status.duration : currentSong.duration;
    final double sliderValue = duration > 0 ? (elapsed / duration).clamp(0.0, 1.0) : 0.0;
    final bool timerActive = status.sleepTimerSeconds > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'PLAYING ON ESP SPEAKER',
              style: TextStyle(
                color: Color(0xFF89B4FA),
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              currentSong.album ?? 'JioSaavn',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.bedtime_outlined,
                  color: timerActive ? const Color(0xFFA6E3A1) : Colors.white70,
                ),
                if (timerActive)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFA6E3A1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Sleep Timer',
            onPressed: () => SleepTimerSheet.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Large Artwork
              Center(
                child: Hero(
                  tag: 'album_art',
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.78,
                    height: MediaQuery.of(context).size.width * 0.78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF89B4FA).withOpacity(0.18),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: currentSong.highQualityImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: currentSong.highQualityImage,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: const Color(0xFF313244)),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFF313244),
                                child: const Icon(Icons.music_note, color: Colors.white, size: 64),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF313244),
                              child: const Icon(Icons.music_note, color: Colors.white, size: 64),
                            ),
                    ),
                  ),
                ),
              ),

              // Title & Artist
              Column(
                children: [
                  Text(
                    currentSong.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentSong.artist,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              // Progress Bar
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: const Color(0xFF89B4FA),
                      inactiveTrackColor: const Color(0xFF313244),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: sliderValue,
                      onChanged: null, // Streaming buffer on ESP is autonomous
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatTime(elapsed), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        Text(_formatTime(duration), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),

              // Main Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded, size: 28),
                    color: player.isShuffle ? const Color(0xFF89B4FA) : Colors.white38,
                    onPressed: () => player.playRandomSuggestions(currentSong),
                    tooltip: 'Play Similar Radio',
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, size: 40),
                    color: Colors.white,
                    onPressed: () => player.previous(),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF89B4FA),
                    ),
                    child: IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 40,
                        color: const Color(0xFF11111B),
                      ),
                      onPressed: () => player.togglePlayPause(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 40),
                    color: Colors.white,
                    onPressed: () => player.next(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.queue_music_rounded, size: 28),
                    color: Colors.white70,
                    onPressed: () => _showQueueModal(context, player),
                  ),
                ],
              ),

              // Volume Slider
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded, color: Colors.white38, size: 20),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                        activeTrackColor: Colors.white70,
                        inactiveTrackColor: const Color(0xFF313244),
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: status.volume.toDouble().clamp(0.0, 100.0),
                        min: 0,
                        max: 100,
                        onChanged: (val) {
                          player.setVolume(val.round());
                        },
                      ),
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, color: Colors.white38, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueueModal(BuildContext context, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final queue = player.queue;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Play Queue (${queue.length} songs)',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (ctx, i) {
                    final s = queue[i];
                    final isCurrent = i == player.queueIndex;
                    return ListTile(
                      leading: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: isCurrent ? const Color(0xFF89B4FA) : Colors.white38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      title: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? const Color(0xFF89B4FA) : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        s.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.graphic_eq_rounded, color: Color(0xFF89B4FA))
                          : null,
                      onTap: () {
                        player.playSong(s, queue, i);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
