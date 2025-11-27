import '../domain/entities/extension_entity.dart';

/// Maps media types to compatible extension types
class ExtensionCompatibilityMapper {
  /// Get compatible extension types for a given media item type
  static List<ExtensionType> getCompatibleExtensionTypes(ItemType mediaType) {
    switch (mediaType) {
      case ItemType.anime:
        return [
          ExtensionType.aniyomi,
          ExtensionType.mangayomi,
          ExtensionType.cloudstream,
        ];
      case ItemType.manga:
        return [ExtensionType.mangayomi, ExtensionType.aniyomi];
      case ItemType.novel:
        return [ExtensionType.lnreader];
      case ItemType.movie:
        return [ExtensionType.cloudstream];
      case ItemType.tvShow:
        return [ExtensionType.cloudstream];
      case ItemType.cartoon:
        return [ExtensionType.cloudstream];
      case ItemType.documentary:
        return [ExtensionType.cloudstream];
      case ItemType.livestream:
        return [ExtensionType.cloudstream];
      case ItemType.nsfw:
        return [
          ExtensionType.aniyomi,
          ExtensionType.mangayomi,
          ExtensionType.cloudstream,
        ];
    }
  }

  /// Check if an extension is compatible with a given media type
  static bool isExtensionCompatible(
    ExtensionEntity extension,
    ItemType mediaType,
  ) {
    final compatibleTypes = getCompatibleExtensionTypes(mediaType);
    return compatibleTypes.contains(extension.type);
  }

  /// Filter extensions by media type compatibility
  static List<ExtensionEntity> filterCompatibleExtensions(
    List<ExtensionEntity> extensions,
    ItemType mediaType,
  ) {
    return extensions
        .where((ext) => isExtensionCompatible(ext, mediaType))
        .toList();
  }
}
