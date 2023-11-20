import 'package:flutter/services.dart';
import 'flutter_method_call.dart';
import 'method_channel_handler.dart';
import 'native_method_call.dart';
import 'dart:developer' as developer;

class PermissionsRequester extends MethodChannelHandler {

  //This is static because hasPermissions and revokePermissions are static - the prior API is driving this
  static bool ALL_PERMISSIONS_GRANTED = false;
  static Function(bool hasPermissions)? _hasPermissionsExternalCallback;
  static Function(bool hasPermissions) HAS_PERMISSIONS_CALLBACK = (bool hasPermissions){
    ALL_PERMISSIONS_GRANTED = hasPermissions;
    _hasPermissionsExternalCallback?.call(ALL_PERMISSIONS_GRANTED);
  };

  /// Returns the result of record permission
  /// if not determined(app first launch),
  /// this will ask user to whether grant the permission
  static Future<bool?> get hasPermissions async {
    ALL_PERMISSIONS_GRANTED = await MethodChannelHandler.METHOD_CHANNEL.invokeMethod(NativeMethodCall.HAS_PERMISSIONS.methodName);
    HAS_PERMISSIONS_CALLBACK(ALL_PERMISSIONS_GRANTED);
    return ALL_PERMISSIONS_GRANTED;
  }

  // This is static because hasPermissions is static - the prior API is driving this
  static Future get revokePermissions async {
    return await MethodChannelHandler.METHOD_CHANNEL.invokeMethod(NativeMethodCall.REVOKE_PERMISSIONS.methodName);
  }

  PermissionsRequester(
    super.methodChannelName,
    {
      super.defaultChannel,
      Function(bool)? hasPermissionsCallback,
    }
  ){
    _hasPermissionsExternalCallback = hasPermissionsCallback;
  }

  @override
  Future<void> methodHandler(MethodCall call) async {
    super.methodHandler(call);
    if (call.method == FlutterMethodCall.HAS_PERMISSIONS.methodName) {
      handleHasPermissions(call.arguments);
    } else {
      developer.log("Unhandled method call:${call.method}");
    }
  }

  void handleHasPermissions(bool hasPermissions) => HAS_PERMISSIONS_CALLBACK.call(hasPermissions);
}