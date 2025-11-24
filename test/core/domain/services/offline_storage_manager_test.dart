import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:aniya/core/domain/services/offline_storage_manager.dart';
import 'package:aniya/core/domain/repositories/download_repository.dart';
import 'package:aniya/core/domain/entities/download_entity.dart';
import 'package:aniya/core/error/failures.dart';

// Mock DownloadRepository
class MockDownloadRepository implements DownloadRepository {
  bool? mockIsContentDownloaded;
  String? mockLocalFilePath;
  Failure? mockFailure;

  @override
  Future<Either<Failure, bool>> isContentDownloaded({
    required String mediaId,
    String? episodeId,
    String? chapterId,
  }) async {
    if (mockFailure != null) return Left(mockFailure!);
    return Right(mockIsContentDownloaded ?? false);
  }

  @override
  Future<Either<Failure, String?>> getLocalFilePath({
    required String mediaId,
    String? episodeId,
    String? chapterId,
  }) async {
    if (mockFailure != null) return Left(mockFailure!);
    return Right(mockLocalFilePath);
  }

  @override
  Future<Either<Failure, List<DownloadEntity>>> getAllDownloads() async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<DownloadEntity>>> getDownloadsByStatus(
    DownloadStatus status,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, DownloadEntity>> getDownloadById(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, DownloadEntity>> addDownload(
    DownloadEntity download,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, DownloadEntity>> updateDownloadProgress(
    String id,
    int downloadedBytes,
    int totalBytes,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, DownloadEntity>> updateDownloadStatus(
    String id,
    DownloadStatus status,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, DownloadEntity>> pauseDownload(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, DownloadEntity>> resumeDownload(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, DownloadEntity>> cancelDownload(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, void>> deleteDownload(
    String id, {
    bool deleteFile = true,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  late OfflineStorageManager offlineStorageManager;
  late MockDownloadRepository mockDownloadRepository;

  setUpAll(() {
    // Initialize Flutter bindings for path_provider
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockDownloadRepository = MockDownloadRepository();
    offlineStorageManager = OfflineStorageManager(
      downloadRepository: mockDownloadRepository,
    );
  });

  group('OfflineStorageManager', () {
    group('isContentAvailableOffline', () {
      const mediaId = 'media123';
      const episodeId = 'episode456';

      test('should return false when content is not downloaded', () async {
        // Arrange
        mockDownloadRepository.mockIsContentDownloaded = false;
        mockDownloadRepository.mockFailure = null;

        // Act
        final result = await offlineStorageManager.isContentAvailableOffline(
          mediaId: mediaId,
          episodeId: episodeId,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not return failure'),
          (isAvailable) => expect(isAvailable, false),
        );
      });

      test('should return failure when repository fails', () async {
        // Arrange
        mockDownloadRepository.mockFailure = StorageFailure('Database error');

        // Act
        final result = await offlineStorageManager.isContentAvailableOffline(
          mediaId: mediaId,
          episodeId: episodeId,
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<StorageFailure>()),
          (_) => fail('Should return failure'),
        );
      });
    });

    group('getOfflineContentPath', () {
      const mediaId = 'media123';
      const episodeId = 'episode456';

      test('should return null when content is not available', () async {
        // Arrange
        mockDownloadRepository.mockLocalFilePath = null;
        mockDownloadRepository.mockFailure = null;

        // Act
        final result = await offlineStorageManager.getOfflineContentPath(
          mediaId: mediaId,
          episodeId: episodeId,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not return failure'),
          (path) => expect(path, null),
        );
      });

      test('should return failure when repository fails', () async {
        // Arrange
        mockDownloadRepository.mockFailure = StorageFailure('Database error');

        // Act
        final result = await offlineStorageManager.getOfflineContentPath(
          mediaId: mediaId,
          episodeId: episodeId,
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<StorageFailure>()),
          (_) => fail('Should return failure'),
        );
      });
    });
  });
}
