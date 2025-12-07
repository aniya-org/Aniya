/// Dialog widget for tracking media progress across multiple services
///
/// CREDIT: Based on common Flutter dialog patterns and tracking service
/// implementations found in open source anime/manga apps.
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/domain/entities/entities.dart';
import '../../../../core/enums/tracking_service.dart';
import '../../../../core/services/tracking/tracking_service_interface.dart';
import '../../../../core/services/tracking/service_id_mapper.dart';
import '../../../../core/utils/logger.dart';

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
  final Map<TrackingService, String?> _serviceIds = {};
  late final Box _trackingBox;

  @override
  void initState() {
    super.initState();
    _loadTrackingPreferences();
  }

  void _loadTrackingPreferences() async {
    // Get or create the tracking preferences box
    _trackingBox = await Hive.openBox('tracking_preferences');

    // Initialize the service ID mapper
    await ServiceIdMapper.initialize();

    // Initialize all services
    for (final service in widget.availableServices) {
      final serviceType = service.serviceType;
      _isLoading[serviceType] = false;
      _errors[serviceType] = null;
      _serviceIds[serviceType] = null;

      // Load previously selected services for this media item
      final trackingKey = _getTrackingKey(widget.media.id, serviceType);
      _selectedServices[serviceType] = _trackingBox.get(
        trackingKey,
        defaultValue: false,
      );
    }

    // Preload service IDs for authenticated services
    await _preloadServiceIds();

    if (mounted) {
      setState(() {});
    }
  }

  String _getTrackingKey(String mediaId, TrackingService service) {
    return '${mediaId}_${service.name}';
  }

  /// Preload service IDs for all authenticated services
  Future<void> _preloadServiceIds() async {
    for (final service in widget.availableServices) {
      if (service.isAuthenticated) {
        try {
          final serviceId = await ServiceIdMapper.getServiceId(
            widget.media,
            service.serviceType,
            availableServices: widget.availableServices,
          );
          _serviceIds[service.serviceType] = serviceId;
          Logger.info(
            'Preloaded ${service.serviceType.name} ID for "${widget.media.title}": $serviceId',
          );
        } catch (e) {
          Logger.error(
            'Failed to preload ${service.serviceType.name} ID for "${widget.media.title}"',
            error: e,
          );
        }
      }
    }
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
    final serviceId = _serviceIds[serviceType];

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
            Expanded(
              child: Text(
                _getServiceName(serviceType),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null)
              Text(
                error,
                style: TextStyle(color: Colors.red, fontSize: 12),
              )
            else if (!service.isAuthenticated)
              Text(
                'Not authenticated - tap to authenticate',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              )
            else if (serviceId != null)
              Text(
                'Service ID: $serviceId',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              )
            else if (_selectedServices[serviceType] == true)
              Text(
                'Searching for media...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              )
            else
              Text(
                'Authenticated - ready to track',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            if (!service.isAuthenticated && isSelected)
              Text(
                'Note: Please authenticate first',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        value: isSelected,
        onChanged: isLoading
            ? null
            : (value) async {
                if (!service.isAuthenticated && value == true) {
                  // Try to authenticate first
                  setState(() {
                    _isLoading[serviceType] = true;
                    _errors[serviceType] = null;
                  });

                  try {
                    final authenticated = await service.authenticate();
                    if (authenticated) {
                      // After successful authentication, try to get service ID
                      try {
                        final id = await ServiceIdMapper.getServiceId(
                          widget.media,
                          serviceType,
                          availableServices: widget.availableServices,
                        );
                        setState(() {
                          _selectedServices[serviceType] = true;
                          _serviceIds[serviceType] = id;
                          _errors[serviceType] = null;
                        });
                      } catch (e) {
                        Logger.warning(
                          'Could not pre-fetch service ID after authentication: $e',
                        );
                        setState(() {
                          _selectedServices[serviceType] = true;
                          _errors[serviceType] = null;
                        });
                      }
                    } else {
                      setState(() {
                        _errors[serviceType] = 'Authentication failed';
                      });
                    }
                  } catch (e) {
                    Logger.error('Authentication error', error: e);
                    setState(() {
                      _errors[serviceType] = 'Authentication error: ${e.toString().length > 50 ? e.toString().substring(0, 50) + '...' : e.toString()}';
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

    Logger.info('Tracking dialog: Selected services: ${selectedServices.map((s) => s.serviceType.name).join(', ')}');

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

    final results = <TrackingService, bool>{};

    for (final service in selectedServices) {
      Logger.info('Processing service: ${service.serviceType.name}, authenticated: ${service.isAuthenticated}');

      // Skip if not authenticated
      if (!service.isAuthenticated) {
        setState(() {
          _errors[service.serviceType] = 'Service not authenticated';
        });
        results[service.serviceType] = false;
        continue;
      }

      try {
        // Get or find the service-specific ID
        String? serviceId = _serviceIds[service.serviceType];

        if (serviceId == null) {
          // Try to get the service ID now
          setState(() {
            _errors[service.serviceType] = 'Finding media on service...';
          });

          try {
            serviceId = await ServiceIdMapper.getServiceId(
              widget.media,
              service.serviceType,
              availableServices: widget.availableServices,
            );

            if (serviceId != null) {
              setState(() {
                _serviceIds[service.serviceType] = serviceId;
                _errors[service.serviceType] = null;
              });
              Logger.info(
                'Found ${service.serviceType.name} ID for "${widget.media.title}": $serviceId',
              );
            }
          } catch (e) {
            Logger.error('Failed to get service ID', error: e);
            setState(() {
              _errors[service.serviceType] = 'Could not find media on service';
            });
            results[service.serviceType] = false;
            continue;
          }
        }

        if (serviceId == null) {
          setState(() {
            _errors[service.serviceType] = 'Media not found on service';
          });
          results[service.serviceType] = false;
          continue;
        }

        // Create media item for tracking with service-specific ID
        final mediaItem = TrackingMediaItem(
          id: serviceId,
          title: widget.media.title,
          mediaType: widget.media.type,
          coverImage: widget.media.coverImage,
          serviceIds: {service.serviceType.name: serviceId},
        );

        // Create progress update with service-specific ID
        final trackingUpdate = TrackingProgressUpdate(
          mediaId: serviceId,
          mediaTitle: widget.media.title,
          mediaType: widget.media.type,
          episode: widget.currentEpisode ?? 0,
          chapter: widget.currentChapter ?? 0,
          progress: widget.progress ?? 0.0,
          completed: widget.completed ?? false,
        );

        // First, check if item exists in watchlist
        var existsInWatchlist = false;
        try {
          Logger.info('Checking watchlist for ${service.serviceType.name}...');
          final watchlist = await service.getWatchlist();
          Logger.info('${service.serviceType.name} watchlist has ${watchlist.length} items');

          existsInWatchlist = watchlist.any((item) => item.id == serviceId);
          Logger.info('Item $serviceId exists in ${service.serviceType.name} watchlist: $existsInWatchlist');
        } catch (e) {
          Logger.warning('Failed to check watchlist for ${service.serviceType.name}: $e');
          // Continue with update even if watchlist check fails
        }

        // Add to watchlist if not exists
        if (!existsInWatchlist) {
          try {
            setState(() {
              _errors[service.serviceType] = 'Adding to watchlist...';
            });

            Logger.info('Adding ${widget.media.title} to ${service.serviceType.name} watchlist...');
            final added = await service.addToWatchlist(mediaItem);
            Logger.info('Added to watchlist result: $added');

            if (!added) {
              setState(() {
                _errors[service.serviceType] = 'Failed to add to watchlist';
              });
              results[service.serviceType] = false;
              continue;
            }
          } catch (e) {
            Logger.error('Failed to add to watchlist for ${service.serviceType.name}', error: e);
            setState(() {
              _errors[service.serviceType] = 'Watchlist error: ${e.toString().length > 30 ? e.toString().substring(0, 30) + '...' : e.toString()}';
            });
            results[service.serviceType] = false;
            continue;
          }
        }

        // Update progress
        setState(() {
          _errors[service.serviceType] = 'Updating progress...';
        });

        final success = await service.updateProgress(trackingUpdate);
        results[service.serviceType] = success;

        if (success) {
          setState(() {
            _errors[service.serviceType] = null;
          });
          Logger.info('Successfully updated progress on ${service.serviceType.name}');
        } else {
          setState(() {
            _errors[service.serviceType] = 'Failed to update progress';
          });
        }
      } catch (e) {
        Logger.error('Unexpected error in ${service.serviceType.name}', error: e);
        setState(() {
          _errors[service.serviceType] = 'Error: ${e.toString().length > 50 ? e.toString().substring(0, 50) + '...' : e.toString()}';
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

    // Show result message
    final successCount = results.values.where((success) => success).length;
    final totalCount = results.length;
    final failedServices = results.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key.name)
        .toList();

    if (successCount == totalCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Progress tracked successfully in $successCount service${successCount == 1 ? '' : 's'}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠ Tracked in $successCount of $totalCount services\nFailed: ${failedServices.join(', ')}',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✗ Failed to track progress in any service\nIssues: ${failedServices.join(', ')}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
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

    // Don't auto-close if there were errors so user can see them
    if (successCount > 0 || mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
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
