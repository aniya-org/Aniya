import '../../../../core/domain/entities/extension_entity.dart';
import '../../../../core/domain/entities/media_entity.dart';
import '../../../../core/domain/entities/source_entity.dart';

/// Result returned when a source is selected from the source selection sheet.
class SourceSelectionResult {
  final SourceEntity source;
  final List<SourceEntity> allSources;
  final MediaEntity selectedMedia;
  final ExtensionEntity selectedExtension;

  const SourceSelectionResult({
    required this.source,
    required this.allSources,
    required this.selectedMedia,
    required this.selectedExtension,
  });
}
