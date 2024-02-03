package com.tcubedstudios.flutter_audio_recorder4

import androidx.annotation.CallSuper
import com.tcubedstudios.flutter_audio_recorder4.MethodCalls.Companion.toMethodCall
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.MethodChannel.Result

open class PlatformInfoHandlerPlugin(
    registrar: PluginRegistry.Registrar? = null,
    methodChannel: MethodChannel? = null
) : ActivityAwarePlugin(registrar, methodChannel) {

    @CallSuper
    override fun onMethodCall(call: MethodCall, result: Result) {
        when(call.method.toMethodCall()) {
            MethodCalls.GET_PLATFORM_VERSION -> getPlatformVersion(result)
            else -> super.onMethodCall(call, result)
        }
    }

    private fun getPlatformVersion(result: Result){
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
    }

}