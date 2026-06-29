package com.wen.gaia.gaia

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var deepLinkChannel: MethodChannel? = null
    private var appUpdateChannel: MethodChannel? = null

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
            startActivity(settingsIntent)
            result.error("UNKNOWN_APP_SOURCES", "Unknown app source permission required", null)
            return
        }

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile
        )
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(installIntent)
        result.success(true)
    }

    private fun canRequestPackageInstalls(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }
}
