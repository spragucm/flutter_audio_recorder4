package com.tcubedstudios.flutter_audio_recorder4

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry

abstract class FlutterPluginImpl : FlutterPlugin, MethodCallHandler {

    companion object {
        // Note that the plugin should still contain the static registerWith() method to remain compatible with apps that don’t use the v2 Android embedding.
        // Apps using the v2 Android embedding use onAttachedToEngine().
        // Only registerWith or onAttachedToEngine will be called, not both.
        // https://docs.flutter.dev/release/breaking-changes/plugin-api-migration
        fun registerWith(registrar: PluginRegistry.Registrar) {
            MethodChannel(registrar.messenger(), "flutter_audio_recorder4").apply {
                val plugin = FlutterAudioRecorder4Plugin()
                setMethodCallHandler(plugin)
                registrar.addRequestPermissionsResultListener(plugin)
            }
        }
    }

    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel : MethodChannel

    //region Flutter plugin binding
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_audio_recorder4")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
    //endregion
}