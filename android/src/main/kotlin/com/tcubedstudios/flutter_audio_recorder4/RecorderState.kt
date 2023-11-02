package com.tcubedstudios.flutter_audio_recorder4

enum class RecorderState(val value: String) {
    UNSET("unset"),
    INITIALIZED("initialized"),
    RECORDING("recording"),
    PAUSED("paused"),
    STOPPED("stopped")
}