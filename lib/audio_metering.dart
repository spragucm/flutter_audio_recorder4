class AudioMetering {

  static const double DEFAULT_AVERAGE_POWER = -120.0;
  static const double DEFAULT_PEAK_POWER = -120.0;
  static const bool DEFAULT_METERING_ENABLED = true;

  double peakPower;
  double averagePower;
  bool meteringEnabled;

  AudioMetering({
    this.peakPower = DEFAULT_PEAK_POWER,
    this.averagePower = DEFAULT_AVERAGE_POWER,
    this.meteringEnabled = DEFAULT_METERING_ENABLED
  });
}