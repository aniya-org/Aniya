# ViewModels Implementation Summary

This document provides an overview of all ViewModels implemented for the Aniya application following the MVVM pattern.

## Implemented ViewModels

### 1. HomeViewModel
**Location:** `lib/features/home/presentation/viewmodels/home_viewmodel.dart`

**Purpose:** Manages the home screen state, displaying trending content and continue watching items.

**Key Features:**
- Loads trending anime and manga
- Fetches continue watching items from library
- Handles loading and error states
- Supports pull-to-refresh functionality

**Dependencies:**
- GetTrendingMediaUseCase
- GetLibraryItemsUseCase

---

### 2. MediaDetailsViewModel
**Location:** `lib/features/media_details/presentation/viewmodels/media_details_viewmodel.dart`

**Purpose:** Manages media detail screen state, including episodes/chapters and library operations.

**Key Features:**
- Loads detailed media information
- Fetches episodes for anime/TV shows or chapters for manga
- Handles adding media to library
- Provides navigation hooks for playback/reading

**Dependencies:**
- GetMediaDetailsUseCase
- GetEpisodesUseCase
- GetChaptersUseCase
- AddToLibraryUseCase

---

### 3. ExtensionViewModel
**Location:** `lib/features/extensions/presentation/viewmodels/extension_viewmodel.dart`

**Purpose:** Manages extension management screen, handling installation and removal of extensions.

**Key Features:**
- Loads available and installed extensions
- Handles extension installation with progress tracking
- Manages extension uninstallation
- Supports all extension types (CloudStream, Aniyomi, Mangayomi, LnReader)

**Dependencies:**
- GetAvailableExtensionsUseCase
- GetInstalledExtensionsUseCase
- InstallExtensionUseCase
- UninstallExtensionUseCase

---

### 4. LibraryViewModel
**Location:** `lib/features/library/presentation/viewmodels/library_viewmodel.dart`

**Purpose:** Manages user's library screen with filtering and status updates.

**Key Features:**
- Loads library items with optional status filtering
- Updates library item status (watching, completed, etc.)
- Removes items from library
- Triggers tracking service sync on updates

**Dependencies:**
- GetLibraryItemsUseCase
- UpdateLibraryItemUseCase
- RemoveFromLibraryUseCase

---

### 5. SearchViewModel
**Location:** `lib/features/search/presentation/viewmodels/search_viewmodel.dart`

**Purpose:** Manages search functionality with debouncing and type filtering.

**Key Features:**
- Implements search with 500ms debouncing
- Supports type filtering (anime, manga, movie, TV show)
- Aggregates results from multiple extensions
- Handles search result clearing

**Dependencies:**
- SearchMediaUseCase

**Special Features:**
- Automatic debouncing to reduce API calls
- Searches across all media types when no filter is set

---

### 6. VideoPlayerViewModel
**Location:** `lib/features/video_player/presentation/viewmodels/video_player_viewmodel.dart`

**Purpose:** Manages video playback state, source selection, and progress tracking.

**Key Features:**
- Loads available video sources
- Handles source selection and URL extraction
- Tracks playback position
- Saves progress and marks episodes complete

**Dependencies:**
- GetVideoSourcesUseCase
- ExtractVideoUrlUseCase
- SavePlaybackPositionUseCase
- UpdateProgressUseCase

---

### 7. SettingsViewModel
**Location:** `lib/features/settings/presentation/viewmodels/settings_viewmodel.dart`

**Purpose:** Manages application settings and preferences.

**Key Features:**
- Theme mode selection (light, dark, OLED, system)
- Video quality preferences
- Auto-play next episode toggle
- NSFW extension visibility toggle
- Tracking service connection management

**Settings Managed:**
- Theme settings
- Video playback settings
- Extension preferences
- Tracking service connections

**Note:** Storage implementation (Hive/SharedPreferences) is marked as TODO for future implementation.

---

### 8. AuthViewModel
**Location:** `lib/features/auth/presentation/viewmodels/auth_viewmodel.dart`

**Purpose:** Manages authentication with tracking services (AniList, MAL, Simkl).

**Key Features:**
- Authenticates with tracking services
- Manages authentication tokens securely
- Tracks authenticated users per service
- Handles logout functionality
- Loads saved authentications on app start

**Dependencies:**
- AuthenticateTrackingServiceUseCase

**Security Features:**
- Token storage using flutter_secure_storage (marked as TODO)
- Per-service authentication management

---

## Common Patterns

All ViewModels follow these common patterns:

1. **State Management:** Extend `ChangeNotifier` for reactive state updates
2. **Error Handling:** Consistent error mapping from Failures to user-friendly messages
3. **Loading States:** Boolean flags for loading indicators
4. **Dependency Injection:** Constructor injection of use cases
5. **Immutability:** Private state with public getters

## Error Handling

All ViewModels implement a common `_mapFailureToMessage` method that converts domain layer Failures into user-friendly error messages:

- NetworkFailure → "Network error: {message}"
- ExtensionFailure → "Extension error: {message}"
- StorageFailure → "Storage error: {message}"
- AuthenticationFailure → "Authentication failed: {message}"
- Generic → "Error: {message}"

## Usage Example

```dart
// In a widget
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<HomeViewModel>();
    _viewModel.loadHomeData();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<HomeViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return CircularProgressIndicator();
          }
          
          if (viewModel.error != null) {
            return Text(viewModel.error!);
          }
          
          return ListView(
            children: [
              // Display trending anime
              ...viewModel.trendingAnime.map((anime) => MediaCard(anime)),
              // Display trending manga
              ...viewModel.trendingManga.map((manga) => MediaCard(manga)),
            ],
          );
        },
      ),
    );
  }
}
```

## Next Steps

1. Register ViewModels in dependency injection container (GetIt)
2. Implement UI screens that consume these ViewModels
3. Add unit tests for ViewModel logic
4. Implement property-based tests as specified in tasks
5. Complete TODO items for storage implementations

## Architecture Compliance

All ViewModels comply with CLEAN Architecture principles:
- ✅ Depend only on domain layer (entities, use cases, failures)
- ✅ No direct dependency on data layer
- ✅ No Flutter-specific logic beyond ChangeNotifier
- ✅ Testable in isolation
- ✅ Single Responsibility Principle
