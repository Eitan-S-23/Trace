class ShareLinks {
  ShareLinks._();

  static const String appId = 'trace';
  static const String appName = 'Trace';
  static const String appPackageName = 'com.wen.gaia.gaia';
  static const String appSchemeUrl = 'trace://speedometer';
  static const String landingPageUrl = 'https://eitan-s-23.github.io/Trace/';
  static const String updateChannel = String.fromEnvironment(
    'TRACE_UPDATE_CHANNEL',
    defaultValue: 'stable',
  );
  static const String cloudflareUpdateManifestUrl = String.fromEnvironment(
    'TRACE_CLOUDFLARE_UPDATE_MANIFEST_URL',
    defaultValue: '',
  );
  static const String emergencyUpdateManifestUrl = String.fromEnvironment(
    'TRACE_EMERGENCY_UPDATE_MANIFEST_URL',
    defaultValue: '',
  );
  static const String updatePayloadPublicKeyBase64 = String.fromEnvironment(
    'TRACE_UPDATE_PAYLOAD_ED25519_PUBLIC_KEY_BASE64',
    defaultValue: '',
  );
  static const String githubReleaseDownloadBaseUrl =
      'https://github.com/Eitan-S-23/Trace/releases/download/';
  static const String githubLatestReleaseDownloadBaseUrl =
      'https://github.com/Eitan-S-23/Trace/releases/latest/download/';
  static const String legacyGithubLatestManifestUrl =
      '${githubLatestReleaseDownloadBaseUrl}ble-monitor-update.json';
  static String get androidUpdateManifestUrl =>
      cloudflareUpdateManifestUrl.isNotEmpty
          ? cloudflareUpdateManifestUrl
          : legacyGithubLatestManifestUrl;
  static const String androidApkUrl =
      '${githubLatestReleaseDownloadBaseUrl}ble-monitor-android.apk';
  static const String windowsDownloadUrl =
      '${githubLatestReleaseDownloadBaseUrl}ble-monitor-windows.zip';

  static final Uri landingPageUri = Uri.parse(landingPageUrl);

  static String githubReleaseAssetUrl(String releaseTag, String assetName) {
    return '$githubReleaseDownloadBaseUrl'
        '${Uri.encodeComponent(releaseTag)}/'
        '${Uri.encodeComponent(assetName)}';
  }
}
