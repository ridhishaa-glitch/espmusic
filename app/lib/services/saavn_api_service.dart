import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/album.dart';
import '../models/playlist.dart';
import '../models/artist.dart';

class SearchResults {
  final List<Song> songs;
  final List<Album> albums;
  final List<Playlist> playlists;
  final List<Artist> artists;

  SearchResults({
    required this.songs,
    required this.albums,
    required this.playlists,
    required this.artists,
  });
}

class SaavnApiService {
  static const String baseUrl = 'https://saavn.sumit.co';
  final http.Client _client = http.Client();

  /// Global multi-category search
  Future<SearchResults> globalSearch(String query) async {
    final uri = Uri.parse('$baseUrl/api/search?query=${Uri.encodeComponent(query)}');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        final data = json['data'];

        List<Song> songs = [];
        if (data['songs']?['results'] is List) {
          for (var item in data['songs']['results']) {
            songs.add(Song.fromJson(item));
          }
        }

        List<Album> albums = [];
        if (data['albums']?['results'] is List) {
          for (var item in data['albums']['results']) {
            albums.add(Album.fromJson(item));
          }
        }

        List<Playlist> playlists = [];
        if (data['playlists']?['results'] is List) {
          for (var item in data['playlists']['results']) {
            playlists.add(Playlist.fromJson(item));
          }
        }

        List<Artist> artists = [];
        if (data['artists']?['results'] is List) {
          for (var item in data['artists']['results']) {
            artists.add(Artist.fromJson(item));
          }
        }

        return SearchResults(songs: songs, albums: albums, playlists: playlists, artists: artists);
      }
    }
    return SearchResults(songs: [], albums: [], playlists: [], artists: []);
  }

  /// Search songs specifically with pagination
  Future<List<Song>> searchSongs(String query, {int page = 0, int limit = 20}) async {
    final uri = Uri.parse('$baseUrl/api/search/songs?query=${Uri.encodeComponent(query)}&page=$page&limit=$limit');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data']?['results'] is List) {
        return (json['data']['results'] as List).map((i) => Song.fromJson(i)).toList();
      }
    }
    return [];
  }

  /// Search albums specifically
  Future<List<Album>> searchAlbums(String query, {int page = 0, int limit = 20}) async {
    final uri = Uri.parse('$baseUrl/api/search/albums?query=${Uri.encodeComponent(query)}&page=$page&limit=$limit');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data']?['results'] is List) {
        return (json['data']['results'] as List).map((i) => Album.fromJson(i)).toList();
      }
    }
    return [];
  }

  /// Search playlists specifically
  Future<List<Playlist>> searchPlaylists(String query, {int page = 0, int limit = 20}) async {
    final uri = Uri.parse('$baseUrl/api/search/playlists?query=${Uri.encodeComponent(query)}&page=$page&limit=$limit');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data']?['results'] is List) {
        return (json['data']['results'] as List).map((i) => Playlist.fromJson(i)).toList();
      }
    }
    return [];
  }

  /// Get detailed song info by ID
  Future<Song?> getSongById(String id) async {
    final uri = Uri.parse('$baseUrl/api/songs/$id');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] is List && (json['data'] as List).isNotEmpty) {
        return Song.fromJson(json['data'][0]);
      }
    }
    return null;
  }

  /// Get song suggestions / similar tracks for infinite playback
  Future<List<Song>> getSongSuggestions(String songId, {int limit = 15}) async {
    final uri = Uri.parse('$baseUrl/api/songs/$songId/suggestions?limit=$limit');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] is List) {
        return (json['data'] as List).map((i) => Song.fromJson(i)).toList();
      }
    }
    return [];
  }

  /// Get album details including track list
  Future<Album?> getAlbumDetails(String albumId) async {
    final uri = Uri.parse('$baseUrl/api/albums?id=$albumId');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        return Album.fromJson(json['data']);
      }
    }
    return null;
  }

  /// Get playlist details including track list
  Future<Playlist?> getPlaylistDetails(String playlistId) async {
    final uri = Uri.parse('$baseUrl/api/playlists?id=$playlistId&limit=100');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        return Playlist.fromJson(json['data']);
      }
    }
    return null;
  }

  /// Get artist top songs
  Future<List<Song>> getArtistSongs(String artistId, {int page = 0, int limit = 30}) async {
    final uri = Uri.parse('$baseUrl/api/artists/$artistId/songs?page=$page&limit=$limit&sortBy=popularity&sortOrder=desc');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data']?['songs'] is List) {
        return (json['data']['songs'] as List).map((i) => Song.fromJson(i)).toList();
      }
    }
    return [];
  }
}
