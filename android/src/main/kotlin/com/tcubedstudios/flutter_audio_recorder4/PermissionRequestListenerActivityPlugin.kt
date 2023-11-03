package com.tcubedstudios.flutter_audio_recorder4

import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

abstract class PermissionRequestListenerActivityPlugin : ActivityAwarePlugin(), PluginRegistry.RequestPermissionsResultListener {

    companion object {
        fun registerWith(registrar: PluginRegistry.Registrar) {
            MethodChannel(registrar.messenger(), "flutter_audio_recorder4").apply {
                val plugin = FlutterAudioRecorder4Plugin()
                setMethodCallHandler(plugin)
                registrar.addRequestPermissionsResultListener(plugin)
            }
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        super.onAttachedToActivity(binding)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        binding?.removeRequestPermissionsResultListener(this)
        super.onDetachedFromActivityForConfigChanges()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        super.onReattachedToActivityForConfigChanges(binding)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        binding?.removeRequestPermissionsResultListener(this)
        super.onDetachedFromActivity()
    }
}