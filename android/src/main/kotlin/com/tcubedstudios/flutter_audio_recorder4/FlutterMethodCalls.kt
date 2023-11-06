package com.tcubedstudios.flutter_audio_recorder4

enum class FlutterMethodCalls(var methodName: String) {

    HAS_PERMISSIONS("hasPermissions");

    companion object {
        fun String.toFlutterMethodCall() = FlutterMethodCalls.values().firstOrNull { it.methodName == this }
    }
}