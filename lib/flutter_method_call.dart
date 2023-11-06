enum FlutterMethodCall {

  HAS_PERMISSIONS(methodName: "hasPermissions");

  final String methodName;

  const FlutterMethodCall({
    required this.methodName
  });
}