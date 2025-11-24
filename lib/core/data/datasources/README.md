# Data Sources

This directory contains all data source implementations for the Aniya application.

## Overview

Data sources are responsible for fetching and storing data from various sources including:
- Remote APIs (extensions, tracking services, TMDB)
- Local storage (Hive, Isar)

## Implemented Data Sources

### 1. MediaRemoteDataSource
**File:** `media_remote_data_source.dart`

Integrates with DartotsuExtensionBridge to fetch media content from extensions.

**Features:**
- Search media across extensions
- Get media details
- Fetch episodes and chapters
- Get trending and popular content

**Requirements:** 2.1, 4.4, 5.1

### 2. MediaLocalDataSource
**File:** `media_local_data_source.dart`

Implements Hive-based caching for media content.

**Features:**
- Cache media items
- Retrieve cached media
- Clear cache
- Remove specific cached items

**Requirements:** 12.2

### 3. ExtensionDataSource
**File:** `extension_data_source.dart`

Manages extensions via DartotsuExtensionBridge.

**Features:**
- Get available extensions by type and item type
- Get installed extensions
- Install/uninstall extensions
- Update extensions
- Check for updates

**Supported Types:**
- CloudStream
- Aniyomi
- Mangayomi
- LnReader

**Requirements:** 2.2, 2.3, 2.4, 2.5

### 4. LibraryLocalDataSource
**File:** `library_local_data_source.dart`

Implements Hive-based library storage.

**Features:**
- Get library items (all or by status)
- Add items to library
- Update library items
- Remove items from library
- Update progress

**Requirements:** 6.1, 12.1

### 5. TrackingDataSource
**File:** `tracking_data_source.dart`

Integrates with tracking services (AniList, MAL, Simkl).

**Features:**
- Authenticate with tracking services
- Sync progress
- Fetch remote library
- Update status
- Secure token storage

**Supported Services:**
- AniList
- MyAnimeList (MAL)
- Simkl

**Requirements:** 7.1, 7.2, 7.3

### 6. TMDBDataSource
**File:** `tmdb_data_source.dart`

Integrates with TMDB API for movie and TV show metadata.

**Features:**
- Get movie/TV show details
- Search movies and TV shows
- Response caching
- Cast, crew, trailers, and recommendations

**Requirements:** 8.1, 8.4

## Usage

Import all data sources:
```dart
import 'package:aniya/core/data/datasources/datasources.dart';
```

Or import specific data sources:
```dart
import 'package:aniya/core/data/datasources/media_remote_data_source.dart';
```

## Dependencies

- **dartotsu_extension_bridge**: Extension system integration
- **dio**: HTTP client for API calls
- **hive**: Local key-value storage
- **flutter_secure_storage**: Secure token storage

## Next Steps

These data sources will be used by repository implementations in the next task (Task 12).
