import 'package:dartz/dartz.dart';
import '../../error/failures.dart';

abstract class SelectedExtensionRepository {
  Future<Either<Failure, String?>> getSelectedExtensionId(String key);
  Future<Either<Failure, void>> setSelectedExtensionId(
    String key,
    String? extensionId,
  );
}
