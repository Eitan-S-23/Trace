import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/share_links.dart';

class AppUpdateService extends GetxService {
  static AppUpdateService get to => Get.find<AppUpdateService>();

  static const MethodChannel _platform = MethodChannel('trace/app_update');
  static const String _lastDailyCheckKey = 'app_update_last_daily_check';

  final Dio _dio = Dio();

  final isChecking = false.obs;
  final isUpdating = false.obs;
  final updateProgress = 0.0.obs;
  final updateStatus = ''.obs;

  Future<void> checkDailyOnStartup() async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    if (prefs.getString(_lastDailyCheckKey) == today) return;

    await prefs.setString(_lastDailyCheckKey, today);
    unawaited(checkForUpdates(manual: false));
  }

  Future<void> checkForUpdates({bool manual = true}) async {
    if (!Platform.isAndroid) {
      if (manual) {
        Get.snackbar('暂不支持', '当前平台暂不支持 APK 增量自更新');
      }
      return;
    }

    if (isChecking.value || isUpdating.value) return;

    isChecking.value = true;
    try {
      final localInfo = await _getLocalAppInfo();
      final updateInfo = await _fetchUpdateInfo();

      if (updateInfo.versionCode <= localInfo.versionCode) {
        if (manual) {
          Get.snackbar('已是最新版本', '当前版本 ${localInfo.versionName}');
        }
        return;
      }

      final patch = updateInfo.patchFor(localInfo.versionCode);
      if (patch == null) {
        _showNoIncrementalPatchDialog(localInfo, updateInfo);
        return;
      }

      _showUpdateDialog(localInfo, updateInfo, patch);
    } catch (e) {
      if (manual) {
        Get.snackbar('检查更新失败', '$e');
      }
    } finally {
      isChecking.value = false;
    }
  }

  Future<_LocalAppInfo> _getLocalAppInfo() async {
    final result = await _platform.invokeMapMethod<String, dynamic>('getAppInfo');
    if (result == null) {
      throw Exception('无法读取当前应用版本');
    }
    return _LocalAppInfo.fromMap(result);
  }

  Future<_RemoteUpdateInfo> _fetchUpdateInfo() async {
    final response = await _dio.get<String>(
      ShareLinks.androidUpdateManifestUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final raw = response.data;
    if (raw == null || raw.trim().isEmpty) {
      throw Exception('更新清单为空');
    }
    return _RemoteUpdateInfo.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  void _showUpdateDialog(
    _LocalAppInfo localInfo,
    _RemoteUpdateInfo updateInfo,
    _RemoteUpdatePatch patch,
  ) {
    Get.dialog<void>(
      AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：${localInfo.versionName} (${localInfo.versionCode})'),
            const SizedBox(height: 6),
            Text('最新版本：${updateInfo.versionName} (${updateInfo.versionCode})'),
            const SizedBox(height: 12),
            Text('增量包大小：${_formatBytes(patch.size)}'),
            const SizedBox(height: 6),
            const Text('将下载增量包并在本机合成新版安装包。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () {
              Get.back<void>();
              unawaited(_applyIncrementalUpdate(localInfo, updateInfo, patch));
            },
            child: const Text('增量更新'),
          ),
        ],
      ),
    );
  }

  void _showNoIncrementalPatchDialog(
    _LocalAppInfo localInfo,
    _RemoteUpdateInfo updateInfo,
  ) {
    Get.dialog<void>(
      AlertDialog(
        title: const Text('发现新版本'),
        content: Text(
          '最新版本 ${updateInfo.versionName} 已发布，但当前版本 '
          '${localInfo.versionName} 没有对应的增量更新包。请先安装包含增量更新能力的版本，'
          '之后即可通过 App 内增量更新。',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyIncrementalUpdate(
    _LocalAppInfo localInfo,
    _RemoteUpdateInfo updateInfo,
    _RemoteUpdatePatch patch,
  ) async {
    if (isUpdating.value) return;

    isUpdating.value = true;
    updateProgress.value = 0;
    updateStatus.value = '准备增量更新...';
    _showProgressDialog();

    try {
      final tempDir = await getTemporaryDirectory();
      final patchFile = File(
        '${tempDir.path}/trace_${localInfo.versionCode}_${updateInfo.versionCode}.tpatch',
      );
      final outputApk = File(
        '${tempDir.path}/trace_update_${updateInfo.versionCode}.apk',
      );

      updateStatus.value = '下载增量包...';
      await _dio.download(
        patch.downloadUrl,
        patchFile.path,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          updateProgress.value = (received / total * 0.45).clamp(0.0, 0.45);
        },
      );

      final patchSha = await _sha256File(patchFile);
      if (patchSha != patch.sha256) {
        throw Exception('增量包校验失败');
      }

      updateStatus.value = '合成新版安装包...';
      await _TracePatchApplier().apply(
        oldApkPath: localInfo.sourceApkPath,
        patchPath: patchFile.path,
        outputApkPath: outputApk.path,
        expectedOldSha256: patch.oldSha256,
        expectedNewSha256: patch.newSha256,
        onProgress: (progress) {
          updateProgress.value = (0.45 + progress * 0.45).clamp(0.45, 0.90);
        },
      );

      updateStatus.value = '打开系统安装器...';
      updateProgress.value = 1;
      await _platform.invokeMethod<bool>('installApk', {
        'apkPath': outputApk.path,
      });
    } on PlatformException catch (e) {
      if (e.code == 'UNKNOWN_APP_SOURCES') {
        Get.snackbar('需要授权', '请允许安装未知来源应用后，再次点击检查更新');
      } else {
        Get.snackbar('更新失败', e.message ?? e.code);
      }
    } catch (e) {
      Get.snackbar('更新失败', '$e');
    } finally {
      if (Get.isDialogOpen == true) {
        Get.back<void>();
      }
      isUpdating.value = false;
    }
  }

  void _showProgressDialog() {
    Get.dialog<void>(
      Obx(
        () => AlertDialog(
          title: const Text('增量更新中'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(updateStatus.value),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: updateProgress.value),
              const SizedBox(height: 8),
              Text('${(updateProgress.value * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}

class _TracePatchApplier {
  static final List<int> _magic = utf8.encode('TRACEPATCH1\n');

  Future<void> apply({
    required String oldApkPath,
    required String patchPath,
    required String outputApkPath,
    required String expectedOldSha256,
    required String expectedNewSha256,
    required ValueChanged<double> onProgress,
  }) async {
    final oldApk = File(oldApkPath);
    final patchFile = File(patchPath);
    final outputApk = File(outputApkPath);

    final oldSha = await sha256.bind(oldApk.openRead()).first;
    if (oldSha.toString() != expectedOldSha256) {
      throw Exception('当前安装包与增量包不匹配');
    }

    final oldRaf = await oldApk.open();
    final patchRaf = await patchFile.open();
    final outRaf = await outputApk.open(mode: FileMode.write);

    try {
      final magic = await _readExactly(patchRaf, _magic.length);
      if (!_listEquals(magic, _magic)) {
        throw Exception('增量包格式错误');
      }

      final manifestLengthBytes = await _readExactly(patchRaf, 4);
      final manifestLength =
          ByteData.sublistView(Uint8List.fromList(manifestLengthBytes))
              .getUint32(0, Endian.little);
      final manifestBytes = await _readExactly(patchRaf, manifestLength);
      final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;

      if (manifest['newSha256'] != expectedNewSha256) {
        throw Exception('增量包目标版本校验失败');
      }

      final newSize = _jsonInt(manifest['newSize']);
      var written = 0;
      final operations = manifest['operations'] as List<dynamic>;

      for (final operation in operations) {
        final op = operation as Map<String, dynamic>;
        final kind = op['op'] as String;
        final length = _jsonInt(op['length']);

        if (kind == 'copy') {
          final offset = _jsonInt(op['offset']);
          await oldRaf.setPosition(offset);
          await _copyBytes(oldRaf, outRaf, length);
        } else if (kind == 'data') {
          await _copyBytes(patchRaf, outRaf, length);
        } else {
          throw Exception('未知增量操作: $kind');
        }

        written += length;
        if (newSize > 0) {
          onProgress((written / newSize).clamp(0.0, 1.0));
        }
      }
    } finally {
      await oldRaf.close();
      await patchRaf.close();
      await outRaf.close();
    }

    final newSha = await sha256.bind(outputApk.openRead()).first;
    if (newSha.toString() != expectedNewSha256) {
      throw Exception('合成安装包校验失败');
    }
  }

  Future<void> _copyBytes(
    RandomAccessFile input,
    RandomAccessFile output,
    int length,
  ) async {
    var remaining = length;
    while (remaining > 0) {
      final chunkSize = remaining > 64 * 1024 ? 64 * 1024 : remaining;
      final chunk = await _readExactly(input, chunkSize);
      await output.writeFrom(chunk);
      remaining -= chunk.length;
    }
  }

  Future<List<int>> _readExactly(RandomAccessFile file, int length) async {
    final bytes = await file.read(length);
    if (bytes.length != length) {
      throw Exception('增量包读取失败');
    }
    return bytes;
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int _jsonInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw Exception('增量包数值字段错误');
  }
}

class _LocalAppInfo {
  const _LocalAppInfo({
    required this.versionName,
    required this.versionCode,
    required this.sourceApkPath,
  });

  final String versionName;
  final int versionCode;
  final String sourceApkPath;

  factory _LocalAppInfo.fromMap(Map<String, dynamic> map) {
    return _LocalAppInfo(
      versionName: map['versionName'] as String,
      versionCode: (map['versionCode'] as num).toInt(),
      sourceApkPath: map['sourceApkPath'] as String,
    );
  }
}

class _RemoteUpdateInfo {
  const _RemoteUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.patches,
  });

  final String versionName;
  final int versionCode;
  final List<_RemoteUpdatePatch> patches;

  factory _RemoteUpdateInfo.fromJson(Map<String, dynamic> json) {
    return _RemoteUpdateInfo(
      versionName: json['versionName'] as String,
      versionCode: (json['versionCode'] as num).toInt(),
      patches: ((json['patches'] as List<dynamic>?) ?? const [])
          .map((item) => _RemoteUpdatePatch.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  _RemoteUpdatePatch? patchFor(int versionCode) {
    for (final patch in patches) {
      if (patch.fromVersionCode == versionCode) {
        return patch;
      }
    }
    return null;
  }
}

class _RemoteUpdatePatch {
  const _RemoteUpdatePatch({
    required this.fromVersionCode,
    required this.assetName,
    required this.sha256,
    required this.size,
    required this.oldSha256,
    required this.newSha256,
  });

  final int fromVersionCode;
  final String assetName;
  final String sha256;
  final int size;
  final String oldSha256;
  final String newSha256;

  String get downloadUrl => '${ShareLinks.githubLatestReleaseDownloadBaseUrl}$assetName';

  factory _RemoteUpdatePatch.fromJson(Map<String, dynamic> json) {
    return _RemoteUpdatePatch(
      fromVersionCode: (json['fromVersionCode'] as num).toInt(),
      assetName: json['assetName'] as String,
      sha256: json['sha256'] as String,
      size: (json['size'] as num).toInt(),
      oldSha256: json['oldSha256'] as String,
      newSha256: json['newSha256'] as String,
    );
  }
}
