class AudioMetering {

  static const double DEFAULTS_AVERAGE_POWER = -120.0;
  static const double DEFAULTS_PEAK_POWER = -120.0;
  static const bool DEFAULTS_METERING_ENABLED = true;

  double? peakPower;
  double? averagePower;
  bool? meteringEnabled;

  AudioMetering({
    this.peakPower,
    this.averagePower,
    this.meteringEnabled
  });
}