enum RecorderState {
  UNSET(state: "unset", description:"Recorder not initialized"),
  INITIALIZED(state: "initialized", description:"Ready to start recording"),
  RECORDING(state: "recording", description:"Currently recording"),
  PAUSED(state: "paused", description:"Currently paused"),
  STOPPED(state: "stopped", description:"This specific recording stopped and cannot be started again");
  
  final String state;
  final String description;
  
  const RecorderState({
    required this.state,
    required this.description
  });
}

extension RecorderExtensionUtils on String? {
  RecorderState? toRecorderState() {
    for (var value in RecorderState.values) {
      if (this == value.state) {
        return value;
      }
    }
    return null;
  }
}