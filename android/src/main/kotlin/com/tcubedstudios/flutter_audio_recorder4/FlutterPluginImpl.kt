package com.tcubedstudios.flutter_audio_recorder4

import androidx.annotation.CallSuper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

abstract class FlutterPluginImpl(
    val registrar: PluginRegistry.Registrar? = null,
    protected var methodChannel: MethodChannel? = null
) : FlutterPlugin, MethodCallHandler {

    /// The MethodChannel will communication between Flutter and native Android
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity

    companion object {
        // Android plugin v1 binding
        @JvmStatic
        fun registerWith(registrar: PluginRegistry.Registrar) {
            val methodChannel = MethodChannel(registrar.messenger(), "flutter_audio_recorder4")
            val plugin = FlutterAudioRecorder4Plugin(registrar, methodChannel)
            methodChannel.setMethodCallHandler(plugin)
        }
    }

    //region Flutter plugin binding
    // Android plugin v2 binding
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_audio_recorder4").apply {
            setMethodCallHandler(this@FlutterPluginImpl)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
    }
    //endregion

    @CallSuper
    override fun onMethodCall(call: MethodCall, result: Result) {}
}