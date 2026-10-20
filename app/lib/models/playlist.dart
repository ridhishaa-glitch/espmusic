import 'song.dart';

class Playlist {
  final String id;
  final String name;
  final String? description;
  final int? songCount;
  final List<SongImage> images;
  final List<Song>? songs;

  Playlist({
    required this.id,
    required this.name,
    this.description,
    this.songCount,
    required this.images,
    this.songs,
  });

  String get highQualityImage {
    if (images.isEmpty) return '';
    for (var img in images) {
      if (img.quality.contains('500')) return img.url;
    }
    return images.last.url;
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    List<SongImage> imgs = [];
    if (json['image'] is List) {
      for (var item in json['image']) {
        if (item is Map<String, dynamic>) {
          imgs.add(SongImage.fromJson(item));
        }
      }
    }

    List<Song>? songList;
    if (json['songs'] is List) {
      songList = [];
      for (var s in json['songs']) {
        if (s is Map<String, dynamic>) {
          songList.add(Song.fromJson(s));
        }
      }
    }

    return Playlist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Playlist',
      description: json['description']?.toString(),
      songCount: int.tryParse(json['songCount']?.toString() ?? ''),
      images: imgs,
      songs: songList,
    );
  }
}
