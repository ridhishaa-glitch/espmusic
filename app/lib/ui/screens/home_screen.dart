import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/player_provider.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../widgets/esp_badge.dart';
import '../widgets/mini_player.dart';
import '../widgets/sleep_timer_sheet.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'playlist_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Playlist> _featuredPlaylists = [];
  List<Song> _trendingSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialContent();
  }

  Future<void> _loadInitialContent() async {
    final player = context.read<PlayerProvider>();
    try {
      final playlists = await player.apiService.searchPlaylists('Top Hits', limit: 8);
      final songs = await player.apiService.searchSongs('Hindi Trending', limit: 10);
      if (mounted) {
        setState(() {
          _featuredPlaylists = playlists;
          _trendingSongs = songs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181825),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.speaker_group_rounded, color: Color(0xFF89B4FA), size: 26),
            SizedBox(width: 8),
            Text(
              'ESP Music',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          const EspBadge(),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.bedtime_outlined, color: Colors.white),
                if (player.espStatus.sleepTimerSeconds > 0)
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
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadInitialContent();
                await player.checkEspConnection();
              },
              color: const Color(0xFF89B4FA),
              backgroundColor: const Color(0xFF313244),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Search & Random Quick Action Card
                  _buildQuickActionCard(context, player),

                  const SizedBox(height: 24),

                  // Featured Playlists Header
                  const Text(
                    'Featured Playlists',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: Color(0xFF89B4FA)),
                      ),
                    )
                  else if (_featuredPlaylists.isEmpty)
                    const Text('No playlists found', style: TextStyle(color: Colors.white38))
                  else
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _featuredPlaylists.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (ctx, i) {
                          final pl = _featuredPlaylists[i];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaylistDetailScreen(playlist: pl),
                                ),
                              );
                            },
                            child: SizedBox(
                              width: 130,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: pl.highQualityImage.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: pl.highQualityImage,
                                            width: 130,
                                            height: 130,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: const Color(0xFF313244)),
                                            errorWidget: (_, __, ___) => Container(
                                              color: const Color(0xFF313244),
                                              child: const Icon(Icons.queue_music, color: Colors.white),
                                            ),
                                          )
                                        : Container(
                                            width: 130,
                                            height: 130,
                                            color: const Color(0xFF313244),
                                            child: const Icon(Icons.queue_music, color: Colors.white),
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    pl.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Trending Songs Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Trending Tracks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
                        },
                        child: const Text('See More', style: TextStyle(color: Color(0xFF89B4FA))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _trendingSongs.length,
                    itemBuilder: (ctx, i) {
                      final s = _trendingSongs[i];
                      final isCurrent = player.currentSong?.id == s.id;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: s.thumbnailImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: s.thumbnailImage,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: const Color(0xFF313244)),
                                  errorWidget: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  color: const Color(0xFF313244),
                                  child: const Icon(Icons.music_note, color: Colors.white),
                                ),
                        ),
                        title: Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent ? const Color(0xFF89B4FA) : Colors.white,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          s.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isCurrent && player.espStatus.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: const Color(0xFF89B4FA),
                            size: 32,
                          ),
                          onPressed: () {
                            if (isCurrent) {
                              player.togglePlayPause();
                            } else {
                              player.playSong(s, _trendingSongs, i);
                            }
                          },
                        ),
                        onTap: () => player.playSong(s, _trendingSongs, i),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),

          // Persistent Mini Player
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, PlayerProvider player) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF313244), Color(0xFF1E1E2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Search input trigger
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF181825),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: Colors.white38),
                  SizedBox(width: 12),
                  Text(
                    'Search songs, albums, playlists...',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_trendingSongs.isNotEmpty) {
                      player.playQueue(_trendingSongs, shuffle: true);
                    }
                  },
                  icon: const Icon(Icons.shuffle_rounded, size: 20),
                  label: const Text('Play Random'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF89B4FA),
                    foregroundColor: const Color(0xFF11111B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => SleepTimerSheet.show(context),
                icon: const Icon(Icons.bedtime_outlined, size: 20),
                label: const Text('Timer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF45475A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
