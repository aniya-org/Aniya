/// Enum representing the steps in the episode/chapter source selection workflow
enum EpisodeSourceSelectionStep {
  /// Step 1: User selects an extension to search within
  selectExtension,

  /// Step 2: User searches for media or confirms automatic search result
  searchMedia,

  /// Step 3: User selects a source to watch/read from
  selectSource,
}
