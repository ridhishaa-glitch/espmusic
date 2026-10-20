import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/player_provider.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../widgets/mini_player.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  Playlist? _detailedPlaylist;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    final api = context.read<PlayerProvider>().apiService;
    try {
      final res = await api.getPlaylistDetails(widget.playlist.id);
      if (mounted) {
        setState(() {
          _detailedPlaylist = res ?? widget.playlist;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _detailedPlaylist = widget.playlist;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final pl = _detailedPlaylist ?? widget.playlist;
    final List<Song> songs = pl.songs ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF89B4FA)))
                : CustomScrollView(
                    slivers: [
                      // Header with Cover Art
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: pl.highQualityImage.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: pl.highQualityImage,
                                        width: 180,
                                        height: 180,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: const Color(0xFF313244)),
                                        errorWidget: (_, __, ___) => const Icon(Icons.queue_music, size: 64, color: Colors.white),
                                      )
                                    : Container(
                                        width: 180,
                                        height: 180,
                                        color: const Color(0xFF313244),
                                        child: const Icon(Icons.queue_music, size: 64, color: Colors.white),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                pl.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (pl.description != null && pl.description!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  pl.description!,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                ),
                              ],
                              const SizedBox(height: 16),
                              // Play All & Shuffle Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: songs.isEmpty ? null : () => player.playQueue(songs, shuffle: false),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('Play All'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF89B4FA),
                                      foregroundColor: const Color(0xFF11111B),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed: songs.isEmpty ? null : () => player.playQueue(songs, shuffle: true),
                                    icon: const Icon(Icons.shuffle_rounded, color: Colors.white),
                                    label: const Text('Shuffle', style: TextStyle(color: Colors.white)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF45475A)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tracks List
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final s = songs[i];
                              final isCurrent = player.currentSong?.id == s.id;
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
                                      player.playSong(s, songs, i);
                                    }
                                  },
                                ),
                                onTap: () => player.playSong(s, songs, i),
                              );
                            },
                            childCount: songs.length,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
