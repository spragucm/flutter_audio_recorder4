package com.tcubedstudios.flutter_audio_recorder4

import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.AUDIO_FORMAT
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.AVERAGE_POWER
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.DURATION
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.EXTENSION
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.FILEPATH
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.METERING_ENABLED
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.PEAK_POWER
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.RECORDER_STATE
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.SAMPLE_RATE
import android.Manifest.permission.RECORD_AUDIO
import android.Manifest.permission.WRITE_EXTERNAL_STORAGE
import android.media.AudioFormat.CHANNEL_IN_MONO
import android.media.AudioFormat.ENCODING_PCM_16BIT
import android.media.AudioRecord
import android.media.MediaRecorder.AudioSource.MIC
import android.os.Build.VERSION_CODES
import com.tcubedstudios.flutter_audio_recorder4.AudioExtension.Companion.toAudioFormat
import com.tcubedstudios.flutter_audio_recorder4.MethodCalls.*
import com.tcubedstudios.flutter_audio_recorder4.MethodCalls.Companion.toMethodCall
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.FILEPATH_TEMP
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.MESSAGE
import com.tcubedstudios.flutter_audio_recorder4.RecorderState.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import kotlin.math.abs
import kotlin.math.ln

//TODO - CHRIS - use a state machine
//https://github.com/Tinder/StateMachine -> supports kotlin and swift

