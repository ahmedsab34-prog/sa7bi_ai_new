
import 'dart:typed_data';

class NewsItem {
  final String title;
  final String source;
  final String link;
  final String imageUrl;
  final String description;
  final String pubDate;

  const NewsItem({
    required this.title,
    required this.source,
    required this.link,
    this.imageUrl = '',
    this.description = '',
    this.pubDate = '',
  });
}

class AudioSearchItem {
  final String id;
  final String title;
  final String? artist;
  final String url;
  final String type;
  final String artwork;
  final String storeUrl;
  final String text;
  final String repeat;
  final String collection;
  final String feedUrl;

  const AudioSearchItem({
    this.id = '',
    required this.title,
    required this.url,
    this.artist,
    required this.type,
    this.artwork = '',
    this.storeUrl = '',
    this.text = '',
    this.repeat = '',
    this.collection = '',
    this.feedUrl = '',
  });
}

class PodcastItem {
  final String id;
  final String title;
  final String artist;
  final String author;
  final String artwork;
  final String feedUrl;
  final String storeUrl;
  final String genre;
  final String country;
  final String releaseDate;
  final int episodeCount;
  final String description;

  const PodcastItem({
    this.id = '',
    required this.title,
    this.artist = '',
    this.author = '',
    this.artwork = '',
    this.feedUrl = '',
    this.storeUrl = '',
    this.genre = '',
    this.country = '',
    this.releaseDate = '',
    this.episodeCount = 0,
    this.description = '',
  });
}

class PodcastEpisode {
  final String id;
  final String title;
  final String description;
  final String audioUrl;
  final String image;
  final String publishedAt;
  final String duration;
  final int episode;
  final int season;
  final bool explicit;

  const PodcastEpisode({
    this.id = '',
    required this.title,
    required this.audioUrl,
    this.description = '',
    this.image = '',
    this.publishedAt = '',
    this.duration = '',
    this.episode = 0,
    this.season = 0,
    this.explicit = false,
  });
}

class HadithBook {
  final String id;
  final String name;

  const HadithBook({
    required this.id,
    required this.name,
  });
}

class HadithItem {
  final String id;
  final String number;
  final String book;
  final String bookName;
  final String text;
  final String source;

  const HadithItem({
    this.id = '',
    this.number = '',
    this.book = '',
    this.bookName = '',
    required this.text,
    this.source = '',
  });
}

class TafsirBook {
  final int id;
  final String name;

  const TafsirBook({
    required this.id,
    required this.name,
  });
}

class TafsirItem {
  final String id;
  final int tafsirId;
  final String tafsirName;
  final int sura;
  final String suraName;
  final String audioUrl;

  const TafsirItem({
    this.id = '',
    required this.tafsirId,
    required this.tafsirName,
    required this.sura,
    required this.suraName,
    this.audioUrl = '',
  });
}

class TafsirAudioResult {
  final bool available;
  final String audioUrl;

  const TafsirAudioResult({
    required this.available,
    required this.audioUrl,
  });
}

class ImageGenerationResult {
  final Uint8List? bytes;
  final String? imageUrl;
  final String? error;

  const ImageGenerationResult._({
    this.bytes,
    this.imageUrl,
    this.error,
  });

  const ImageGenerationResult.success(Uint8List bytes)
      : this._(bytes: bytes);

  const ImageGenerationResult.successUrl(String url)
      : this._(imageUrl: url);

  const ImageGenerationResult.failure(String error)
      : this._(error: error);

  bool get isSuccess =>
      (bytes != null && bytes!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);
}

class QuranCatalog {
  final List<QuranReciter> reciters;
  final List<QuranSura> suwar;

  const QuranCatalog({
    required this.reciters,
    required this.suwar,
  });
}

class QuranReciter {
  final String id;
  final String name;
  final List<QuranMoshaf> moshaf;

  const QuranReciter({
    required this.id,
    required this.name,
    required this.moshaf,
  });
}

class QuranMoshaf {
  final String id;
  final String name;
  final String server;
  final int surahTotal;
  final String surahList;

  const QuranMoshaf({
    required this.id,
    required this.name,
    required this.server,
    required this.surahTotal,
    required this.surahList,
  });
}

class QuranSura {
  final int id;
  final String name;

  const QuranSura({
    required this.id,
    required this.name,
  });
}

class RadioCountry {
  final String name;
  final String code;
  final int stationCount;

  const RadioCountry({
    required this.name,
    required this.code,
    required this.stationCount,
  });
}

class RadioStation {
  final String id;
  final String name;
  final String url;
  final String homepage;
  final String favicon;
  final String tags;
  final String codec;
  final int bitrate;

  const RadioStation({
    this.id = '',
    required this.name,
    required this.url,
    required this.homepage,
    required this.favicon,
    required this.tags,
    required this.codec,
    required this.bitrate,
  });
}

class ShortVideoItem {
  final String id;
  final String title;
  final String creator;
  final String videoUrl;
  final String thumbnail;
  final String description;

  const ShortVideoItem({
    this.id = '',
    required this.title,
    required this.creator,
    required this.videoUrl,
    required this.thumbnail,
    this.description = '',
  });
}
