/// Audio playback states
enum AdPlaybackState { idle, loading, playing, paused, stopped, error }

/// Status of audio playback
class AdPlaybackStatus {
  final AdPlaybackState state;
  final int currentPositionMs;
  final int durationMs;
  final double playbackSpeed;
  final String? errorMessage;

  AdPlaybackStatus({
    this.state = AdPlaybackState.idle,
    this.currentPositionMs = 0,
    this.durationMs = 0,
    this.playbackSpeed = 1.0,
    this.errorMessage,
  });

  AdPlaybackStatus copyWith({
    AdPlaybackState? state,
    int? currentPositionMs,
    int? durationMs,
    double? playbackSpeed,
    String? errorMessage,
  }) {
    return AdPlaybackStatus(
      state: state ?? this.state,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      durationMs: durationMs ?? this.durationMs,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() =>
      'AdPlaybackStatus(state=$state, position=$currentPositionMs, duration=$durationMs, speed=$playbackSpeed)';
}

/// Audio capture states
enum CaptureState {
  idle,
  starting,
  capturing,
  permissionDenied,
  error,
  stopped,
}