//Registrar is passed for Android plugin v1 compatibility
class FlutterAudioRecorder4Plugin(
    registrar: Registrar? = null,
    methodChannel: MethodChannel? = null
) : PermissionRequestListenerActivityPlugin(registrar, methodChannel) {

  //TODO - CHRIS
  // If recorder is ever expected to operate in a background service, implement ServiceAware interface.

  companion object {
    private const val RECORDER_BPP: Byte = 16;
    private const val DEFAULTS_PEAK_POWER = -120.0
    private const val DEFAULTS_AVERAGE_POWER = -120.0
    private const val DEFAULTS_DATA_SIZE = 0L
    private const val DEFAULTS_BUFFER_SIZE = 1024
    private const val IOS_POWER_LEVEL_FACTOR = 0.25// iOS factor : to match iOS power level
  }

  override val permissionsToRequest = listOf(
    PermissionToRequest(RECORD_AUDIO),
    PermissionToRequest(WRITE_EXTERNAL_STORAGE, maxSdk = VERSION_CODES.LOLLIPOP_MR1)//WR_EX_ST was removed in M, so last allowed version is LP_MR1
  )

  private var sampleRate = 16000L//Khz
  private var dataSize = DEFAULTS_DATA_SIZE
  private var peakPower = DEFAULTS_PEAK_POWER
  private var averagePower = DEFAULTS_AVERAGE_POWER
  private var recorderState = UNSET
  private var bufferSize = DEFAULTS_BUFFER_SIZE
  private var fileOutputStream: FileOutputStream? = null
  private var recordingThread: Thread? = null
  private var recorder: AudioRecord? = null
  private var filepath: String? = null
  private var extension: String? = null
  private var message: String? = null

  private val filepathTemp: String?
    get() = filepath?.plus(".temp")
  private val duration: Int
    get() = (dataSize / (sampleRate * 2 * 1)).toInt()

  //region Handle method calls from flutter
  override fun onMethodCall(call: MethodCall, result: Result) {
    super.onMethodCall(call, result)

    when(call.method.toMethodCall()) {
      INIT -> handleInit(call, result)
      CURRENT -> handleCurrent(call, result)
      START -> handleStart(call, result)
      PAUSE -> handlePause(call, result)
      RESUME -> handleResume(call, result)
      STOP -> handleStop(call, result)
      else -> result.notImplemented()
    }
  }
  //endregion

  //region Recorder
  private fun handleInit(call: MethodCall, result: Result) {
    resetRecorder()

      filepath = call.argument<Any?>(FILEPATH)?.toString()
    extension = call.argument<Any?>(EXTENSION)?.toString()
    sampleRate = call.argument<Any?>(SAMPLE_RATE)?.toString()?.toLong() ?: 0L
    bufferSize = AudioRecord.getMinBufferSize(sampleRate.toInt(), CHANNEL_IN_MONO, ENCODING_PCM_16BIT)
    recorderState = if (filePath.isNullOrBlank().not() && extension.isNullOrBlank().not()) INITIALIZED else UNSET

    val initResult = mapOf<String, Any?>(
            FILEPATH to filePath,
            EXTENSION to extension,
            DURATION to 0,
            AUDIO_FORMAT to extension?.toAudioFormat()?.name,
            RECORDER_STATE to recorderState.value,
            METERING_ENABLED to true,
            PEAK_POWER to peakPower,
            AVERAGE_POWER to averagePower,
            SAMPLE_RATE to sampleRate
    )

    result.success(initResult)
  }

  private fun handleCurrent(call: MethodCall, result: Result) {
    val currentResult = mapOf(
        FILEPATH to if (recorderState == STOPPED) filePath else tempFileName,
        EXTENSION to extension,
        DURATION to duration * 1000,
        AUDIO_FORMAT to extension?.toAudioFormat()?.name,
        RECORDER_STATE to recorderState.value,
        METERING_ENABLED to true,
        PEAK_POWER to peakPower,
        AVERAGE_POWER to averagePower,
        SAMPLE_RATE to sampleRate
    )

    result.success(currentResult)
  }

  private fun handleStart(call: MethodCall, result: Result) {
    recorder = AudioRecord(MIC, sampleRate.toInt(), CHANNEL_IN_MONO, ENCODING_PCM_16BIT, bufferSize)

    try {
      fileOutputStream = FileOutputStream(filepathTemp)
    } catch (exception: FileNotFoundException) {
      result.error("", "cannot find the file", null)
      return
    }

    recorder?.startRecording()
    recorderState = RECORDING
    startThread()
    result.success(null)
  }

  private fun handlePause(call: MethodCall, result: Result) {
    recorderState = PAUSED
    peakPower = DEFAULTS_PEAK_POWER
    averagePower = DEFAULTS_AVERAGE_POWER
    recorder?.stop()
    recordingThread = null
    result.success(null)
  }

  private fun handleResume(call: MethodCall, result: Result) {
    recorderState = RECORDING
    recorder?.startRecording()
    startThread()
    result.success(null)//TODO - CHRIS - why null vs success?
  }

  private fun handleStop(call: MethodCall, result: Result) {
    if (recorderState == STOPPED) {
      result.success(null)
    } else {
      recorderState = STOPPED

      val currentResult = mapOf(
        DURATION to duration * 1000,
        FILEPATH to filePath,
        AUDIO_FORMAT to extension,
        PEAK_POWER to peakPower,
        AVERAGE_POWER to averagePower,
        METERING_ENABLED to true,
        RECORDER_STATE to recorderState
      )
      
      resetRecorder()
      recordingThread = null
      recorder?.stop()
      recorder?.release()

      try {
        fileOutputStream?.close()
      } catch (exception: IOException) {
        exception.printStackTrace()
      }

      filepathTemp?.let { tempFileName ->
        filepath?.let { filePath ->
          copyWaveFile(tempFileName, filePath)
        }
      }

      deleteTempFile()

      result.success(currentResult)
    }
  }

  private fun resetRecorder() {
    peakPower = DEFAULTS_PEAK_POWER
    averagePower = DEFAULTS_AVERAGE_POWER
    dataSize = DEFAULTS_DATA_SIZE
  }
  //endregion

  //region Audio Stream
  private fun processAudioStream() {
    val size = bufferSize
    val bData = ByteArray(size)

    while (recorderState === RECORDING) {
      recorder?.read(bData, 0, bData.size)
      dataSize += bData.size.toLong()
      updatePowers(bData)

      try {
        fileOutputStream?.write(bData)
      } catch (e: IOException) {
        e.printStackTrace()
      }
    }
  }

  private fun updatePowers(byteArray: ByteArray) {
    val shortArray = byteArray.toShortArray()
    val sampleVal: Short = shortArray.last()
    val escapeRecorderStateList = arrayOf(PAUSED, STOPPED, INITIALIZED, UNSET)

    averagePower = if (sampleVal == 0.toShort() || escapeRecorderStateList.contains(recorderState)) {
      DEFAULTS_AVERAGE_POWER //to match iOS silent case
    } else {
      20 * ln(abs(sampleVal.toDouble()) / 32768.0) * IOS_POWER_LEVEL_FACTOR
    }

    peakPower = averagePower
  }
  //endregion

  //region Threads
  private fun startThread() {
    recordingThread = Thread({ processAudioStream() }, "Audio Processing Thread")
    recordingThread?.start()
  }
  //endregion

  //region Files
  private fun deleteTempFile() {
    filepathTemp?.let {
      val file = File(it)
      if (file.exists()) file.delete()
    }
  }

  private fun copyWaveFile(inputFileName: String, outputFileName: String) {
    try {
      val inputFileStream = FileInputStream(inputFileName)
      val outputFileStream = FileOutputStream(outputFileName)
      val totalAudioLength = inputFileStream.channel.size()
      val totalDataLength = totalAudioLength + 36

      val channels = 1
      val byteRate = RECORDER_BPP * sampleRate * channels / 8
      writeWaveFileHeader(outputFileStream, totalAudioLength, totalDataLength, sampleRate, channels, byteRate)

      val data = ByteArray(bufferSize)
      while (inputFileStream.read(data) != -1) {
        outputFileStream.write(data)
      }

      inputFileStream.close()
      outputFileStream.close()

    } catch (exception: FileNotFoundException) {
      exception.printStackTrace()
    } catch (exception: IOException) {
      exception.printStackTrace()
    }
  }

  @Throws (IOException::class)
  private fun writeWaveFileHeader(
    out: FileOutputStream,
    totalAudioLength: Long,
    totalDataLength: Long,
    longSampleRate: Long,
    channels: Int,
    byteRate: Long
  ) {
    try {
      val header = ByteArray(44)

      header[0] = 'R'.code.toByte() // RIFF/WAVE header

      header[1] = 'I'.code.toByte()
      header[2] = 'F'.code.toByte()
      header[3] = 'F'.code.toByte()
      header[4] = (totalDataLength and 0xffL).toByte()
      header[5] = (totalDataLength shr 8 and 0xffL).toByte()
      header[6] = (totalDataLength shr 16 and 0xffL).toByte()
      header[7] = (totalDataLength shr 24 and 0xffL).toByte()
      header[8] = 'W'.code.toByte()
      header[9] = 'A'.code.toByte()
      header[10] = 'V'.code.toByte()
      header[11] = 'E'.code.toByte()
      header[12] = 'f'.code.toByte() // 'fmt ' chunk

      header[13] = 'm'.code.toByte()
      header[14] = 't'.code.toByte()
      header[15] = ' '.code.toByte()
      header[16] = 16 // 4 bytes: size of 'fmt ' chunk

      header[17] = 0
      header[18] = 0
      header[19] = 0
      header[20] = 1 // format = 1

      header[21] = 0
      header[22] = channels.toByte()
      header[23] = 0
      header[24] = (longSampleRate and 0xffL).toByte()
      header[25] = (longSampleRate shr 8 and 0xffL).toByte()
      header[26] = (longSampleRate shr 16 and 0xffL).toByte()
      header[27] = (longSampleRate shr 24 and 0xffL).toByte()
      header[28] = (byteRate and 0xffL).toByte()
      header[29] = (byteRate shr 8 and 0xffL).toByte()
      header[30] = (byteRate shr 16 and 0xffL).toByte()
      header[31] = (byteRate shr 24 and 0xffL).toByte()
      header[32] = (channels * RECORDER_BPP.toInt() shr 3).toByte()
      header[33] = (channels * RECORDER_BPP.toInt() shr 11).toByte()
      header[34] = RECORDER_BPP // bits per sample

      header[35] = 0
      header[36] = 'd'.code.toByte()
      header[37] = 'a'.code.toByte()
      header[38] = 't'.code.toByte()
      header[39] = 'a'.code.toByte()
      header[40] = (totalAudioLength and 0xffL).toByte()
      header[41] = (totalAudioLength shr 8 and 0xffL).toByte()
      header[42] = (totalAudioLength shr 16 and 0xffL).toByte()
      header[43] = (totalAudioLength shr 24 and 0xffL).toByte()

      out.write(header, 0, 44)
    } catch (exception: IOException) {
      throw exception
    }
  }
  //endregion
}
