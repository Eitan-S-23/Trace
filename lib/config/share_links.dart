class ShareLinks {
  ShareLinks._();

  static const String appName = 'Trace';
  static const String appPackageName = 'com.wen.gaia.gaia';
  static const String appSchemeUrl = 'trace://speedometer';
  static const String landingPageUrl = 'https://eitan-s-23.github.io/Trace/';
  static const String githubLatestReleaseDownloadBaseUrl =
      'https://github.com/Eitan-S-23/Trace/releases/latest/download/';
  static const String androidUpdateManifestUrl =
      '${githubLatestReleaseDownloadBaseUrl}ble-monitor-update.json';
  static const String androidApkUrl =
      '${githubLatestReleaseDownloadBaseUrl}ble-monitor-android.apk';
  static const String windowsDownloadUrl =
      '${githubLatestReleaseDownloadBaseUrl}ble-monitor-windows.zip';

  static final Uri landingPageUri = Uri.parse(landingPageUrl);
}
