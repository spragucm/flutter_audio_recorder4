package com.tcubedstudios.flutter_audio_recorder4

import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

open class PlatformInfoHandler(
    registrar: PluginRegistry.Registrar? = null,
    methodChannel: MethodChannel? = null
) : ActivityAwarePlugin(registrar, methodChannel) {
}