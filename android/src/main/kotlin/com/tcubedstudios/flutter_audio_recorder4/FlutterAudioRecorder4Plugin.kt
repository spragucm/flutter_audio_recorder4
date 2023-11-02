package com.tcubedstudios.flutter_audio_recorder4

import android.Manifest.permission.RECORD_AUDIO
import android.Manifest.permission.WRITE_EXTERNAL_STORAGE
import android.content.pm.PackageManager.PERMISSION_GRANTED
import android.media.AudioFormat.CHANNEL_IN_MONO
import android.media.AudioFormat.ENCODING_PCM_16BIT
import android.media.AudioRecord
import android.media.MediaRecorder.AudioSource.MIC
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.tcubedstudios.flutter_audio_recorder4.MethodCalls.*
import com.tcubedstudios.flutter_audio_recorder4.MethodCalls.Companion.toMethodCall
import com.tcubedstudios.flutter_audio_recorder4.RecorderState.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import kotlin.math.abs
import kotlin.math.ln

class FlutterAudioRecorder4Plugin(
  var registrar: Registrar
): FlutterPlugin, MethodCallHandler, PluginRegistry.RequestPermissionsResultListener {

  companion object {
    private const val LOG_NAME = "AndroidAudioRecorder"
    private const val PERMISSIONS_REQUEST_CODE = 200
    private const val RECORDER_BPP: Byte = 16;
    private const val DEFAULTS_PEAK_POWER = -120.0
    private const val DEFAULTS_AVERAGE_POWER = -120.0
    private const val DEFAULTS_DATA_SIZE = 0L
    private const val DEFAULTS_BUFFER_SIZE = 1024

    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "flutter_audio_recorder4")
      channel.setMethodCallHandler(FlutterAudioRecorder4Plugin(registrar))
    }
  }

  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  private var allPermissionsGranted = false
  private var sampleRate = 16000L//Khz
  private var dataSize = DEFAULTS_DATA_SIZE
  private var peakPower = DEFAULTS_PEAK_POWER
  private var averagePower = DEFAULTS_AVERAGE_POWER
  private var recorderState = UNSET
  private var bufferSize = DEFAULTS_BUFFER_SIZE
  private var fileOutputStream: FileOutputStream? = null
  private var recordingThread: Thread? = null
  private var recorder: AudioRecord? = null
  private var filePath: String? = null
  private var fileExtension: String? = null
  private var result: Result? = null
  private val tempFileName: String?
    get() = filePath?.plus(".temp")
  private val duration: Int
    get() = (dataSize / (sampleRate * 2 * 1)).toInt()

  init {
    registrar.addRequestPermissionsResultListener(this)
  }

  //region Flutter plugin binding
  override fun onAttachedToEngine(flutterPluginBinding: FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_audio_recorder4")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
  //endregion

  //region Handle method calls from flutter
  override fun onMethodCall(call: MethodCall, result: Result) {
    this.result = result

    when(call.method.toMethodCall()) {
      REQUEST_PERMISSIONS -> handleRequestPermissions()
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

  //region Permission handling
  private fun handleRequestPermissions() {
    if (areAllPermissionsGranted())
      result?.success(true)
    else
      requestPermissions()
  }

  private fun areAllPermissionsGranted() = if (VERSION.SDK_INT >= VERSION_CODES.M) {
    // if after [Marshmallow], we need to check permission on runtime
    ContextCompat.checkSelfPermission(registrar.context(), RECORD_AUDIO) == PERMISSION_GRANTED &&
    ContextCompat.checkSelfPermission(registrar.context(), WRITE_EXTERNAL_STORAGE) == PERMISSION_GRANTED
  } else {
    ContextCompat.checkSelfPermission(registrar.context(), RECORD_AUDIO) == PERMISSION_GRANTED
  }

  private fun requestPermissions() {
    registrar.activity()?.let { activity ->
      val permissions = if(VERSION.SDK_INT >= VERSION_CODES.M) arrayOf(RECORD_AUDIO, WRITE_EXTERNAL_STORAGE) else arrayOf(RECORD_AUDIO)
      ActivityCompat.requestPermissions(activity, permissions, PERMISSIONS_REQUEST_CODE)
    }
  }

  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
    if (requestCode == PERMISSIONS_REQUEST_CODE) {
      allPermissionsGranted = grantResults.isNotEmpty() && grantResults.all { it == PERMISSION_GRANTED }
      if (allPermissionsGranted) handleAllPermissionsGranted()
      return true
    }
    return false
  }

  private fun handleAllPermissionsGranted() {
    //Nothing to do now. Maybe in the future.
  }
  //endregion

  //region Recorder

  //endregion
  private fun handleInit(call: MethodCall, result: Result) {
    resetRecorder()

    sampleRate = call.argument<Any>("sampleRate").toString().toLong()
    filePath = call.argument<Any>("path").toString()
    fileExtension = call.argument<Any>("extension").toString()//TODO - CHRIS - use audioFormat?
    bufferSize = AudioRecord.getMinBufferSize(sampleRate.toInt(), CHANNEL_IN_MONO, ENCODING_PCM_16BIT)
    recorderState = INITIALIZED

    val initResult = java.util.HashMap<String, Any>()//TODO - CHRIS - is hashmap required?
    initResult["duration"] = 0
    initResult["path"] = filePath
    initResult["audioFormat"] = fileExtension//TODO - CHRIS - use audioFormat?
    initResult["peakPower"] = peakPower
    initResult["averagePower"] = averagePower
    initResult["isMeteringEnabled"] = true
    initResult["recorderState"] = recorderState
    result.success(initResult)
  }

  private fun handleCurrent(call: MethodCall, result: Result) {
    val currentResult = java.util.HashMap<String, Any>()//TODO - CHRIS - is hashmap required?
    currentResult["duration"] = duration * 1000
    currentResult["path"] = if (recorderState == STOPPED) filePath else tempFileName
    currentResult["audioFormat"] = fileExtension
    currentResult["peakPower"] = peakPower
    currentResult["averagePower"] = averagePower
    currentResult["isMeteringEnabled"] = true
    currentResult["recorderState"] = recorderState
    result.success(currentResult)
  }

  private fun handleStart(call: MethodCall, result: Result) {
    recorder = AudioRecord(MIC, sampleRate.toInt(), CHANNEL_IN_MONO, ENCODING_PCM_16BIT, bufferSize)

    try {
      fileOutputStream = FileOutputStream(tempFileName)
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
    result.success(null)
  }

  private fun handleStop(call: MethodCall, result: Result) {
    if (recorderState == STOPPED) {
      result.success(null)
    } else {
      recorderState = STOPPED

      // Return Recording Object
      val currentResult = HashMap<String, Any>()
      currentResult["duration"] = duration * 1000
      currentResult["path"] = filePath
      currentResult["audioFormat"] = fileExtension
      currentResult["peakPower"] = peakPower
      currentResult["averagePower"] = averagePower
      currentResult["isMeteringEnabled"] = true
      currentResult["recorderState"] = recorderState

      resetRecorder()
      recordingThread = null
      recorder?.stop()
      recorder?.release()

      try {
        fileOutputStream?.close()
      } catch (exception: IOException) {
        exception.printStackTrace()
      }

      copyWaveFile(tempFileName, filePath)
      deleteTempFile()

      result.success(currentResult)
    }
  }

  private fun resetRecorder() {
    peakPower = DEFAULTS_PEAK_POWER
    averagePower = DEFAULTS_AVERAGE_POWER
    dataSize = DEFAULTS_DATA_SIZE
  }

  private fun startThread() {
    recordingThread = Thread({ processAudioStream() }, "Audio Processing Thread")
    recordingThread?.start()
  }

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

  private fun deleteTempFile() {
    tempFileName?.let {
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

  private fun updatePowers(byteArray: ByteArray) {
    val shortArray = byteArray.toShortArray()
    val sampleVal: Short = shortArray.last()
    val escapeStatusList = arrayOf(PAUSED, STOPPED, INITIALIZED, UNSET)

    averagePower = if (sampleVal == 0.toShort() || escapeStatusList.contains(recorderState)) {
      DEFAULTS_AVERAGE_POWER //to match iOS silent case
    } else {
      // iOS factor : to match iOS power level
      val iOsFactor = 0.25
      20 * ln(abs(sampleVal.toDouble()) / 32768.0) * iOsFactor
    }

    peakPower = averagePower
  }
}
