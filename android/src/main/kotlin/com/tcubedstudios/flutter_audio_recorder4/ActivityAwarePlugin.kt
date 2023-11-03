package com.tcubedstudios.flutter_audio_recorder4

import android.app.Activity
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

abstract class ActivityAwarePlugin : FlutterPluginImpl(), ActivityAware {

    protected var binding: ActivityPluginBinding? = null
    protected val activity: Activity?
        get() = binding?.activity

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        binding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.binding = binding
    }

    override fun onDetachedFromActivity() {
        binding = null
    }
}