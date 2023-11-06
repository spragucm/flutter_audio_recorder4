package com.tcubedstudios.flutter_audio_recorder4

import androidx.annotation.CallSuper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

abstract class FlutterPluginImpl(val registrar: PluginRegistry.Registrar? = null) : FlutterPlugin, MethodCallHandler {

    companion object {
        /// The MethodChannel that will the communication between Flutter and native Android
        /// This local reference serves to register the plugin with the Flutter Engine and unregister it
        /// when the Flutter Engine is detached from the Activity
        @JvmStatic
        private lateinit var methodChannel : MethodChannel

        // Android plugin v1 binding
        @JvmStatic
        fun registerWith(registrar: PluginRegistry.Registrar) {
            methodChannel = MethodChannel(registrar.messenger(), "flutter_audio_recorder4")
            val plugin = FlutterAudioRecorder4Plugin(registrar)
            methodChannel.setMethodCallHandler(plugin)
        }
    }

    protected var result: Result? = null

    //region Flutter plugin binding
    // Android plugin v2 binding
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_audio_recorder4")
        methodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
    }
    //endregion

    @CallSuper
    override fun onMethodCall(call: MethodCall, result: Result) {
        this.result = result
    }
}