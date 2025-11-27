import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

class PermissionService {
  Future<bool> requestInstallPackagesPermission() async {
    try {
      final status = await Permission.requestInstallPackages.status;
      
      if (status.isGranted) {
        return true;
      }
      
      final result = await Permission.requestInstallPackages.request();
      
      if (result.isGranted) {
        Logger.info('Install packages permission granted', tag: 'PermissionService');
        return true;
      } else if (result.isPermanentlyDenied) {
        Logger.warning('Install packages permission permanently denied', tag: 'PermissionService');
        await openAppSettings();
        return false;
      } else {
        Logger.warning('Install packages permission denied', tag: 'PermissionService');
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('Error requesting install packages permission', tag: 'PermissionService', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
