import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../error/failures.dart';
import '../../utils/logger.dart';
import '../../domain/repositories/selected_extension_repository.dart';

class SelectedExtensionRepositoryImpl implements SelectedExtensionRepository {
  final SharedPreferences prefs;
  static const String _prefix = 'selected_extension_for_media:';

  SelectedExtensionRepositoryImpl({required this.prefs});

  @override
  Future<Either<Failure, String?>> getSelectedExtensionId(String key) async {
    try {
      final id = prefs.getString('$_prefix$key');
      return Right(id);
    } catch (e) {
      Logger.error(
        'Failed to get selected extension',
        tag: 'SelectedExtensionRepo',
        error: e,
      );
      return Left(UnknownFailure('Failed to get selected extension: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> setSelectedExtensionId(
    String key,
    String? extensionId,
  ) async {
    try {
      if (extensionId == null || extensionId.isEmpty) {
        await prefs.remove('$_prefix$key');
      } else {
        await prefs.setString('$_prefix$key', extensionId);
      }
      return const Right(null);
    } catch (e) {
      Logger.error(
        'Failed to set selected extension',
        tag: 'SelectedExtensionRepo',
        error: e,
      );
      return Left(UnknownFailure('Failed to set selected extension: $e'));
    }
  }
}
