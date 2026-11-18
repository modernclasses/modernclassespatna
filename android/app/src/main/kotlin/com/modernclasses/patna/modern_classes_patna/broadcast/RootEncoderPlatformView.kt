package com.modernclasses.patna.modern_classes_patna.broadcast

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.view.OrientationEventListener
import android.view.Surface
import android.view.View
import android.view.WindowManager
import androidx.core.content.ContextCompat
import com.pedro.common.ConnectChecker
import com.pedro.encoder.input.video.CameraHelper
import com.pedro.library.rtmp.RtmpCamera2
import com.pedro.library.util.SensorRotationManager
import com.pedro.library.view.OpenGlView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.net.URI

class RootEncoderPlatformView(
    private val context: Context,
    private val viewId: Int,
    args: Any?,
    private val messenger: BinaryMessenger
) : PlatformView, ConnectChecker, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val openGlView: OpenGlView = OpenGlView(context)
    private val rtmpCamera2: RtmpCamera2 = RtmpCamera2(openGlView, this)

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var orientationListener: OrientationEventListener? = null
    private var sensorRotationManager: SensorRotationManager? = null
    private var currentRotation: Int = -1

    // Dual channel registration: viewId-scoped and default singleton
    private val methodChannelView = MethodChannel(messenger, "modern_classes_patna/broadcast_$viewId")
    private val methodChannelGlobal = MethodChannel(messenger, "modern_classes_patna/broadcast")

    private val eventChannelView = EventChannel(messenger, "modern_classes_patna/broadcast_events_$viewId")
    private val eventChannelGlobal = EventChannel(messenger, "modern_classes_patna/broadcast/events")

    init {
        methodChannelView.setMethodCallHandler(this)
        methodChannelGlobal.setMethodCallHandler(this)

        eventChannelView.setStreamHandler(this)
        eventChannelGlobal.setStreamHandler(this)
    }

    override fun getView(): View = openGlView

    override fun dispose() {
        methodChannelView.setMethodCallHandler(null)
        methodChannelGlobal.setMethodCallHandler(null)
        eventChannelView.setStreamHandler(null)
        eventChannelGlobal.setStreamHandler(null)
        eventSink = null

        try {
            sensorRotationManager?.stop()
            sensorRotationManager = null
            orientationListener?.disable()
            orientationListener = null
        } catch (ignored: Exception) {
        }

        try {
            if (rtmpCamera2.isStreaming) {
                rtmpCamera2.stopStream()
            }
            if (rtmpCamera2.isOnPreview) {
                rtmpCamera2.stopPreview()
            }
        } catch (ignored: Exception) {
            // Ignore hardware release exceptions during activity teardown
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initializePreview", "initStream" -> handleInitializePreview(call, result)
            "startPreview" -> handleStartPreview(call, result)
            "stopPreview" -> handleStopPreview(result)
            "setOrientation" -> handleSetOrientation(call, result)
            "prepare" -> handlePrepare(call, result)
            "startStream" -> handleStartStream(call, result)
            "stopStream" -> handleStopStream(result)
            "switchCamera" -> handleSwitchCamera(result)
            "toggleMute" -> handleToggleMute(result)
            "isStreaming" -> result.success(rtmpCamera2.isStreaming)
            "isOnPreview" -> result.success(rtmpCamera2.isOnPreview)
            "isAudioMuted" -> result.success(rtmpCamera2.isAudioMuted)
            else -> result.notImplemented()
        }
    }

    private fun getDisplayRotationDegrees(): Int {
        return try {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
            val display = wm?.defaultDisplay
            when (display?.rotation) {
                Surface.ROTATION_0 -> 90      // Normal Portrait
                Surface.ROTATION_90 -> 0      // Landscape (rotated counter-clockwise)
                Surface.ROTATION_180 -> 270   // Reverse Portrait
                Surface.ROTATION_270 -> 180   // Reverse Landscape (rotated clockwise)
                else -> 90
            }
        } catch (e: Exception) {
            try {
                CameraHelper.getCameraOrientation(context)
            } catch (_: Exception) {
                90
            }
        }
    }

    private fun applyCameraOrientation(degrees: Int? = null) {
        val targetRotation = degrees ?: getDisplayRotationDegrees()
        if (targetRotation != currentRotation) {
            currentRotation = targetRotation
            try {
                // In Pedro RootEncoder:
                // When targetRotation is 0 (Landscape), preview GL rotation is 270.
                // When targetRotation is 90 (Portrait), preview GL rotation is 0.
                // When targetRotation is 180 (Reverse Landscape), preview GL rotation is 90.
                // When targetRotation is 270 (Reverse Portrait), preview GL rotation is 180.
                val glRotation = if (targetRotation == 0) 270 else (targetRotation - 90 + 360) % 360
                rtmpCamera2.glInterface.setRotation(glRotation)
                rtmpCamera2.glInterface.setStreamRotation(targetRotation)
            } catch (ignored: Exception) {
                // Ignore if OpenGL rendering pipeline is not initialized yet
            }
        }
    }

    private fun startOrientationListener(forceLandscape: Boolean = true) {
        if (sensorRotationManager == null) {
            try {
                sensorRotationManager = SensorRotationManager(context, false, false) { rotation, isLandscape ->
                    try {
                        rtmpCamera2.glInterface.setRotation(rotation)
                        val streamRot = if (forceLandscape) 0 else (if (isLandscape) 0 else 90)
                        currentRotation = streamRot
                        rtmpCamera2.glInterface.setStreamRotation(streamRot)
                    } catch (ignored: Exception) {
                    }
                }
            } catch (ignored: Exception) {
            }
        }
        try {
            sensorRotationManager?.start()
        } catch (ignored: Exception) {
        }
    }

    private fun handleSetOrientation(call: MethodCall, result: MethodChannel.Result) {
        val isLandscape = call.argument<Boolean>("isLandscape") ?: true
        val degrees = call.argument<Int>("degrees") ?: (if (isLandscape) 0 else 90)
        applyCameraOrientation(degrees)
        result.success(true)
    }

    private fun hasPermissions(): Boolean {
        val cameraGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
        val audioGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        return cameraGranted && audioGranted
    }

    private fun handleInitializePreview(call: MethodCall, result: MethodChannel.Result) {
        if (!hasPermissions()) {
            result.error("PERMISSION_DENIED", "Camera and microphone permissions are required", null)
            return
        }
        try {
            val isLandscape = call.argument<Boolean>("isLandscape") ?: true
            val targetRotation = if (isLandscape) 0 else getDisplayRotationDegrees()
            currentRotation = targetRotation

            if (!rtmpCamera2.isOnPreview) {
                rtmpCamera2.startPreview(CameraHelper.Facing.BACK, targetRotation)
            } else {
                applyCameraOrientation(targetRotation)
            }
            startOrientationListener(forceLandscape = isLandscape)
            result.success(true)
        } catch (e: Exception) {
            result.error("PREVIEW_ERROR", e.message, null)
        }
    }

    private fun handleStartPreview(call: MethodCall, result: MethodChannel.Result) {
        if (!hasPermissions()) {
            result.error("PERMISSION_DENIED", "Camera and microphone permissions are required", null)
            return
        }
        try {
            val isLandscape = call.argument<Boolean>("isLandscape") ?: true
            val targetRotation = if (isLandscape) 0 else getDisplayRotationDegrees()
            currentRotation = targetRotation

            if (!rtmpCamera2.isOnPreview) {
                rtmpCamera2.startPreview(CameraHelper.Facing.BACK, targetRotation)
            } else {
                applyCameraOrientation(targetRotation)
            }
            startOrientationListener(forceLandscape = isLandscape)
            result.success(true)
        } catch (e: Exception) {
            result.error("PREVIEW_ERROR", e.message, null)
        }
    }

    private fun handleStopPreview(result: MethodChannel.Result) {
        try {
            if (rtmpCamera2.isOnPreview) {
                rtmpCamera2.stopPreview()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("PREVIEW_ERROR", e.message, null)
        }
    }

    private fun handlePrepare(call: MethodCall, result: MethodChannel.Result): Boolean {
        val isLandscape = call.argument<Boolean>("isLandscape") ?: true
        val width = call.argument<Int>("width") ?: (if (isLandscape) 1280 else 720)
        val height = call.argument<Int>("height") ?: (if (isLandscape) 720 else 1280)
        val fps = call.argument<Int>("fps") ?: 30
        val bitrate = call.argument<Int>("bitrate") ?: (2000 * 1024)
        val iFrameInterval = call.argument<Int>("iFrameInterval") ?: 2
        val rotation = call.argument<Int>("rotation") ?: (if (isLandscape) 0 else 90)

        currentRotation = rotation
        val audioOk = rtmpCamera2.prepareAudio()
        val videoOk = rtmpCamera2.prepareVideo(width, height, fps, bitrate, iFrameInterval, rotation)

        val success = audioOk && videoOk
        if (!success) {
            result.error("PREPARE_FAILED", "Hardware encoder initialization failed (audio: $audioOk, video: $videoOk)", null)
            return false
        }
        result.success(true)
        return true
    }

    private fun handleStartStream(call: MethodCall, result: MethodChannel.Result) {
        val rawUrl = call.argument<String>("url")?.trim() ?: ""
        val streamKey = call.argument<String>("streamKey")?.trim() ?: ""

        if (rawUrl.isEmpty()) {
            result.error("INVALID_URL", "Streaming URL cannot be empty", null)
            return
        }
        if (!rawUrl.startsWith("rtmp://") && !rawUrl.startsWith("rtmps://")) {
            result.error("INVALID_PROTOCOL", "Endpoint must begin with rtmp:// or rtmps://", null)
            return
        }
        if (!hasPermissions()) {
            result.error("PERMISSION_DENIED", "Camera and microphone permissions are required", null)
            return
        }
        if (rtmpCamera2.isStreaming) {
            result.success(true) // Idempotent success
            return
        }

        // Determine orientation and stream dimensions
        val isLandscape = call.argument<Boolean>("isLandscape") ?: true
        val width = call.argument<Int>("width") ?: (if (isLandscape) 1280 else 720)
        val height = call.argument<Int>("height") ?: (if (isLandscape) 720 else 1280)
        val fps = call.argument<Int>("fps") ?: 30
        val bitrate = call.argument<Int>("bitrate") ?: (2000 * 1024)
        val iFrameInterval = call.argument<Int>("iFrameInterval") ?: 2
        val rotation = call.argument<Int>("rotation") ?: (if (isLandscape) 0 else 90)

        currentRotation = rotation
        val audioOk = rtmpCamera2.prepareAudio()
        val videoOk = rtmpCamera2.prepareVideo(width, height, fps, bitrate, iFrameInterval, rotation)

        if (!audioOk || !videoOk) {
            result.error("PREPARE_FAILED", "Failed to prepare MediaCodec encoders (audio: $audioOk, video: $videoOk)", null)
            return
        }

        val fullUrl = if (streamKey.isNotEmpty()) {
            if (rawUrl.endsWith("/")) "$rawUrl$streamKey" else "$rawUrl/$streamKey"
        } else {
            rawUrl
        }

        try {
            rtmpCamera2.startStream(fullUrl)
            result.success(true)
        } catch (e: Exception) {
            result.error("START_STREAM_FAILED", e.message, null)
        }
    }

    private fun handleStopStream(result: MethodChannel.Result) {
        try {
            if (rtmpCamera2.isStreaming) {
                rtmpCamera2.stopStream()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("STOP_STREAM_FAILED", e.message, null)
        }
    }

    private fun handleSwitchCamera(result: MethodChannel.Result) {
        try {
            rtmpCamera2.switchCamera()
            result.success(true)
        } catch (e: Exception) {
            result.error("SWITCH_CAMERA_FAILED", e.message, null)
        }
    }

    private fun handleToggleMute(result: MethodChannel.Result) {
        try {
            if (rtmpCamera2.isAudioMuted) {
                rtmpCamera2.enableAudio()
            } else {
                rtmpCamera2.disableAudio()
            }
            result.success(rtmpCamera2.isAudioMuted)
        } catch (e: Exception) {
            result.error("MUTE_FAILED", e.message, null)
        }
    }

    // ConnectChecker implementations
    override fun onConnectionStarted(url: String) {
        postEvent(mapOf("event" to "connecting", "url" to sanitizeUrl(url)))
    }

    override fun onConnectionSuccess() {
        postEvent(mapOf("event" to "connected"))
    }

    override fun onConnectionFailed(reason: String) {
        postEvent(mapOf("event" to "failed", "reason" to reason))
    }

    override fun onNewBitrate(bitrate: Long) {
        postEvent(mapOf("event" to "bitrate", "bitrate" to bitrate))
    }

    override fun onDisconnect() {
        postEvent(mapOf("event" to "disconnected"))
    }

    override fun onAuthError() {
        postEvent(mapOf("event" to "auth_error"))
    }

    override fun onAuthSuccess() {
        postEvent(mapOf("event" to "auth_success"))
    }

    private fun postEvent(event: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(event)
        }
    }

    private fun sanitizeUrl(url: String): String {
        return try {
            val uri = URI(url)
            val path = uri.path ?: ""
            val lastSlash = path.lastIndexOf('/')
            if (lastSlash >= 0 && lastSlash < path.length - 1) {
                val base = path.substring(0, lastSlash + 1)
                val portStr = if (uri.port > 0) ":${uri.port}" else ""
                "${uri.scheme}://${uri.host ?: ""}$portStr$base***"
            } else {
                val portStr = if (uri.port > 0) ":${uri.port}" else ""
                "${uri.scheme}://${uri.host ?: ""}$portStr/..."
            }
        } catch (e: Exception) {
            "rtmps://***"
        }
    }

    // EventChannel.StreamHandler implementations
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }
}
