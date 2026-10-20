import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/player_provider.dart';
import '../../models/song.dart';
import '../../models/album.dart';
import '../../models/playlist.dart';
import '../../models/artist.dart';
import '../widgets/mini_player.dart';
import 'playlist_detail_screen.dart';
import 'album_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  String _selectedFilter = 'All';

  List<Song> _songs = [];
  List<Album> _albums = [];
  List<Playlist> _playlists = [];
  List<Artist> _artists = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _songs = [];
        _albums = [];
        _playlists = [];
        _artists = [];
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final api = context.read<PlayerProvider>().apiService;

    try {
      if (_selectedFilter == 'All') {
        final res = await api.globalSearch(query);
        if (mounted) {
          setState(() {
            _songs = res.songs;
            _albums = res.albums;
            _playlists = res.playlists;
            _artists = res.artists;
            _isLoading = false;
          });
        }
      } else if (_selectedFilter == 'Songs') {
        final songs = await api.searchSongs(query, limit: 30);
        if (mounted) {
          setState(() {
            _songs = songs;
            _albums = [];
            _playlists = [];
            _artists = [];
            _isLoading = false;
          });
        }
      } else if (_selectedFilter == 'Albums') {
        final albums = await api.searchAlbums(query, limit: 20);
        if (mounted) {
          setState(() {
            _albums = albums;
            _songs = [];
            _playlists = [];
            _artists = [];
            _isLoading = false;
          });
        }
      } else if (_selectedFilter == 'Playlists') {
        final playlists = await api.searchPlaylists(query, limit: 20);
        if (mounted) {
          setState(() {
            _playlists = playlists;
            _songs = [];
            _albums = [];
            _artists = [];
            _isLoading = false;
          });
        }
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
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search songs, playlists, artists...',
            hintStyle: const TextStyle(color: Colors.white38),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['All', 'Songs', 'Albums', 'Playlists'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: const Color(0xFF89B4FA),
                    backgroundColor: const Color(0xFF313244),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF11111B) : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    checkmarkColor: const Color(0xFF11111B),
                    onSelected: (val) {
                      setState(() => _selectedFilter = filter);
                      if (_searchController.text.isNotEmpty) {
                        _performSearch(_searchController.text.trim());
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Search Results List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF89B4FA)))
                : _buildResultsList(player),
          ),

          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildResultsList(PlayerProvider player) {
    final bool isEmpty = _songs.isEmpty && _albums.isEmpty && _playlists.isEmpty && _artists.isEmpty;

    if (isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'Type to search JioSaavn music'
              : 'No results found',
          style: const TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (_songs.isNotEmpty) ...[
          const Text('Songs', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._songs.map((song) => _buildSongTile(song, player)).toList(),
          const SizedBox(height: 16),
        ],
        if (_playlists.isNotEmpty) ...[
          const Text('Playlists', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._playlists.map((pl) => _buildPlaylistTile(pl)).toList(),
          const SizedBox(height: 16),
        ],
        if (_albums.isNotEmpty) ...[
          const Text('Albums', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._albums.map((album) => _buildAlbumTile(album)).toList(),
        ],
      ],
    );
  }

  Widget _buildSongTile(Song song, PlayerProvider player) {
    final isCurrent = player.currentSong?.id == song.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: song.thumbnailImage.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: song.thumbnailImage,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF313244)),
                errorWidget: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white),
              )
            : Container(
                width: 46,
                height: 46,
                color: const Color(0xFF313244),
                child: const Icon(Icons.music_note, color: Colors.white),
              ),
      ),
      title: Text(
        song.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? const Color(0xFF89B4FA) : Colors.white,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
        onPressed: () => _showSongOptions(context, song, player),
      ),
      onTap: () => player.playSong(song, _songs, _songs.indexOf(song)),
    );
  }

  Widget _buildPlaylistTile(Playlist pl) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: pl.highQualityImage.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: pl.highQualityImage,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF313244)),
                errorWidget: (_, __, ___) => const Icon(Icons.queue_music, color: Colors.white),
              )
            : Container(
                width: 46,
                height: 46,
                color: const Color(0xFF313244),
                child: const Icon(Icons.queue_music, color: Colors.white),
              ),
      ),
      title: Text(
        pl.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${pl.songCount ?? 0} songs',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlist: pl)),
        );
      },
    );
  }

  Widget _buildAlbumTile(Album album) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: album.highQualityImage.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: album.highQualityImage,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF313244)),
                errorWidget: (_, __, ___) => const Icon(Icons.album, color: Colors.white),
              )
            : Container(
                width: 46,
                height: 46,
                color: const Color(0xFF313244),
                child: const Icon(Icons.album, color: Colors.white),
              ),
      ),
      title: Text(
        album.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        album.artist ?? 'Album',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
        );
      },
    );
  }

  void _showSongOptions(BuildContext context, Song song, PlayerProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded, color: Color(0xFF89B4FA)),
                title: const Text('Play Now on ESP', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  player.playSong(song);
                },
              ),
              ListTile(
                leading: const Icon(Icons.shuffle_rounded, color: Colors.white70),
                title: const Text('Play Radio / Similar Songs', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  player.playRandomSuggestions(song);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
