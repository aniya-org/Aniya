import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/data/repositories/tracking_repository_impl.dart';
import 'package:aniya/core/data/datasources/tracking_data_source.dart';
import 'package:aniya/core/data/models/user_model.dart';
import 'package:aniya/core/data/models/library_item_model.dart';
import 'package:aniya/core/domain/entities/user_entity.dart';
import 'package:aniya/core/domain/entities/library_item_entity.dart';
import 'package:aniya/core/domain/entities/media_entity.dart';
import 'package:aniya/core/enums/tracking_service.dart' as ts;
import 'package:aniya/core/error/failures.dart';
import 'package:aniya/core/error/exceptions.dart';

// Mock TrackingDataSource
class MockTrackingDataSource implements TrackingDataSource {
  UserModel? mockUser;
  Exception? mockException;
  List<LibraryItemModel>? mockLibraryItems;
  String? storedToken;

  @override
  Future<UserModel> authenticate(TrackingService service, String token) async {
    if (mockException != null) throw mockException!;
    if (mockUser != null) {
      storedToken = token;
      return mockUser!;
    }
    throw ServerException('No mock user configured');
  }

  @override
  Future<void> syncProgress(
    TrackingService service,
    String mediaId,
    int episode,
    int chapter,
  ) async {
    if (mockException != null) throw mockException!;
  }

  @override
  Future<List<LibraryItemModel>> fetchRemoteLibrary(
    TrackingService service,
  ) async {
    if (mockException != null) throw mockException!;
    if (mockLibraryItems != null) return mockLibraryItems!;
    return [];
  }

  @override
  Future<void> updateStatus(
    TrackingService service,
    String mediaId,
    LibraryStatus status,
  ) async {
    if (mockException != null) throw mockException!;
  }

  @override
  Future<void> storeToken(TrackingService service, String token) async {
    storedToken = token;
  }

  @override
  Future<String?> getToken(TrackingService service) async {
    return storedToken;
  }

  @override
  Future<void> clearToken(TrackingService service) async {
    storedToken = null;
  }
}

