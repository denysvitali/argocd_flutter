package it.denv.argocd_flutter

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "it.denv.argocd_flutter/sso")
            .setMethodCallHandler { call, result ->
                if (call.method != "openBrowser") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uri = (call.arguments as? String)?.let { Uri.parse(it) }
                if (uri == null || uri.scheme != "https" || uri.host.isNullOrEmpty()) {
                    result.error("invalid_url", "SSO requires an HTTPS URL.", null)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE))
                    result.success(null)
                } catch (_: ActivityNotFoundException) {
                    result.error("no_browser", "No browser is available.", null)
                }
            }
    }
}
