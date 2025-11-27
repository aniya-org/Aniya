import 'package:flutter_test/flutter_test.dart';
import 'package:aniya/core/data/models/deep_link_models.dart';
import 'package:aniya/core/domain/entities/extension_entity.dart';

void main() {
  group('DeepLinkParams', () {
    test('should create DeepLinkParams with all fields', () {
      const params = DeepLinkParams(
        extensionType: ExtensionType.mangayomi,
        animeRepoUrl: 'https://example.com/anime',
        mangaRepoUrl: 'https://example.com/manga',
        novelRepoUrl: 'https://example.com/novel',
      );

      expect(params.extensionType, ExtensionType.mangayomi);
      expect(params.animeRepoUrl, 'https://example.com/anime');
      expect(params.mangaRepoUrl, 'https://example.com/manga');
      expect(params.novelRepoUrl, 'https://example.com/novel');
    });

    test('hasAnyUrl should return true when at least one URL is provided', () {
      const params = DeepLinkParams(
        extensionType: ExtensionType.aniyomi,
        animeRepoUrl: 'https://example.com/anime',
      );

      expect(params.hasAnyUrl, true);
    });

    test('hasAnyUrl should return false when no URLs are provided', () {
      const params = DeepLinkParams(extensionType: ExtensionType.aniyomi);

      expect(params.hasAnyUrl, false);
    });

    test('allUrls should return list of all non-null URLs', () {
      const params = DeepLinkParams(
        extensionType: ExtensionType.mangayomi,
        animeRepoUrl: 'https://example.com/anime',
        mangaRepoUrl: 'https://example.com/manga',
      );

      expect(params.allUrls, [
        'https://example.com/anime',
        'https://example.com/manga',
      ]);
    });

    test('two DeepLinkParams with same values should be equal', () {
      const params1 = DeepLinkParams(
        extensionType: ExtensionType.cloudstream,
        animeRepoUrl: 'https://example.com/repo',
      );
      const params2 = DeepLinkParams(
        extensionType: ExtensionType.cloudstream,
        animeRepoUrl: 'https://example.com/repo',
      );

      expect(params1, params2);
    });
  });

  group('DeepLinkResult', () {
    test('should create DeepLinkResult with all fields', () {
      const result = DeepLinkResult(
        success: true,
        message: 'Repository added successfully',
        addedRepos: ['https://example.com/repo'],
      );

      expect(result.success, true);
      expect(result.message, 'Repository added successfully');
      expect(result.addedRepos, ['https://example.com/repo']);
    });

    test('success factory should create successful result', () {
      final result = DeepLinkResult.success(
        message: 'Added 2 repositories',
        addedRepos: ['url1', 'url2'],
      );

      expect(result.success, true);
      expect(result.message, 'Added 2 repositories');
      expect(result.addedRepos, ['url1', 'url2']);
    });

    test('failure factory should create failure result', () {
      final result = DeepLinkResult.failure(
        message: 'Invalid deep link format',
      );

      expect(result.success, false);
      expect(result.message, 'Invalid deep link format');
      expect(result.addedRepos, isEmpty);
    });

    test('two DeepLinkResults with same values should be equal', () {
      const result1 = DeepLinkResult(
        success: true,
        message: 'Success',
        addedRepos: ['url1'],
      );
      const result2 = DeepLinkResult(
        success: true,
        message: 'Success',
        addedRepos: ['url1'],
      );

      expect(result1, result2);
    });
  });
}
