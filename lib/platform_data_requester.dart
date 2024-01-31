import 'method_channel_handler.dart';

class PlatformDataRequester extends MethodChannelHandler {

  PlatformDataRequester(super.methodChannelName);

  Future<String> getPlatformVersion() async => await platform.getPlatformVersion() ?? "Unknown platform version";
}