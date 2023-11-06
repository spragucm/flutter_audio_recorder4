package com.tcubedstudios.flutter_audio_recorder4

import android.app.Activity
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.Registrar

//Registrar is passed for Android plugin v1 compatibility
abstract class ActivityAwarePlugin(
    registrar: Registrar? = null,
    methodChannel: MethodChannel? = null
) : FlutterPluginImpl(registrar, methodChannel), ActivityAware {

    var activity: Activity? = registrar?.activity()         //Available in Android plugin v1 and v2
    protected var binding: ActivityPluginBinding? = null    //Only available in Android plugin v2

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        binding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.binding = binding
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        binding = null
        activity = null
    }
}