import 'song.dart';
import 'album.dart';

class Artist {
  final String id;
  final String name;
  final String? role;
  final List<SongImage> images;
  final List<Song>? topSongs;
  final List<Album>? topAlbums;

  Artist({
    required this.id,
    required this.name,
    this.role,
    required this.images,
    this.topSongs,
    this.topAlbums,
  });

  String get highQualityImage {
    if (images.isEmpty) return '';
    for (var img in images) {
      if (img.quality.contains('500')) return img.url;
    }
    return images.last.url;
  }

  factory Artist.fromJson(Map<String, dynamic> json) {
    List<SongImage> imgs = [];
    if (json['image'] is List) {
      for (var item in json['image']) {
        if (item is Map<String, dynamic>) {
          imgs.add(SongImage.fromJson(item));
        }
      }
    }

    List<Song>? songs;
    if (json['topSongs'] is List) {
      songs = [];
      for (var s in json['topSongs']) {
        if (s is Map<String, dynamic>) {
          songs.add(Song.fromJson(s));
        }
      }
    }

    List<Album>? albums;
    if (json['topAlbums'] is List) {
      albums = [];
      for (var a in json['topAlbums']) {
        if (a is Map<String, dynamic>) {
          albums.add(Album.fromJson(a));
        }
      }
    }

    return Artist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Artist',
      role: json['role']?.toString(),
      images: imgs,
      topSongs: songs,
      topAlbums: albums,
    );
  }
}
