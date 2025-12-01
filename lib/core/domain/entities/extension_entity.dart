import 'package:equatable/equatable.dart';

/// The type of extension ecosystem
enum ExtensionType { cloudstream, aniyomi, mangayomi, lnreader }

/// The media category type for an extension
enum ItemType {
  manga,
  anime,
  novel,
  movie,
  tvShow,
  cartoon,
  documentary,
  livestream,
  nsfw;

  @override
  String toString() {
    switch (this) {
      case ItemType.manga:
        return 'Manga';
      case ItemType.anime:
        return 'Anime';
      case ItemType.novel:
        return 'Novel';
      case ItemType.movie:
        return 'Movie';
      case ItemType.tvShow:
        return 'TV Show';
      case ItemType.cartoon:
        return 'Cartoon';
      case ItemType.documentary:
        return 'Documentary';
      case ItemType.livestream:
        return 'Livestream';
      case ItemType.nsfw:
        return 'NSFW';
    }
  }
}

/// Entity representing an extension that provides content sources
class ExtensionEntity extends Equatable {
  /// Unique identifier for the extension
  final String id;

  /// Display name of the extension
  final String name;

  /// Current installed version
  final String version;

  /// Latest available version from repository
  final String? versionLast;

  /// The extension ecosystem type (CloudStream, Aniyomi, etc.)
  final ExtensionType type;

  /// The media category this extension provides (anime, manga, novel, etc.)
  final ItemType itemType;

  /// Language code for the extension content
  final String language;

  /// Whether the extension is currently installed
  final bool isInstalled;

  /// Whether the extension contains NSFW content
  final bool isNsfw;

  /// Whether an update is available for this extension
  final bool hasUpdate;

  /// URL to the extension icon
  final String? iconUrl;

  /// URL to download the extension package (APK)
  final String? apkUrl;

  /// Description of the extension
  final String? description;

  /// Whether this extension can be executed on desktop platforms.
  /// For CloudStream: true if plugin has JS code, false if DEX-only.
  /// Null means unknown (e.g., not yet checked or not applicable).
  final bool? isExecutableOnDesktop;

  const ExtensionEntity({
    required this.id,
    required this.name,
    required this.version,
    this.versionLast,
    required this.type,
    this.itemType = ItemType.anime,
    required this.language,
    required this.isInstalled,
    required this.isNsfw,
    this.hasUpdate = false,
    this.iconUrl,
    this.apkUrl,
    this.description,
    this.isExecutableOnDesktop,
  });

  /// Creates a copy of this extension with the given fields replaced.
  ExtensionEntity copyWith({
    String? id,
    String? name,
    String? version,
    String? versionLast,
    ExtensionType? type,
    ItemType? itemType,
    String? language,
    bool? isInstalled,
    bool? isNsfw,
    bool? hasUpdate,
    String? iconUrl,
    String? apkUrl,
    String? description,
    bool? isExecutableOnDesktop,
  }) {
    return ExtensionEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      versionLast: versionLast ?? this.versionLast,
      type: type ?? this.type,
      itemType: itemType ?? this.itemType,
      language: language ?? this.language,
      isInstalled: isInstalled ?? this.isInstalled,
      isNsfw: isNsfw ?? this.isNsfw,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      iconUrl: iconUrl ?? this.iconUrl,
      apkUrl: apkUrl ?? this.apkUrl,
      description: description ?? this.description,
      isExecutableOnDesktop:
          isExecutableOnDesktop ?? this.isExecutableOnDesktop,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    version,
    versionLast,
    type,
    itemType,
    language,
    isInstalled,
    isNsfw,
    hasUpdate,
    iconUrl,
    apkUrl,
    description,
    isExecutableOnDesktop,
  ];
}
