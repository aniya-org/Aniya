/// Dialog widget for tracking media progress across multiple services
///
/// CREDIT: Based on common Flutter dialog patterns and tracking service
/// implementations found in open source anime/manga apps.
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/enums/tracking_service.dart';
import '../../../../core/services/tracking/tracking_service_interface.dart';

/// Dialog that allows users to track their progress in multiple services
class TrackingDialog extends StatefulWidget {
  final MediaEntity media;
  final int? currentEpisode;
  final int? currentChapter;
  final double? progress;
  final bool? completed;
  final List<TrackingServiceInterface> availableServices;

  const TrackingDialog({
    required this.media,
    this.currentEpisode,
    this.currentChapter,
    this.progress,
    this.completed,
    required this.availableServices,
    super.key,
  });

  @override
  State<TrackingDialog> createState() => _TrackingDialogState();
}

class _TrackingDialogState extends State<TrackingDialog> {
  final Map<TrackingService, bool> _selectedServices = {};
  final Map<TrackingService, bool> _isLoading = {};
  final Map<TrackingService, String?> _errors = {};
  late final Box _trackingBox;

  @override
  void initState() {
    super.initState();
    _loadTrackingPreferences();
  }

  void _loadTrackingPreferences() async {
    // Get or create the tracking preferences box
    _trackingBox = await Hive.openBox('tracking_preferences');

    // Initialize all services
    for (final service in widget.availableServices) {
      final serviceType = service.serviceType;
      _isLoading[serviceType] = false;
      _errors[serviceType] = null;

      // Load previously selected services for this media item
      final trackingKey = _getTrackingKey(widget.media.id, serviceType);
      _selectedServices[serviceType] = _trackingBox.get(
        trackingKey,
        defaultValue: false,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  String _getTrackingKey(String mediaId, TrackingService service) {
    return '${mediaId}_${service.name}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text('Track "${widget.media.title}"'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose which services to track your progress in:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Progress summary
            if (_hasProgressInfo()) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Progress',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildProgressSummary(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Service selection
            ...widget.availableServices.map(
              (service) => _buildServiceTile(service),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedServices.values.any((selected) => selected)
              ? _trackProgress
              : null,
          child: const Text('Track'),
        ),
      ],
    );
  }

  bool _hasProgressInfo() {
    return widget.currentEpisode != null ||
        widget.currentChapter != null ||
        widget.progress != null ||
        widget.completed == true;
  }

  Widget _buildProgressSummary() {
    final List<String> progressParts = [];

    if (widget.currentEpisode != null) {
      progressParts.add('Episode ${widget.currentEpisode}');
    }

    if (widget.currentChapter != null) {
      progressParts.add('Chapter ${widget.currentChapter}');
    }

    if (widget.progress != null && widget.progress! > 0) {
      progressParts.add('${(widget.progress! * 100).round()}% complete');
    }

    if (widget.completed == true) {
      progressParts.add('Completed');
    }

    return Text(
      progressParts.isEmpty
          ? 'No progress recorded'
          : progressParts.join(' • '),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget _buildServiceTile(TrackingServiceInterface service) {
    final serviceType = service.serviceType;
    final isSelected = _selectedServices[serviceType] ?? false;
    final isLoading = _isLoading[serviceType] ?? false;
    final error = _errors[serviceType];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: error != null
              ? Colors.red.withOpacity(0.5)
              : isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        title: Row(
          children: [
            _getServiceIcon(serviceType),
            const SizedBox(width: 8),
            Text(_getServiceName(serviceType)),
            if (isLoading) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        subtitle: error != null
            ? Text(error, style: TextStyle(color: Colors.red, fontSize: 12))
            : Text(
                service.isAuthenticated
                    ? 'Authenticated'
                    : 'Not authenticated - tap to authenticate',
                style: TextStyle(
                  color: service.isAuthenticated ? Colors.green : Colors.orange,
                  fontSize: 12,
                ),
              ),
        value: isSelected,
        onChanged: isLoading
            ? null
            : (value) async {
                if (!service.isAuthenticated && value == true) {
                  // Try to authenticate first
                  setState(() {
                    _isLoading[serviceType] = true;
                  });

                  try {
                    final authenticated = await service.authenticate();
                    if (authenticated) {
                      setState(() {
                        _selectedServices[serviceType] = true;
                        _errors[serviceType] = null;
                      });
                    } else {
                      setState(() {
                        _errors[serviceType] = 'Authentication failed';
                      });
                    }
                  } catch (e) {
                    setState(() {
                      _errors[serviceType] = 'Authentication error: $e';
                    });
                  } finally {
                    setState(() {
                      _isLoading[serviceType] = false;
                    });
                  }
                } else {
                  setState(() {
                    _selectedServices[serviceType] = value ?? false;
                    _errors[serviceType] = null;
                  });
                }
              },
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _getServiceIcon(TrackingService service) {
    const iconSize = 20.0;
    switch (service) {
      case TrackingService.anilist:
        return Icon(
          Icons.list_alt,
          size: iconSize,
          color: const Color(0xFF02A9FF),
        );
      case TrackingService.mal:
        return Icon(Icons.book, size: iconSize, color: const Color(0xFF2E51A2));
      case TrackingService.simkl:
        return Icon(Icons.tv, size: iconSize, color: const Color(0xFF0D0D0D));
      default:
        return Icon(Icons.track_changes, size: iconSize);
    }
  }

  String _getServiceName(TrackingService service) {
    switch (service) {
      case TrackingService.anilist:
        return 'AniList';
      case TrackingService.mal:
        return 'MyAnimeList';
      case TrackingService.simkl:
        return 'Simkl';
      default:
        return service.name;
    }
  }

  Future<void> _trackProgress() async {
    final selectedServices = widget.availableServices
        .where((service) => _selectedServices[service.serviceType] ?? false)
        .toList();

    if (selectedServices.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    // Show loading state
    setState(() {
      for (final service in selectedServices) {
        _isLoading[service.serviceType] = true;
        _errors[service.serviceType] = null;
      }
    });

    // Track progress in selected services
    final trackingUpdate = TrackingProgressUpdate(
      mediaId: widget.media.id,
      mediaTitle: widget.media.title,
      mediaType: widget.media.type,
      episode: widget.currentEpisode,
      chapter: widget.currentChapter,
      progress: widget.progress,
      completed: widget.completed,
    );

    final results = <TrackingService, bool>{};

    for (final service in selectedServices) {
      try {
        final success = await service.updateProgress(trackingUpdate);
        results[service.serviceType] = success;

        if (!success) {
          setState(() {
            _errors[service.serviceType] = 'Failed to update progress';
          });
        }
      } catch (e) {
        setState(() {
          _errors[service.serviceType] = 'Error: $e';
        });
        results[service.serviceType] = false;
      }
    }

    // Hide loading state
    setState(() {
      for (final service in selectedServices) {
        _isLoading[service.serviceType] = false;
      }
    });

    // Show success message
    final successCount = results.values.where((success) => success).length;
    final totalCount = results.length;

    if (successCount == totalCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Progress tracked successfully in $successCount service${successCount == 1 ? '' : 's'}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Progress tracked in $successCount of $totalCount services',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to track progress in any service'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Save tracking preferences for this media item
    for (final service in widget.availableServices) {
      final serviceType = service.serviceType;
      final trackingKey = _getTrackingKey(widget.media.id, serviceType);
      final isSelected = _selectedServices[serviceType] ?? false;
      await _trackingBox.put(trackingKey, isSelected);
    }

    Navigator.of(context).pop();
  }
}

/// Shows the tracking dialog for a media item
Future<void> showTrackingDialog(
  BuildContext context,
  MediaEntity media, {
  int? currentEpisode,
  int? currentChapter,
  double? progress,
  bool? completed,
  required List<TrackingServiceInterface> availableServices,
}) {
  return showDialog(
    context: context,
    builder: (context) => TrackingDialog(
      media: media,
      currentEpisode: currentEpisode,
      currentChapter: currentChapter,
      progress: progress,
      completed: completed,
      availableServices: availableServices,
    ),
  );
}
