enum NativeMethodCall {

  HAS_PERMISSIONS(methodName: "hasPermissions"),
  REVOKE_PERMISSIONS(methodName: "revokePermissions"),
  INIT(methodName: "init"),
  CURRENT(methodName: "current"),
  START(methodName: "start"),
  PAUSE(methodName: "pause"),
  RESUME(methodName: "resume"),
  STOP(methodName: "stop");

  final String methodName;

  const NativeMethodCall({
    required this.methodName
  });
}