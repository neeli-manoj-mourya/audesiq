/// Represents a chunk of audio captured from the microphone
class AudioChunk {
  /// Raw PCM-16 samples captured at 16000 Hz
  final List<int> pcm16;

  /// Sample rate in Hz (16000)
  final int sampleRateHz;

  /// Wall-clock capture time in milliseconds
  final DateTime capturedAt;

  AudioChunk({
    required this.pcm16,
    required this.sampleRateHz,
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now();

  @override
  String toString() =>
      'AudioChunk(samples=${pcm16.length}, sampleRate=$sampleRateHz, capturedAt=$capturedAt)';
}