void main() {
  late TrackingRepositoryImpl repository;
  late MockTrackingDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockTrackingDataSource();
    repository = TrackingRepositoryImpl(dataSource: mockDataSource);
  });

  group('TrackingRepositoryImpl', () {
    group('authenticate', () {
      test('should return UserEntity when authentication succeeds', () async {
        // Arrange
        final mockUser = UserModel(
          id: '123',
          username: 'testuser',
          avatarUrl: 'https://example.com/avatar.jpg',
          service: TrackingService.anilist,
        );
        mockDataSource.mockUser = mockUser;

        // Act
        final result = await repository.authenticate(
          TrackingService.anilist,
          'test_token',
        );

        // Assert
        expect(result.isRight(), true);
        result.fold((failure) => fail('Should not return failure'), (user) {
          expect(user.id, '123');
          expect(user.username, 'testuser');
          expect(user.service, TrackingService.anilist);
        });
      });

      test(
        'should return AuthenticationFailure when authentication fails',
        () async {
          // Arrange
          mockDataSource.mockException = const AuthenticationException(
            'Invalid token',
          );

          // Act
          final result = await repository.authenticate(
            TrackingService.anilist,
            'invalid_token',
          );

          // Assert
          expect(result.isLeft(), true);
          result.fold((failure) {
            expect(failure, isA<AuthenticationFailure>());
            expect(failure.message, 'Invalid token');
          }, (user) => fail('Should not return user'));
        },
      );

      test('should return ServerFailure when server error occurs', () async {
        // Arrange
        mockDataSource.mockException = const ServerException('Server error');

        // Act
        final result = await repository.authenticate(
          TrackingService.anilist,
          'test_token',
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'Server error');
        }, (user) => fail('Should not return user'));
      });
    });

    group('syncProgress', () {
      test('should return Unit when sync succeeds', () async {
        // Arrange
        mockDataSource.storedToken = 'valid_token';

        // Act
        final result = await repository.syncProgress('media123', 5, 0);

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not return failure'),
          (unit) => expect(unit, equals(unit)),
        );
      });

      test(
        'should return AuthenticationFailure when no token is stored',
        () async {
          // Arrange
          mockDataSource.storedToken = null;

          // Act
          final result = await repository.syncProgress('media123', 5, 0);

          // Assert
          expect(result.isLeft(), true);
          result.fold((failure) {
            expect(failure, isA<AuthenticationFailure>());
            expect(failure.message, 'No tracking service authenticated');
          }, (unit) => fail('Should not return unit'));
        },
      );

      test('should return ServerFailure when sync fails', () async {
        // Arrange
        mockDataSource.storedToken = 'valid_token';
        mockDataSource.mockException = const ServerException('Sync failed');

        // Act
        final result = await repository.syncProgress('media123', 5, 0);

        // Assert
        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'Sync failed');
        }, (unit) => fail('Should not return unit'));
      });
    });

    group('fetchRemoteLibrary', () {
      test(
        'should return list of LibraryItemEntity when fetch succeeds',
        () async {
          // Arrange
          final mockMedia = MediaEntity(
            id: 'media1',
            title: 'Test Anime',
            type: MediaType.anime,
            status: MediaStatus.ongoing,
            sourceId: 'source1',
            sourceName: 'Test Source',
            genres: ['Action', 'Adventure'],
          );

          final mockLibraryItem = LibraryItemModel(
            id: 'item1',
            mediaId: 'media1',
            userService: ts.TrackingService.anilist,
            media: mockMedia,
            status: LibraryStatus.watching,
            progress: const WatchProgress(currentEpisode: 5, currentChapter: 0),
            addedAt: DateTime.now(),
          );

          mockDataSource.mockLibraryItems = [mockLibraryItem];

          // Act
          final result = await repository.fetchRemoteLibrary(
            TrackingService.anilist,
          );

          // Assert
          expect(result.isRight(), true);
          result.fold((failure) => fail('Should not return failure'), (items) {
            expect(items.length, 1);
            expect(items[0].id, 'item1');
            expect(items[0].status, LibraryStatus.watching);
          });
        },
      );

      test('should return ServerFailure when fetch fails', () async {
        // Arrange
        mockDataSource.mockException = const ServerException(
          'Failed to fetch library',
        );

        // Act
        final result = await repository.fetchRemoteLibrary(
          TrackingService.anilist,
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'Failed to fetch library');
        }, (items) => fail('Should not return items'));
      });
    });

    group('updateStatus', () {
      test('should return Unit when status update succeeds', () async {
        // Arrange
        mockDataSource.storedToken = 'valid_token';

        // Act
        final result = await repository.updateStatus(
          'media123',
          LibraryStatus.completed,
        );

        // Assert
        expect(result.isRight(), true);
        result.fold(
          (failure) => fail('Should not return failure'),
          (unit) => expect(unit, equals(unit)),
        );
      });

      test(
        'should return AuthenticationFailure when no token is stored',
        () async {
          // Arrange
          mockDataSource.storedToken = null;

          // Act
          final result = await repository.updateStatus(
            'media123',
            LibraryStatus.completed,
          );

          // Assert
          expect(result.isLeft(), true);
          result.fold((failure) {
            expect(failure, isA<AuthenticationFailure>());
            expect(failure.message, 'No tracking service authenticated');
          }, (unit) => fail('Should not return unit'));
        },
      );

      test('should return ServerFailure when update fails', () async {
        // Arrange
        mockDataSource.storedToken = 'valid_token';
        mockDataSource.mockException = const ServerException('Update failed');

        // Act
        final result = await repository.updateStatus(
          'media123',
          LibraryStatus.completed,
        );

        // Assert
        expect(result.isLeft(), true);
        result.fold((failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'Update failed');
        }, (unit) => fail('Should not return unit'));
      });
    });
  });
}
