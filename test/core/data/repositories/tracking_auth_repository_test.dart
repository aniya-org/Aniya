import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aniya/core/data/repositories/tracking_auth_repository_impl.dart';
import 'package:aniya/core/domain/entities/auth_token.dart';
import 'package:aniya/core/enums/tracking_service.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late TrackingAuthRepositoryImpl repository;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    repository = TrackingAuthRepositoryImpl(secureStorage: mockSecureStorage);
  });

  group('TrackingAuthRepository', () {
    group('saveToken', () {
      test('should save token to secure storage', () async {
        // Arrange
        final token = AuthToken(
          accessToken: 'test_access_token',
          refreshToken: 'test_refresh_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          service: TrackingService.mal,
        );

        when(
          () => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.saveToken(TrackingService.mal, token);

        // Assert
        expect(result.isRight(), true);
        verify(
          () => mockSecureStorage.write(
            key: 'tracking_auth_token_mal',
            value: any(named: 'value'),
          ),
        ).called(1);
      });
    });

    group('getAuthToken', () {
      test('should return null when no token exists', () async {
        // Arrange
        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getAuthToken(TrackingService.mal);

        // Assert
        expect(result, isNull);
      });

      test('should return token when it exists', () async {
        // Arrange
        final token = AuthToken(
          accessToken: 'test_access_token',
          refreshToken: 'test_refresh_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          service: TrackingService.mal,
        );

        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => token.encode());

        // Act
        final result = await repository.getAuthToken(TrackingService.mal);

        // Assert
        expect(result, isNotNull);
        expect(result!.accessToken, 'test_access_token');
        expect(result.refreshToken, 'test_refresh_token');
        expect(result.service, TrackingService.mal);
      });
    });

    group('getValidToken', () {
      test('should return null when no token exists', () async {
        // Arrange
        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getValidToken(TrackingService.mal);

        // Assert
        expect(result, isNull);
      });

      test('should return access token when token is valid', () async {
        // Arrange
        final token = AuthToken(
          accessToken: 'valid_access_token',
          refreshToken: 'test_refresh_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          service: TrackingService.mal,
        );

        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => token.encode());

        // Act
        final result = await repository.getValidToken(TrackingService.mal);

        // Assert
        expect(result, 'valid_access_token');
      });

      test(
        'should return null when token is expired and cannot refresh',
        () async {
          // Arrange - AniList token expired (no refresh support)
          final token = AuthToken(
            accessToken: 'expired_access_token',
            refreshToken: null,
            expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
            service: TrackingService.anilist,
          );

          when(
            () => mockSecureStorage.read(key: any(named: 'key')),
          ).thenAnswer((_) async => token.encode());

          // Act
          final result = await repository.getValidToken(
            TrackingService.anilist,
          );

          // Assert
          expect(result, isNull);
        },
      );

      test('should return token for Simkl (never expires)', () async {
        // Arrange - Simkl token has no expiry
        final token = AuthToken(
          accessToken: 'simkl_access_token',
          refreshToken: null,
          expiresAt: null, // Never expires
          service: TrackingService.simkl,
        );

        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => token.encode());

        // Act
        final result = await repository.getValidToken(TrackingService.simkl);

        // Assert
        expect(result, 'simkl_access_token');
      });
    });

    group('clearToken', () {
      test('should delete token from secure storage', () async {
        // Arrange
        when(
          () => mockSecureStorage.delete(key: any(named: 'key')),
        ).thenAnswer((_) async {});

        // Act
        final result = await repository.clearToken(TrackingService.mal);

        // Assert
        expect(result.isRight(), true);
        verify(
          () => mockSecureStorage.delete(key: 'tracking_auth_token_mal'),
        ).called(1);
      });
    });

    group('isAuthenticated', () {
      test('should return true when token exists', () async {
        // Arrange
        final token = AuthToken(
          accessToken: 'test_token',
          service: TrackingService.mal,
        );

        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => token.encode());

        // Act
        final result = await repository.isAuthenticated(TrackingService.mal);

        // Assert
        expect(result, true);
      });

      test('should return false when no token exists', () async {
        // Arrange
        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.isAuthenticated(TrackingService.mal);

        // Assert
        expect(result, false);
      });
    });

    group('getAuthenticatedServices', () {
      test('should return list of authenticated services', () async {
        // Arrange
        final malToken = AuthToken(
          accessToken: 'mal_token',
          service: TrackingService.mal,
        );
        final anilistToken = AuthToken(
          accessToken: 'anilist_token',
          service: TrackingService.anilist,
        );

        when(
          () => mockSecureStorage.read(key: 'tracking_auth_token_mal'),
        ).thenAnswer((_) async => malToken.encode());
        when(
          () => mockSecureStorage.read(key: 'tracking_auth_token_anilist'),
        ).thenAnswer((_) async => anilistToken.encode());
        when(
          () => mockSecureStorage.read(key: 'tracking_auth_token_simkl'),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getAuthenticatedServices();

        // Assert
        expect(result, contains(TrackingService.mal));
        expect(result, contains(TrackingService.anilist));
        expect(result, isNot(contains(TrackingService.simkl)));
        expect(result, isNot(contains(TrackingService.jikan)));
      });
    });
  });

  group('AuthToken', () {
    test('isExpired should return false when expiresAt is null', () {
      final token = AuthToken(
        accessToken: 'test',
        expiresAt: null,
        service: TrackingService.simkl,
      );

      expect(token.isExpired, false);
    });

    test('isExpired should return true when token is expired', () {
      final token = AuthToken(
        accessToken: 'test',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        service: TrackingService.mal,
      );

      expect(token.isExpired, true);
    });

    test('isExpired should return true when within 5 minute buffer', () {
      final token = AuthToken(
        accessToken: 'test',
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
        service: TrackingService.mal,
      );

      expect(token.isExpired, true);
    });

    test('isExpired should return false when token is valid', () {
      final token = AuthToken(
        accessToken: 'test',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        service: TrackingService.mal,
      );

      expect(token.isExpired, false);
    });

    test('canRefresh should return true when refresh token exists', () {
      final token = AuthToken(
        accessToken: 'test',
        refreshToken: 'refresh',
        service: TrackingService.mal,
      );

      expect(token.canRefresh, true);
    });

    test('canRefresh should return false when no refresh token', () {
      final token = AuthToken(
        accessToken: 'test',
        refreshToken: null,
        service: TrackingService.anilist,
      );

      expect(token.canRefresh, false);
    });

    test('encode and decode should preserve all fields', () {
      final original = AuthToken(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime(2024, 12, 31, 23, 59, 59),
        tokenType: 'Bearer',
        service: TrackingService.mal,
      );

      final encoded = original.encode();
      final decoded = AuthToken.decode(encoded);

      expect(decoded.accessToken, original.accessToken);
      expect(decoded.refreshToken, original.refreshToken);
      expect(decoded.expiresAt, original.expiresAt);
      expect(decoded.tokenType, original.tokenType);
      expect(decoded.service, original.service);
    });
  });

  group('createTokenFromOAuthResponse', () {
    test('should create MAL token with expiration', () {
      final data = {
        'access_token': 'mal_access',
        'refresh_token': 'mal_refresh',
        'expires_in': 3600,
        'token_type': 'Bearer',
      };

      final token = TrackingAuthRepositoryImpl.createTokenFromOAuthResponse(
        TrackingService.mal,
        data,
      );

      expect(token.accessToken, 'mal_access');
      expect(token.refreshToken, 'mal_refresh');
      expect(token.expiresAt, isNotNull);
      expect(token.service, TrackingService.mal);
    });

    test('should create AniList token with 1 year expiration', () {
      final data = {'access_token': 'anilist_access', 'token_type': 'Bearer'};

      final token = TrackingAuthRepositoryImpl.createTokenFromOAuthResponse(
        TrackingService.anilist,
        data,
      );

      expect(token.accessToken, 'anilist_access');
      expect(token.refreshToken, isNull);
      expect(token.expiresAt, isNotNull);
      // Should be approximately 1 year from now
      expect(
        token.expiresAt!.difference(DateTime.now()).inDays,
        greaterThan(360),
      );
      expect(token.service, TrackingService.anilist);
    });

    test('should create Simkl token with no expiration', () {
      final data = {'access_token': 'simkl_access', 'token_type': 'bearer'};

      final token = TrackingAuthRepositoryImpl.createTokenFromOAuthResponse(
        TrackingService.simkl,
        data,
      );

      expect(token.accessToken, 'simkl_access');
      expect(token.expiresAt, isNull);
      expect(token.service, TrackingService.simkl);
    });
  });
}
