package com.tcubedstudios.flutter_audio_recorder4

fun ByteArray.toShortArray() = ShortArray(this.size / 2) {
    (this[it * 2].toUByte().toInt() + (this[(it * 2) + 1].toInt() shl 8)).toShort()
}