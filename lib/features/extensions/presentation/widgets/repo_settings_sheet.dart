import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../../../core/domain/entities/extension_entity.dart';
import '../../../../core/data/models/repository_config_model.dart';

/// A Material Design 3 bottom sheet for managing repository URLs
///
/// Displays input fields for anime, manga, and novel repository URLs.
/// On Android, shows extension type tabs (Mangayomi/Aniyomi).
///
/// Requirements: 2.1, 11.1
class RepoSettingsSheet extends StatefulWidget {
  /// Current repository configuration
  final RepositoryConfig? currentConfig;

  /// Current extension type (for Android tab selection)
  final ExtensionType currentExtensionType;

  /// Callback when configuration is saved
  final void Function(ExtensionType type, RepositoryConfig config)? onSave;

  /// Callback when extension type changes (Android only)
  final void Function(ExtensionType type)? onExtensionTypeChanged;

  const RepoSettingsSheet({
    super.key,
    this.currentConfig,
    this.currentExtensionType = ExtensionType.mangayomi,
    this.onSave,
    this.onExtensionTypeChanged,
  });

  /// Shows the RepoSettingsSheet as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    RepositoryConfig? currentConfig,
    ExtensionType currentExtensionType = ExtensionType.mangayomi,
    void Function(ExtensionType type, RepositoryConfig config)? onSave,
    void Function(ExtensionType type)? onExtensionTypeChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => RepoSettingsSheet(
        currentConfig: currentConfig,
        currentExtensionType: currentExtensionType,
        onSave: onSave,
        onExtensionTypeChanged: onExtensionTypeChanged,
      ),
    );
  }

  @override
  State<RepoSettingsSheet> createState() => _RepoSettingsSheetState();
}

