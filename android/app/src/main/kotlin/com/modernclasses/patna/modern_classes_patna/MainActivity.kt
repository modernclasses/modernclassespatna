package com.modernclasses.patna.modern_classes_patna

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.modernclasses.patna.modern_classes_patna.broadcast.RootEncoderViewFactory

class MainActivity : FlutterActivity() {
    private val SECURITY_CHANNEL = "com.modernclasses.patna/security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Hardware-level Anti-Piracy: Block screenshots & screen recording globally
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "modern_classes_patna/broadcast_preview",
            RootEncoderViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecure" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                "disableSecure" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                "isSecureEnabled" -> {
                    val flags = window.attributes.flags
                    val isSecure = (flags and WindowManager.LayoutParams.FLAG_SECURE) != 0
                    result.success(isSecure)
                }
                else -> result.notImplemented()
            }
        }
    }
}
