import 'method_channel_handler.dart';

class PlatformInfoHandler extends MethodChannelHandler {

  PlatformInfoHandler(super.methodChannelName);

  Future<String> getPlatformVersion() async => await platform.getPlatformVersion() ?? "Unknown platform version";
}