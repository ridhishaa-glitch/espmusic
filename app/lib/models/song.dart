class SongDownloadUrl {
  final String quality;
  final String url;

  SongDownloadUrl({required this.quality, required this.url});

  factory SongDownloadUrl.fromJson(Map<String, dynamic> json) {
    return SongDownloadUrl(
      quality: json['quality']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'quality': quality,
    'url': url,
  };
}

class SongImage {
  final String quality;
  final String url;

  SongImage({required this.quality, required this.url});

  factory SongImage.fromJson(Map<String, dynamic> json) {
    return SongImage(
      quality: json['quality']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

class Song {
  final String id;
  final String name;
  final String? album;
  final String? albumId;
  final String artist;
  final int duration; // in seconds
  final String? year;
  final List<SongImage> images;
  final List<SongDownloadUrl> downloadUrls;

  Song({
    required this.id,
    required this.name,
    this.album,
    this.albumId,
    required this.artist,
    required this.duration,
    this.year,
    required this.images,
    required this.downloadUrls,
  });

  String get highQualityImage {
    if (images.isEmpty) return '';
    // Prefer 500x500, then 150x150, or first
    for (var img in images) {
      if (img.quality.contains('500')) return img.url;
    }
    return images.last.url;
  }

  String get thumbnailImage {
    if (images.isEmpty) return '';
    for (var img in images) {
      if (img.quality.contains('150')) return img.url;
    }
    return images.first.url;
  }

  String getStreamUrl({String preferredQuality = '160kbps'}) {
    if (downloadUrls.isEmpty) return '';
    for (var d in downloadUrls) {
      if (d.quality == preferredQuality) return d.url;
    }
    // Fallback: 160kbps or 320kbps or last
    for (var d in downloadUrls) {
      if (d.quality.contains('160')) return d.url;
    }
    return downloadUrls.last.url;
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    // Parse artists
    String artistStr = 'Unknown Artist';
    if (json['artists'] != null && json['artists'] is Map) {
      final primary = json['artists']['primary'];
      if (primary is List && primary.isNotEmpty) {
        artistStr = primary.map((a) => a['name']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ');
      }
    } else if (json['primaryArtists'] != null) {
      artistStr = json['primaryArtists'].toString();
    }

    // Parse album
    String? albumName;
    String? albumId;
    if (json['album'] != null) {
      if (json['album'] is Map) {
        albumName = json['album']['name']?.toString();
        albumId = json['album']['id']?.toString();
      } else if (json['album'] is String) {
        albumName = json['album'].toString();
      }
    }

    // Parse duration
    int dur = 0;
    if (json['duration'] != null) {
      dur = int.tryParse(json['duration'].toString()) ?? 0;
    }

    // Parse images
    List<SongImage> imgs = [];
    if (json['image'] is List) {
      for (var item in json['image']) {
        if (item is Map<String, dynamic>) {
          imgs.add(SongImage.fromJson(item));
        }
      }
    }

    // Parse download URLs
    List<SongDownloadUrl> urls = [];
    if (json['downloadUrl'] is List) {
      for (var item in json['downloadUrl']) {
        if (item is Map<String, dynamic>) {
          urls.add(SongDownloadUrl.fromJson(item));
        }
      }
    }

    return Song(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Unknown Track',
      album: albumName,
      albumId: albumId,
      artist: artistStr,
      duration: dur,
      year: json['year']?.toString(),
      images: imgs,
      downloadUrls: urls,
    );
  }

  Map<String, dynamic> toEspPayload({String preferredQuality = '160kbps'}) {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'duration': duration,
      'url': getStreamUrl(preferredQuality: preferredQuality),
      'image': thumbnailImage,
    };
  }
}
