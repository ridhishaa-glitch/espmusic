import 'song.dart';

class Album {
  final String id;
  final String name;
  final String? year;
  final String? artist;
  final int? songCount;
  final List<SongImage> images;
  final List<Song>? songs;

  Album({
    required this.id,
    required this.name,
    this.year,
    this.artist,
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

  factory Album.fromJson(Map<String, dynamic> json) {
    List<SongImage> imgs = [];
    if (json['image'] is List) {
      for (var item in json['image']) {
        if (item is Map<String, dynamic>) {
          imgs.add(SongImage.fromJson(item));
        }
      }
    }

    String? artistName;
    if (json['artists'] != null && json['artists'] is Map) {
      final primary = json['artists']['primary'];
      if (primary is List && primary.isNotEmpty) {
        artistName = primary.map((a) => a['name']?.toString() ?? '').join(', ');
      }
    } else if (json['artist'] != null) {
      artistName = json['artist'].toString();
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

    return Album(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Unknown Album',
      year: json['year']?.toString(),
      artist: artistName,
      songCount: int.tryParse(json['songCount']?.toString() ?? ''),
      images: imgs,
      songs: songList,
    );
  }
}