class _RepoSettingsSheetState extends State<RepoSettingsSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _animeUrlController;
  late final TextEditingController _mangaUrlController;
  late final TextEditingController _novelUrlController;
  // CloudStream-specific controllers (Requirements 12.1, 12.4)
  late final TextEditingController _movieUrlController;
  late final TextEditingController _tvShowUrlController;
  late final TextEditingController _cartoonUrlController;
  late final TextEditingController _documentaryUrlController;
  late final TextEditingController _livestreamUrlController;
  late final TextEditingController _nsfwUrlController;

  late ExtensionType _selectedType;
  TabController? _tabController;

  final _formKey = GlobalKey<FormState>();
  bool _isAndroid = false;

  /// Returns true if the current extension type is CloudStream
  bool get _isCloudStream => _selectedType == ExtensionType.cloudstream;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.currentExtensionType;
    _animeUrlController = TextEditingController(
      text: widget.currentConfig?.animeRepoUrl ?? '',
    );
    _mangaUrlController = TextEditingController(
      text: widget.currentConfig?.mangaRepoUrl ?? '',
    );
    _novelUrlController = TextEditingController(
      text: widget.currentConfig?.novelRepoUrl ?? '',
    );
    // Initialize CloudStream-specific controllers
    _movieUrlController = TextEditingController(
      text: widget.currentConfig?.movieRepoUrl ?? '',
    );
    _tvShowUrlController = TextEditingController(
      text: widget.currentConfig?.tvShowRepoUrl ?? '',
    );
    _cartoonUrlController = TextEditingController(
      text: widget.currentConfig?.cartoonRepoUrl ?? '',
    );
    _documentaryUrlController = TextEditingController(
      text: widget.currentConfig?.documentaryRepoUrl ?? '',
    );
    _livestreamUrlController = TextEditingController(
      text: widget.currentConfig?.livestreamRepoUrl ?? '',
    );
    _nsfwUrlController = TextEditingController(
      text: widget.currentConfig?.nsfwRepoUrl ?? '',
    );

    // Check if running on Android
    try {
      _isAndroid = Platform.isAndroid;
    } catch (_) {
      _isAndroid = false;
    }

    // Initialize tab controller for Android (3 tabs: Mangayomi, Aniyomi, CloudStream)
    if (_isAndroid) {
      _tabController = TabController(
        length: 3,
        vsync: this,
        initialIndex: _getTabIndex(_selectedType),
      );
      _tabController!.addListener(_onTabChanged);
    }
  }

  int _getTabIndex(ExtensionType type) {
    switch (type) {
      case ExtensionType.mangayomi:
        return 0;
      case ExtensionType.aniyomi:
        return 1;
      case ExtensionType.cloudstream:
        return 2;
      default:
        return 0;
    }
  }

  ExtensionType _getTypeFromIndex(int index) {
    switch (index) {
      case 0:
        return ExtensionType.mangayomi;
      case 1:
        return ExtensionType.aniyomi;
      case 2:
        return ExtensionType.cloudstream;
      default:
        return ExtensionType.mangayomi;
    }
  }

  @override
  void dispose() {
    _animeUrlController.dispose();
    _mangaUrlController.dispose();
    _novelUrlController.dispose();
    _movieUrlController.dispose();
    _tvShowUrlController.dispose();
    _cartoonUrlController.dispose();
    _documentaryUrlController.dispose();
    _livestreamUrlController.dispose();
    _nsfwUrlController.dispose();
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController != null && !_tabController!.indexIsChanging) {
      setState(() {
        _selectedType = _getTypeFromIndex(_tabController!.index);
      });
      widget.onExtensionTypeChanged?.call(_selectedType);
    }
  }

  String? _validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URLs are optional
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Please enter a valid URL';
    }
    if (!uri.scheme.startsWith('http')) {
      return 'URL must start with http:// or https://';
    }
    return null;
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      final config = RepositoryConfig(
        animeRepoUrl: _animeUrlController.text.isEmpty
            ? null
            : _animeUrlController.text.trim(),
        mangaRepoUrl: _mangaUrlController.text.isEmpty
            ? null
            : _mangaUrlController.text.trim(),
        novelRepoUrl: _novelUrlController.text.isEmpty
            ? null
            : _novelUrlController.text.trim(),
        // CloudStream-specific URLs (Requirements 12.1, 12.4)
        movieRepoUrl: _movieUrlController.text.isEmpty
            ? null
            : _movieUrlController.text.trim(),
        tvShowRepoUrl: _tvShowUrlController.text.isEmpty
            ? null
            : _tvShowUrlController.text.trim(),
        cartoonRepoUrl: _cartoonUrlController.text.isEmpty
            ? null
            : _cartoonUrlController.text.trim(),
        documentaryRepoUrl: _documentaryUrlController.text.isEmpty
            ? null
            : _documentaryUrlController.text.trim(),
        livestreamRepoUrl: _livestreamUrlController.text.isEmpty
            ? null
            : _livestreamUrlController.text.trim(),
        nsfwRepoUrl: _nsfwUrlController.text.isEmpty
            ? null
            : _nsfwUrlController.text.trim(),
      );
      widget.onSave?.call(_selectedType, config);
      Navigator.of(context).pop();
    }
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Repository Settings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Extension type tabs (Android only)
                // Includes CloudStream tab (Requirements 12.1)
                if (_isAndroid && _tabController != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Mangayomi'),
                        Tab(text: 'Aniyomi'),
                        Tab(text: 'CloudStream'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info text
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Enter repository URLs to fetch extensions. Leave empty to use default repositories.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Anime Repository URL
                          _buildUrlField(
                            controller: _animeUrlController,
                            label: 'Anime Repository URL',
                            hint: 'https://example.com/anime-repo.json',
                            icon: Icons.play_circle_outline,
                          ),

                          const SizedBox(height: 16),

                          // Manga Repository URL
                          _buildUrlField(
                            controller: _mangaUrlController,
                            label: 'Manga Repository URL',
                            hint: 'https://example.com/manga-repo.json',
                            icon: Icons.menu_book_outlined,
                          ),

                          const SizedBox(height: 16),

                          // Novel Repository URL
                          _buildUrlField(
                            controller: _novelUrlController,
                            label: 'Novel Repository URL',
                            hint: 'https://example.com/novel-repo.json',
                            icon: Icons.auto_stories_outlined,
                          ),

                          // CloudStream-specific repository URLs (Requirements 12.1, 12.4)
                          if (_isCloudStream) ...[
                            const SizedBox(height: 16),

                            // Movie Repository URL
                            _buildUrlField(
                              controller: _movieUrlController,
                              label: 'Movie Repository URL',
                              hint: 'https://example.com/movie-repo.json',
                              icon: Icons.movie_outlined,
                            ),

                            const SizedBox(height: 16),

                            // TV Show Repository URL
                            _buildUrlField(
                              controller: _tvShowUrlController,
                              label: 'TV Show Repository URL',
                              hint: 'https://example.com/tvshow-repo.json',
                              icon: Icons.tv_outlined,
                            ),

                            const SizedBox(height: 16),

                            // Cartoon Repository URL
                            _buildUrlField(
                              controller: _cartoonUrlController,
                              label: 'Cartoon Repository URL',
                              hint: 'https://example.com/cartoon-repo.json',
                              icon: Icons.animation_outlined,
                            ),

                            const SizedBox(height: 16),

                            // Documentary Repository URL
                            _buildUrlField(
                              controller: _documentaryUrlController,
                              label: 'Documentary Repository URL',
                              hint: 'https://example.com/documentary-repo.json',
                              icon: Icons.video_library_outlined,
                            ),

                            const SizedBox(height: 16),

                            // Livestream Repository URL
                            _buildUrlField(
                              controller: _livestreamUrlController,
                              label: 'Livestream Repository URL',
                              hint: 'https://example.com/livestream-repo.json',
                              icon: Icons.live_tv_outlined,
                            ),

                            const SizedBox(height: 16),

                            // NSFW Repository URL
                            _buildUrlField(
                              controller: _nsfwUrlController,
                              label: 'NSFW Repository URL',
                              hint: 'https://example.com/nsfw-repo.json',
                              icon: Icons.no_adult_content_outlined,
                            ),
                          ],

                          const SizedBox(height: 32),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _handleCancel,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _handleSave,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  child: const Text('Save'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUrlField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: _validateUrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
