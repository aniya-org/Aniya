import 'dart:convert';
import 'package:dartotsu_extension_bridge/Extensions/SourceMethods.dart';
import 'package:dartotsu_extension_bridge/Models/DMedia.dart';
import 'package:dartotsu_extension_bridge/Models/DEpisode.dart';
import 'package:dartotsu_extension_bridge/Models/Page.dart';
import 'package:dartotsu_extension_bridge/Models/Pages.dart';
import 'package:dartotsu_extension_bridge/Models/Source.dart';
import 'package:dartotsu_extension_bridge/Models/SourcePreference.dart';
import 'package:dartotsu_extension_bridge/Models/Video.dart';
import 'package:get/get.dart';
import 'runtime/aniya_eval_runtime.dart';

class AniyaEvalSourceMethods extends SourceMethods {
  AniyaEvalSourceMethods(Source source) {
    this.source = source;
  }

  AniyaEvalRuntime get _runtime => Get.find<AniyaEvalRuntime>();

  Future<Pages> _pagesFromEvalResult(dynamic result) async {
    if (result is String) {
      final decoded = json.decode(result);
      if (decoded is Map) {
        return Pages.fromJson(Map<String, dynamic>.from(decoded));
      }
      return Pages(list: []);
    } else if (result is Map) {
      return Pages.fromJson(Map<String, dynamic>.from(result));
    }
    return Pages(list: []);
  }

  String get _pluginId {
    final id = source.id;
    if (id == null || id.isEmpty) {
      throw StateError('Missing plugin id');
    }
    return id;
  }

  @override
  Future<Pages> getPopular(int page) async {
    final res = await _runtime.callFunction(_pluginId, 'getPopular', [page]);
    return _pagesFromEvalResult(res);
  }

  @override
  Future<Pages> getLatestUpdates(int page) async {
    final res = await _runtime.callFunction(_pluginId, 'getLatestUpdates', [
      page,
    ]);
    return _pagesFromEvalResult(res);
  }

  @override
  Future<Pages> search(String query, int page, List<dynamic> filters) async {
    final res = await _runtime.callFunction(_pluginId, 'search', [
      query,
      page,
      filters,
    ]);
    return _pagesFromEvalResult(res);
  }

  @override
  Future<DMedia> getDetail(DMedia media) async {
    final res = await _runtime.callFunction(_pluginId, 'getDetail', [
      media.toJson(),
    ]);
    if (res is String) {
      final decoded = json.decode(res);
      if (decoded is Map) {
        return DMedia.fromJson(Map<String, dynamic>.from(decoded));
      }
      return media;
    } else if (res is Map) {
      return DMedia.fromJson(Map<String, dynamic>.from(res));
    }
    return media;
  }

  @override
  Future<List<PageUrl>> getPageList(DEpisode episode) async {
    final res = await _runtime.callFunction(_pluginId, 'getPageList', [
      episode.toJson(),
    ]);
    if (res is String) {
      final decoded = json.decode(res);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => PageUrl.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return <PageUrl>[];
    } else if (res is List) {
      return res
          .map((e) => PageUrl.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <PageUrl>[];
  }

  @override
  Future<List<Video>> getVideoList(DEpisode episode) async {
    final res = await _runtime.callFunction(_pluginId, 'getVideoList', [
      episode.toJson(),
    ]);
    if (res is String) {
      final decoded = json.decode(res);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Video.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return <Video>[];
    } else if (res is List) {
      return res
          .map((e) => Video.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <Video>[];
  }

  @override
  Future<String?> getNovelContent(String chapterTitle, String chapterId) async {
    final res = await _runtime.callFunction(_pluginId, 'getNovelContent', [
      chapterTitle,
      chapterId,
    ]);
    if (res is String) return res;
    return null;
  }

  @override
  Future<List<SourcePreference>> getPreference() async {
    final res = await _runtime.callFunction(_pluginId, 'getPreference', []);
    if (res is String) {
      final decoded = json.decode(res);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => SourcePreference.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return <SourcePreference>[];
    } else if (res is List) {
      return res
          .map((e) => SourcePreference.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <SourcePreference>[];
  }

  @override
  Future<bool> setPreference(SourcePreference pref, dynamic value) async {
    final res = await _runtime.callFunction(_pluginId, 'setPreference', [
      pref.toJson(),
      value,
    ]);
    return res == true;
  }
}
