## Goals
- Add an extension/source selector to Episodes/Chapters tabs.
- When an extension is selected, list episodes/chapters from that extension first.
- While extension-first items are shown, concurrently enhance them with aggregated metadata; only show aggregation for items that the selected extension actually has.
- If no extension is selected, show today’s behavior (full aggregated list).

## Key Behavior
- Default: aggregated list across providers (current behavior).
- Extension selected: render the extension’s episode/chapter list immediately; start background aggregation; merge alternative metadata per item number for only the items present in the extension list.
- UI shows lightweight “enhancing…” feedback while aggregation runs.

## Affected Files
- `lib/features/details/presentation/screens/tmdb_details_screen.dart`
- `lib/features/details/presentation/screens/anime_manga_details_screen.dart`

## Dependencies & Existing Building Blocks
- Extensions inventory: `ExtensionsController` via GetX provides installed `ExtensionEntity` items.
- Extension search+scrape: `ExtensionSearchRepository` for finding the media within an extension and scraping per-episode sources.
- Extension episodes/chapters: `MediaRepository.getEpisodes(mediaId, sourceId)` / `getChapters(mediaId, sourceId)` (bridge-backed) for listing items from the selected extension.
- Cross-provider aggregation: `ExternalRemoteDataSource` + `DataAggregator` for fetching and merging external provider metadata.
- Episode/Chapter models support `alternativeData` for provider-specific overlays (`lib/core/domain/entities/episode_entity.dart`).

## UI Changes
- Add a compact selector row above the list:
  - Label `Source` + `DropdownButton` (or `PopupMenuButton`) listing installed extensions filtered by item type.
  - First option: `All Sources` (no extension → full aggregation).
  - Subsequent options: installed extension names (icon if available).
- Show a subtle inline progress indicator when extension items are being enhanced.

## TMDB Details Screen
- State additions:
  - `ExtensionEntity? _selectedExtension`
  - `MediaEntity? _selectedExtensionMedia`
  - `List<EpisodeEntity> _extensionEpisodes = []`
  - `bool _isLoadingExtension = false`
  - `bool _isEnhancingExtensionItems = false`
- Flow when selecting an extension:
  1. Set `_selectedExtension` and `_isLoadingExtension = true`.
  2. Use `ExtensionSearchRepository.searchMedia(title, extension, page:1)`; choose best match (top result).
  3. Fetch episodes from the extension: `MediaRepository.getEpisodes(selectedMedia.id, extension.id)`; set `_extensionEpisodes`, render immediately (basic info).
  4. Start enhancement: build a `MediaEntity` for the selected extension (`sourceId = extension.id`), call `ExternalRemoteDataSource.getEpisodes(media)` to obtain an aggregated list across external providers.
  5. For each extension episode, locate matching aggregated episode by episode number (or season+episode when available) and merge `alternativeData` from matched providers into the extension episode (only for intersection items). Set `_isEnhancingExtensionItems = false` when done.
- Rendering:
  - If `_selectedExtension == null`: current tabs unchanged; keep season chips and aggregated list (`_aggregatedEpisodes`).
  - If `_selectedExtension != null`: show the selector row + extension episode list; hide “multi-source enhanced” banner; optionally keep season chips only if extension episodes carry season info; otherwise render a flat list.

## Anime/Manga Details Screen
- Episodes (Anime): mirror the TMDB pattern.
- Chapters (Manga/Novel): same pattern but use `MediaRepository.getChapters` for the extension list.
- State additions:
  - Shared: `_selectedExtension`, `_selectedExtensionMedia`, `_extensionEpisodes`, `_extensionChapters`, `_isLoadingExtension`, `_isEnhancingExtensionItems`.
- Rendering rules:
  - Episodes tab: when extension selected, render `_extensionEpisodes` with basic info; enhance thumbnails and dates via `alternativeData` once aggregation finishes.
  - Chapters tab: when extension selected, render `_extensionChapters` only; enhance release dates via aggregation where available; do not show aggregated-only chapters.
  - If no extension selected: preserve current season/page grouping logic and aggregated content.

## Enhancement Logic (Intersection-Only Aggregation)
- Matching: use episode/chapter `number` as the primary key; fall back to season+episode matching if present (season-aware using the logic in `DataAggregator._findMatchingEpisode`).
- Populate `EpisodeEntity.alternativeData` for each extension item with provider-specific `EpisodeData` (thumbnail, air date, title) from external providers.
- Thumbnails selection: reuse existing `_resolveEpisodeThumbnail` priority (`anime_manga_details_screen.dart:2106`…2119); this means once `alternativeData` is present, the UI automatically picks best thumbnails by provider preference.

## AnymeX Reference Mapping
- Follow the interaction pattern from `ref/AnymeX/lib/screens/anime/widgets/episode_section.dart`:
  - Build source dropdown from installed extensions.
  - On change: remap title → select media in extension → fetch details → list episodes quickly.
- Our implementation stays within the current app’s DI and widgets; we are not adopting GetX state for these screens, only using `ExtensionsController` to obtain inventory.

## Edge Cases
- No installed extensions: selector shows `All Sources` only.
- Extension search returns no results: show a small notice (“No match in this extension”) and revert to aggregated view or keep empty list.
- Large series: enhancement runs in the background; keep the UI responsive; avoid blocking scroll.
- Season chips when extension has no season data: hide season filter while `_selectedExtension` is set (flat list).

## Verification
- Unit-check matching: test a few episode numbers to ensure enhancement keys match.
- Manual run-through:
  - Default aggregated view still renders.
  - Select extension → immediate base list appears; enhancement indicator shows; thumbnails and dates populate progressively.
  - Chapters tab behaves similarly.
- File references useful while implementing:
  - TMDB episodes aggregation entry: `lib/features/details/presentation/screens/tmdb_details_screen.dart:614`…`686`.
  - Episode card and thumbnail resolution: `lib/features/details/presentation/screens/anime_manga_details_screen.dart:1196`…`1263` and `2106`…`2119`.
  - Bridge-backed extension episodes: `lib/core/data/datasources/media_remote_data_source.dart:158`…`182`.
  - External aggregation fetch: `lib/core/data/datasources/external_remote_data_source.dart:596`…`759`.
  - AnymeX dropdown example: see `ref/AnymeX/lib/screens/anime/widgets/episode_section.dart`.

## Implementation Notes
- Use `sl<ExtensionSearchRepository>()`, `sl<MediaRepository>()`, `sl<ExternalRemoteDataSource>()`, and `Get.find<ExtensionsController>()`.
- Keep existing tap-to-open `EpisodeSourceSelectionSheet` behavior; when extension is selected, the sheet will still allow picking any scraped source.
- Avoid comments in code; follow existing style and imports patterns.
