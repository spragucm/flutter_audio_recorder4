import 'package:flutter/services.dart';
import 'package:flutter_audio_recorder4/platform_info_handler.dart';
import 'flutter_method_call.dart';
import 'dart:developer' as developer;

class PermissionsHandler extends PlatformInfoHandler {

  bool allPermissionsGranted = false;

  Function(bool hasPermissions)? _hasPermissionsExternalCallback;

  late Function(bool hasPermissions) _hasPermissionsCallback;

  PermissionsHandler(
      super.methodChannelName,
      {
        Function(bool)? hasPermissionsCallback,
      }
  ){
    _hasPermissionsExternalCallback = hasPermissionsCallback;

    _hasPermissionsCallback = (bool hasPermissions) {
      allPermissionsGranted = hasPermissions;
      _hasPermissionsExternalCallback?.call(allPermissionsGranted);
    };
  }

  /// Returns the result of record permission
  /// if not determined(app first launch),
  /// this will ask user to whether grant the permission
  Future<bool> hasPermissions() async {
    allPermissionsGranted = await platform.hasPermissions();
    _hasPermissionsCallback(allPermissionsGranted);
    return allPermissionsGranted;
  }

  Future revokePermissions() async => await platform.revokePermissions();

  @override
  Future<void> methodHandler(MethodCall call) async {
    super.methodHandler(call);

    if (call.method == FlutterMethodCall.HAS_PERMISSIONS.methodName) {
      handleHasPermissions(call.arguments);
    } else {
      developer.log("Unhandled method call:${call.method}");
    }
  }

  void handleHasPermissions(bool hasPermissions) => _hasPermissionsCallback.call(hasPermissions);
}