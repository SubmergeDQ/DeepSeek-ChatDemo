/// 应用版本与发布仓库信息。
class AppInfo {
  static const String version = '1.0.4';
  static const int versionCode = 5;
  static const String repo = 'SubmergeDQ/DeepSeek-ChatDemo';
  static const String releasesApi =
      'https://api.github.com/repos/$repo/releases/latest';
  static const String releasesPage = 'https://github.com/$repo/releases';
  static const String licenseUrl = 'https://github.com/$repo/blob/main/LICENSE';
  static const String feedbackUrl = 'https://github.com/$repo/issues';
  static const String repoUrl = 'https://github.com/$repo';
}
