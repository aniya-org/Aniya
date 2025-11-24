# Data Layer

This directory contains the data layer implementation following CLEAN Architecture principles.

## Models

All data models are located in `models/` directory and serve as DTOs (Data Transfer Objects) for serialization and deserialization.

### Implemented Models

1. **MediaModel** - Extends MediaEntity
   - JSON serialization/deserialization
   - Conversion from DMedia (extension bridge)
   - Conversion to MediaEntity

2. **EpisodeModel** - Extends EpisodeEntity
   - JSON serialization/deserialization
   - Conversion from DEpisode (extension bridge)
   - Conversion to EpisodeEntity

3. **ChapterModel** - Extends ChapterEntity
   - JSON serialization/deserialization
   - Conversion from DEpisode (extension bridge for manga)
   - Conversion to ChapterEntity

4. **ExtensionModel** - Extends ExtensionEntity
   - JSON serialization/deserialization
   - Conversion to ExtensionEntity
   - copyWith method for immutable updates

5. **LibraryItemModel** - Extends LibraryItemEntity
   - JSON serialization/deserialization
   - Nested MediaModel serialization
   - Conversion to LibraryItemEntity
   - copyWith method for immutable updates

6. **UserModel** - Extends UserEntity
   - JSON serialization/deserialization
   - Conversion to UserEntity
   - copyWith method for immutable updates

7. **VideoSourceModel** - Extends VideoSource
   - JSON serialization/deserialization
   - Conversion to VideoSource
   - copyWith method for immutable updates

## Usage

All models can be imported via the barrel file:

```dart
import 'package:aniya/core/data/models/models.dart';
```

### Example: JSON Serialization

```dart
// From JSON
final mediaModel = MediaModel.fromJson(jsonData);

// To JSON
final json = mediaModel.toJson();

// To Entity
final entity = mediaModel.toEntity();
```

### Example: Extension Bridge Integration

```dart
// From DMedia (extension bridge)
final mediaModel = MediaModel.fromDMedia(
  dMedia,
  sourceId: 'source1',
  sourceName: 'Test Source',
  type: MediaType.anime,
);

// From DEpisode (extension bridge)
final episodeModel = EpisodeModel.fromDEpisode(dEpisode, mediaId);
final chapterModel = ChapterModel.fromDEpisode(dEpisode, mediaId);
```

## Next Steps

- Implement data sources (remote and local)
- Implement repository implementations
- Add caching strategies
