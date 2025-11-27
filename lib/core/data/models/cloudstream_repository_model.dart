import '../../domain/entities/extension_entity.dart';
import 'extension_model.dart';

/// Model representing a CloudStream repository manifest
///
/// CloudStream repositories have a specific JSON format:
/// {
///   "name": "Repository Name",
///   "description": "Repository description",
///   "iconUrl": "https://example.com/icon.png",
///   "manifestVersion": 1,
///   "pluginLists": ["https://example.com/plugins.json"]
/// }
class CloudStreamRepositoryModel {
  /// Name of the repository
  final String name;

  /// Description of the repository
  final String? description;

  /// URL to the repository icon
  final String? iconUrl;

  /// Manifest version number
  final int manifestVersion;

  /// List of URLs pointing to plugin list JSON files
  final List<String> pluginLists;

  const CloudStreamRepositoryModel({
    required this.name,
    this.description,
    this.iconUrl,
    this.manifestVersion = 1,
    required this.pluginLists,
  });

  /// Creates a CloudStreamRepositoryModel from JSON
  factory CloudStreamRepositoryModel.fromJson(Map<String, dynamic> json) {
    return CloudStreamRepositoryModel(
      name: json['name'] as String? ?? 'Unknown Repository',
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      manifestVersion: json['manifestVersion'] as int? ?? 1,
      pluginLists:
          (json['pluginLists'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// Converts this model to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'manifestVersion': manifestVersion,
      'pluginLists': pluginLists,
    };
  }

  /// Returns true if this is a valid CloudStream repository manifest
  bool get isValid => pluginLists.isNotEmpty;
}

/// Model representing a CloudStream plugin/extension
///
/// CloudStream plugins have a specific JSON format:
/// {
///   "url": "https://example.com/plugin.cs3",
///   "status": 1,
///   "version": 1,
///   "apiVersion": 1,
///   "name": "Plugin Name",
///   "internalName": "plugin-internal",
///   "authors": ["Author"],
///   "description": "Plugin description",
///   "language": "en",
///   "iconUrl": "https://example.com/icon.png",
///   "tvTypes": ["Movie", "TvSeries"]
/// }
class CloudStreamPluginModel {
  /// URL to download the plugin (.cs3 file)
  final String url;

  /// Plugin status (1 = active, 0 = inactive)
  final int status;

  /// Plugin version number
  final int version;

  /// API version compatibility
  final int apiVersion;

  /// Display name of the plugin
  final String name;

  /// Internal identifier for the plugin
  final String internalName;

  /// List of plugin authors
  final List<String> authors;

  /// Description of the plugin
  final String? description;

  /// Language code for the plugin content
  final String language;

  /// URL to the plugin icon
  final String? iconUrl;

  /// List of supported TV/content types
  final List<String> tvTypes;

  const CloudStreamPluginModel({
    required this.url,
    this.status = 1,
    this.version = 1,
    this.apiVersion = 1,
    required this.name,
    required this.internalName,
    this.authors = const [],
    this.description,
    this.language = 'en',
    this.iconUrl,
    this.tvTypes = const [],
  });

  /// Creates a CloudStreamPluginModel from JSON
  factory CloudStreamPluginModel.fromJson(Map<String, dynamic> json) {
    return CloudStreamPluginModel(
      url: json['url'] as String? ?? '',
      status: json['status'] as int? ?? 1,
      version: json['version'] as int? ?? 1,
      apiVersion: json['apiVersion'] as int? ?? 1,
      name: json['name'] as String? ?? 'Unknown Plugin',
      internalName: json['internalName'] as String? ?? '',
      authors:
          (json['authors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: json['description'] as String?,
      language: json['language'] as String? ?? 'en',
      iconUrl: json['iconUrl'] as String?,
      tvTypes:
          (json['tvTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// Converts this model to JSON
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'status': status,
      'version': version,
      'apiVersion': apiVersion,
      'name': name,
      'internalName': internalName,
      'authors': authors,
      'description': description,
      'language': language,
      'iconUrl': iconUrl,
      'tvTypes': tvTypes,
    };
  }

  /// Returns true if this plugin is active
  bool get isActive => status == 1;

  /// Returns the version as a string (e.g., "1.0.0")
  String get versionString => '$version.0.0';

  /// Determines the ItemType based on tvTypes
  ///
  /// Maps CloudStream tvTypes to our ItemType enum:
  /// - "Movie" -> movie
  /// - "TvSeries", "TvShow" -> tvShow
  /// - "Anime", "AnimeMovie", "OVA" -> anime
  /// - "Cartoon" -> cartoon
  /// - "Documentary" -> documentary
  /// - "Live", "Livestream" -> livestream
  /// - "Manga" -> manga
  /// - "Novel" -> novel
  /// - "NSFW" -> nsfw
  ItemType get itemType {
    final types = tvTypes.map((t) => t.toLowerCase()).toSet();

    // Check for anime types first
    if (types.contains('anime') ||
        types.contains('animemovie') ||
        types.contains('ova')) {
      return ItemType.anime;
    }

    // Check for other specific types
    if (types.contains('movie')) return ItemType.movie;
    if (types.contains('tvseries') || types.contains('tvshow')) {
      return ItemType.tvShow;
    }
    if (types.contains('cartoon')) return ItemType.cartoon;
    if (types.contains('documentary')) return ItemType.documentary;
    if (types.contains('live') || types.contains('livestream')) {
      return ItemType.livestream;
    }
    if (types.contains('manga')) return ItemType.manga;
    if (types.contains('novel')) return ItemType.novel;
    if (types.contains('nsfw')) return ItemType.nsfw;

    // Default to anime for video content
    return ItemType.anime;
  }

  /// Converts this plugin to an ExtensionEntity
  ExtensionEntity toExtensionEntity() {
    return ExtensionModel(
      id: internalName.isNotEmpty
          ? internalName
          : name.toLowerCase().replaceAll(' ', '-'),
      name: name,
      version: versionString,
      type: ExtensionType.cloudstream,
      itemType: itemType,
      language: language,
      isInstalled: false,
      isNsfw: tvTypes.any((t) => t.toLowerCase() == 'nsfw'),
      iconUrl: iconUrl,
      apkUrl: url, // .cs3 file URL
      description: description,
    );
  }
}
