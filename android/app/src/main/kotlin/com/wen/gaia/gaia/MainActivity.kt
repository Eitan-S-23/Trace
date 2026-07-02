package com.wen.gaia.gaia

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var deepLinkChannel: MethodChannel? = null
    private var appUpdateChannel: MethodChannel? = null
    private var isActivityResumed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEEP_LINK_CHANNEL
        )
        deepLinkChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> result.success(intent?.dataString)
                else -> result.notImplemented()
            }
        }
        appUpdateChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_UPDATE_CHANNEL
        )
        appUpdateChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppInfo" -> result.success(getAppInfo())
                "canRequestPackageInstalls" -> result.success(canRequestPackageInstalls())
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    installApk(apkPath, result)
                }
                "startUpdateForegroundService" -> {
                    val status = call.argument<String>("status") ?: "正在准备更新..."
                    val progress = call.argument<Int>("progress") ?: -1
                    result.success(UpdateForegroundService.start(applicationContext, status, progress))
                }
                "updateUpdateForegroundService" -> {
                    val status = call.argument<String>("status") ?: "正在更新..."
                    val progress = call.argument<Int>("progress") ?: -1
                    result.success(UpdateForegroundService.start(applicationContext, status, progress))
                }
                "stopUpdateForegroundService" -> {
                    result.success(UpdateForegroundService.stop(applicationContext))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { link ->
            deepLinkChannel?.invokeMethod("onDeepLink", link)
        }
    }

    override fun onResume() {
        super.onResume()
        isActivityResumed = true
    }

    override fun onPause() {
        isActivityResumed = false
        super.onPause()
    }

    companion object {
        private const val DEEP_LINK_CHANNEL = "trace/deep_link"
        private const val APP_UPDATE_CHANNEL = "trace/app_update"
    }

    private fun getAppInfo(): Map<String, Any> {
        val packageInfo = packageManager.getPackageInfo(packageName, 0)
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }
        return mapOf(
            "versionName" to (packageInfo.versionName ?: ""),
            "versionCode" to versionCode,
            "sourceApkPath" to applicationInfo.sourceDir
        )
    }

    private fun installApk(apkPath: String?, result: MethodChannel.Result) {
        if (apkPath.isNullOrBlank()) {
            result.error("APK_PATH_EMPTY", "APK path is empty", null)
            return
        }
        val apkFile = File(apkPath)
        if (!apkFile.exists()) {
            result.error("APK_NOT_FOUND", "APK file does not exist", null)
            return
        }

        if (!canRequestPackageInstalls()) {
            val settingsIntent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )
            settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(settingsIntent)
            } catch (_: Exception) {
                // Flutter still needs the explicit permission error instead of a hung method call.
            }
            result.error("UNKNOWN_APP_SOURCES", "Unknown app source permission required", null)
            return
        }

        if (isActivityResumed) {
            val installIntent = UpdateForegroundService.installIntentFor(
                this,
                apkFile.path,
                packageName,
            )
            try {
                startActivity(installIntent)
                result.success(mapOf("requested" to true, "launched" to true))
            } catch (_: Exception) {
                val requested = UpdateForegroundService.openInstaller(
                    applicationContext,
                    apkFile.path,
                    packageName,
                )
                result.success(mapOf("requested" to requested, "launched" to false))
            }
            return
        }

        val requested = UpdateForegroundService.openInstaller(
            applicationContext,
            apkFile.path,
            packageName,
        )
        result.success(mapOf("requested" to requested, "launched" to false))
    }

    private fun canRequestPackageInstalls(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }
}
