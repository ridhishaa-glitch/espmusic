import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/player_provider.dart';
import '../screens/now_playing_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final currentSong = player.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final status = player.espStatus;
    final isPlaying = status.isPlaying;
    final double progress = (status.duration > 0)
        ? (status.elapsed / status.duration).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF24273A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: currentSong.thumbnailImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: currentSong.thumbnailImage,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.grey[800]),
                            errorWidget: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white),
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note, color: Colors.white),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentSong.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: const Color(0xFF89B4FA),
                      size: 34,
                    ),
                    onPressed: () => player.togglePlayPause(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                    onPressed: () => player.next(),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF89B4FA)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
