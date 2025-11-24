import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../constants/app_constants.dart';

/// Custom cache manager for images with configured cache duration
class ImageCacheManager {
  static const key = 'aniya_image_cache';

  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: Duration(days: AppConstants.imageCacheDurationDays),
        maxNrOfCacheObjects: 200,
      ),
    );
    return _instance!;
  }
}
