/// Synchronization phases
enum SyncPhase {
  idle,
  listening,
  monitoring,
  adjustingSpeed,
  seeking,
  stable,
  stopped,
}

/// Current synchronization state
class SyncState {
  final SyncPhase phase;
  final String status;
  final double confidenceScore;
  final int currentMovieTimestampMs;
  final int currentAdPlaybackTimestampMs;
  final int driftMs;
  final double playbackSpeed;

  SyncState({
    this.phase = SyncPhase.idle,
    this.status = 'Idle',
    this.confidenceScore = 0.0,
    this.currentMovieTimestampMs = 0,
    this.currentAdPlaybackTimestampMs = 0,
    this.driftMs = 0,
    this.playbackSpeed = 1.0,
  });

  SyncState copyWith({
    SyncPhase? phase,
    String? status,
    double? confidenceScore,
    int? currentMovieTimestampMs,
    int? currentAdPlaybackTimestampMs,
    int? driftMs,
    double? playbackSpeed,
  }) {
    return SyncState(
      phase: phase ?? this.phase,
      status: status ?? this.status,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      currentMovieTimestampMs:
          currentMovieTimestampMs ?? this.currentMovieTimestampMs,
      currentAdPlaybackTimestampMs:
          currentAdPlaybackTimestampMs ?? this.currentAdPlaybackTimestampMs,
      driftMs: driftMs ?? this.driftMs,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  @override
  String toString() =>
      'SyncState(phase=$phase, status=$status, confidence=$confidenceScore, drift=$driftMs, speed=$playbackSpeed)';
}
