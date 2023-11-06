package com.tcubedstudios.flutter_audio_recorder4

import android.content.pm.PackageManager.PERMISSION_GRANTED
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.tcubedstudios.flutter_audio_recorder4.MethodCalls.Companion.toMethodCall
import com.tcubedstudios.flutter_audio_recorder4.MethodCalls.HAS_PERMISSIONS
import com.tcubedstudios.flutter_audio_recorder4.MethodCalls.REVOKE_PERMISSIONS
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

//Registrar is passed for Android plugin v1 compatibility
abstract class PermissionRequestListenerActivityPlugin(
    registrar: Registrar? = null,
    methodChannel: MethodChannel? = null
) : ActivityAwarePlugin(registrar, methodChannel), PluginRegistry.RequestPermissionsResultListener {

    open val permissionsRequestCode = 200
    var allPermissionsGrantedTemp: Boolean? = null

    //Android version:permission
    //The version indicates the android version to start requesting the given permission
    abstract val permissionsToRequest: List<PermissionToRequest>

    val uniquePermissionsToRequest: Set<String>
        get() = permissionsToRequest.filter { permission ->
            val minSdk = permission.minSdk ?: 0
            val maxSdk = permission.maxSdk ?: Int.MAX_VALUE
            val sdk = Build.VERSION.SDK_INT
            sdk in minSdk..maxSdk
        }.map { it.permission }.toSet()

    //region region Add/Remove listener based on lifecycle (Android plugin v1)
    init {
        registrar?.addRequestPermissionsResultListener(this)
    }
    //endregion

    //region Add/Remove listener based on lifecycle (Android plugin v2)
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        super.onAttachedToActivity(binding)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        binding?.removeRequestPermissionsResultListener(this)
        super.onDetachedFromActivityForConfigChanges()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        super.onReattachedToActivityForConfigChanges(binding)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        binding?.removeRequestPermissionsResultListener(this)
        super.onDetachedFromActivity()
    }
    //endregion

    //region Flutter exchange handling
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        super.onMethodCall(call, result)
        when(call.method.toMethodCall()) {
            HAS_PERMISSIONS -> handleHasPermissions()
            REVOKE_PERMISSIONS -> revokePermissions()
            else -> {}
        }
    }

    fun callFlutterHasPermissions() {
        //methodChannel?.invokeMethod("", "")
    }
    //endregion

    //region Permission handling
    private fun handleHasPermissions() {
        if (areAllPermissionsGranted()) {
            result?.success(true)
        } else {
            requestPermissions()
            result?.success(false)
        }
    }

    private fun revokePermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            uniquePermissionsToRequest.forEach { permission ->
                activity?.revokeSelfPermissionOnKill(permission)
            }
            result?.success(true)
        }
        result?.success(false)
    }

    private fun areAllPermissionsGranted() : Boolean {
        activity?.let { activity ->
            return uniquePermissionsToRequest.all { permission ->
                ContextCompat.checkSelfPermission(activity, permission) == PERMISSION_GRANTED
            }
        }
        return false
    }

    private fun requestPermissions() {
        activity?.let { activity ->
            ActivityCompat.requestPermissions(activity, uniquePermissionsToRequest.toTypedArray(), permissionsRequestCode)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        var isHandled = false
        if (requestCode == permissionsRequestCode) {
            //Setting allPermissionsGrantedTemp to a non null will allow a result to be returned to flutter
            allPermissionsGrantedTemp = grantResults.isNotEmpty() && grantResults.all { it == PERMISSION_GRANTED }

            isHandled = true
        }
        return isHandled
    }
    //endregion
}