package com.tcubedstudios.flutter_audio_recorder4

data class PermissionToRequest(
    val permission: String,
    val minSdk: Int? = NO_CONSTRAINT,
    val maxSdk: Int? = NO_CONSTRAINT
) {
    companion object {
        val NO_CONSTRAINT : Int? = null
    }
}