import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_info.dart';

class ReleaseAsset {
  ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    this.size = 0,
  });

  final String name;
  final String downloadUrl;
  final int size;
}

class ReleaseInfo {
  ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final String publishedAt;
  final List<ReleaseAsset> assets;

  String? get apkUrl {
    for (final asset in assets) {
      if (asset.name.toLowerCase().endsWith('.apk')) {
        return asset.downloadUrl;
      }
    }
    return null;
  }

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final assets = <ReleaseAsset>[];
    final rawAssets = json['assets'];
    if (rawAssets is List) {
      for (final item in rawAssets) {
        if (item is! Map) continue;
        final name = item['name'];
        final url = item['browser_download_url'];
        if (name is! String || url is! String) continue;
        assets.add(ReleaseAsset(
          name: name,
          downloadUrl: url,
          size: (item['size'] as num?)?.toInt() ?? 0,
        ));
      }
    }
    return ReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? AppInfo.releasesPage,
      publishedAt: json['published_at'] as String? ?? '',
      assets: assets,
    );
  }
}

class UpdateException implements Exception {
  UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateService {
  Future<ReleaseInfo?> fetchLatest() async {
    final response = await http.get(
      Uri.parse(AppInfo.releasesApi),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'DeepChat-Android',
      },
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw UpdateException('GitHub 返回 ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw UpdateException('发行版数据格式不正确');
    }
    return ReleaseInfo.fromJson(decoded);
  }

  /// 返回正数表示 [remote] 比 [local] 新。
  static int compareVersions(String remote, String local) {
    List<int> parse(String input) {
      final cleaned = input.trim().replaceFirst(RegExp(r'^[vV]'), '');
      return cleaned
          .split(RegExp(r'[._+-]'))
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
    }

    final a = parse(remote);
    final b = parse(local);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final left = i < a.length ? a[i] : 0;
      final right = i < b.length ? b[i] : 0;
      if (left != right) return left.compareTo(right);
    }
    return 0;
  }

  static bool isNewer(ReleaseInfo release) =>
      compareVersions(release.tagName, AppInfo.version) > 0;
}
