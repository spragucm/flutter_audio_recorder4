enum RecorderState {
  UNSET(state: "unset", nexStateDisplayText: "Initialize", description:"Recorder not initialized"),
  INITIALIZED(state: "initialized", nexStateDisplayText: "Start", description:"Ready to start recording"),
  RECORDING(state: "recording", nexStateDisplayText: "Pause", description:"Currently recording"),
  PAUSED(state: "paused", nexStateDisplayText: "Resume", description:"Currently paused"),
  STOPPED(state: "stopped", nexStateDisplayText: "Initialize", description:"This specific recording stopped and cannot be started again");
  
  final String state;
  final String nexStateDisplayText;
  final String description;
  
  const RecorderState({
    required this.state,
    required this.nexStateDisplayText,
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