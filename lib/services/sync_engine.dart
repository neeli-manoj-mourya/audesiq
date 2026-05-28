import 'package:audesiq/models/sync_state.dart';

/// Interface for playback control needed by SyncEngine
abstract class SyncPlaybackController {
  int getCurrentPlaybackTimestampMs();
  double getPlaybackSpeed();
  Future<void> seekTo(int positionMs);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> resetPlaybackSpeed();
}

/// Core synchronization state machine
///
/// Handles audio fingerprint matching and intelligently corrects AD playback
/// to match the movie timestamp with drift detection and correction strategies:
/// 1. Large drift (>1s) → Seek
/// 2. Small drift (<150ms) → Normal speed
/// 3. Medium drift → Speed adjustment (0.97x - 1.03x)
class SyncEngine {
  final SyncPlaybackController _playbackController;
  final int Function() _currentTimeMs;

  SyncState _state = SyncState();
  int _lastCorrectionAtMs = 0;
  int _lastSeekAtMs = 0;
  int? _lastMatchedMovieTimestampMs;
  double? _smoothedDriftMs;

  // Sync thresholds - must match Android implementation
  static const int _recheckIntervalMs = 3000;
  static const int _seekThresholdMs = 1000;
  static const int _seekCooldownMs = 9000;
  static const int _stableDriftMs = 150;
  // Confidence scale from real device logs: peakCount/totalHits ≈ 0.0004–0.0015
  // (long reference audio → many hash collisions → low fraction per bucket).
  // Threshold must be below the consensus tracker's _minConsensusConfidence.
  static const double _minConfidenceForCorrection = 0.0003; // 0.03 %
  static const double _minConfidenceForOutlierOverride = 0.005; // 0.5 %
  static const int _maxTimestampJumpMs = 12000;
  static const double _speedAdjustDivisorMs = 4000.0;
  static const double _maxSpeedOffset = 0.03;
  static const double _minPlaybackSpeed = 0.97;
  static const double _maxPlaybackSpeed = 1.03;
  static const double _driftSmoothingAlpha = 0.35;

  SyncState get state => _state;
  Stream<SyncState> get stateStream => _createStateStream();

  SyncEngine(this._playbackController, {int Function()? timeProviderMs})
    : _currentTimeMs = timeProviderMs ?? _defaultTimeMs;

  static int _defaultTimeMs() => DateTime.now().millisecondsSinceEpoch;

  /// Start synchronization
  void start() {
    _lastCorrectionAtMs = 0;
    _lastSeekAtMs = 0;
    _lastMatchedMovieTimestampMs = null;
    _smoothedDriftMs = null;
    _playbackController.resetPlaybackSpeed();

    _state = SyncState(
      phase: SyncPhase.listening,
      status: 'Listening for sync',
      currentAdPlaybackTimestampMs: _playbackController
          .getCurrentPlaybackTimestampMs(),
      playbackSpeed: _playbackController.getPlaybackSpeed(),
    );
  }

  /// Stop synchronization
  Future<void> stop() async {
    await _playbackController.resetPlaybackSpeed();
    _lastMatchedMovieTimestampMs = null;
    _smoothedDriftMs = null;
    _state = SyncState(
      phase: SyncPhase.stopped,
      status: 'Stopped',
      currentMovieTimestampMs: _state.currentMovieTimestampMs,
      currentAdPlaybackTimestampMs: _playbackController
          .getCurrentPlaybackTimestampMs(),
      playbackSpeed: _playbackController.getPlaybackSpeed(),
    );
  }

  /// Called when no fingerprint match is found
  void onNoMatch({int? adPlaybackTimestampMs}) {
    final previous = _state;
    if (previous.phase == SyncPhase.stopped ||
        previous.phase == SyncPhase.idle) {
      return;
    }

    _state = previous.copyWith(
      phase: SyncPhase.listening,
      status: 'Listening for match',
      currentAdPlaybackTimestampMs:
          adPlaybackTimestampMs ??
          _playbackController.getCurrentPlaybackTimestampMs(),
    );
  }

  /// Called when a fingerprint match is found
  /// Core sync logic: decide whether to seek, adjust speed, or maintain
  Future<void> onMatchedTimestamp({
    required int matchedMovieTimestampMs,
    required double confidenceScore,
  }) async {
    final now = _currentTimeMs();

    if (_isOutlierTimestamp(
      matchedMovieTimestampMs: matchedMovieTimestampMs,
      confidenceScore: confidenceScore,
    )) {
      _state = _state.copyWith(
        phase: SyncPhase.listening,
        status: 'Ignoring outlier match',
        confidenceScore: confidenceScore,
      );
      return;
    }

    _lastMatchedMovieTimestampMs = matchedMovieTimestampMs;

    final currentAdPlaybackTimestampMs = _playbackController
        .getCurrentPlaybackTimestampMs();
    final rawDriftMs = matchedMovieTimestampMs - currentAdPlaybackTimestampMs;
    final driftMs = _smoothDrift(rawDriftMs).round();
    final absDriftMs = driftMs.abs();

    final baseState = SyncState(
      phase: SyncPhase.monitoring,
      status: 'Monitoring sync',
      confidenceScore: confidenceScore,
      currentMovieTimestampMs: matchedMovieTimestampMs,
      currentAdPlaybackTimestampMs: currentAdPlaybackTimestampMs,
      driftMs: driftMs,
      playbackSpeed: _playbackController.getPlaybackSpeed(),
    );

    // If confidence is too low, ignore match
    if (confidenceScore < _minConfidenceForCorrection) {
      await _playbackController.resetPlaybackSpeed();
      _state = baseState.copyWith(
        phase: SyncPhase.monitoring,
        status: 'Low-confidence match',
        playbackSpeed: _playbackController.getPlaybackSpeed(),
      );
      return;
    }

    // Check if we're in recheck interval
    if (_lastCorrectionAtMs > 0 &&
        (now - _lastCorrectionAtMs) < _recheckIntervalMs) {
      _state = baseState.copyWith(status: 'Holding sync window');
      return;
    }

    // SEEK STRATEGY: Large drift
    if (absDriftMs > _seekThresholdMs &&
        (_lastSeekAtMs == 0 || (now - _lastSeekAtMs) >= _seekCooldownMs)) {
      await _playbackController.seekTo(matchedMovieTimestampMs);
      await _playbackController.resetPlaybackSpeed();
      _lastCorrectionAtMs = now;
      _lastSeekAtMs = now;

      _state = baseState.copyWith(
        phase: SyncPhase.seeking,
        status: 'Large drift detected — seeking',
        currentAdPlaybackTimestampMs: matchedMovieTimestampMs,
        driftMs: 0,
        playbackSpeed: _playbackController.getPlaybackSpeed(),
      );
      return;
    }

    // STABLE STRATEGY: Small drift
    if (absDriftMs <= _stableDriftMs) {
      await _playbackController.resetPlaybackSpeed();
      _lastCorrectionAtMs = now;

      _state = baseState.copyWith(
        phase: SyncPhase.stable,
        status: 'In sync',
        playbackSpeed: _playbackController.getPlaybackSpeed(),
      );
      return;
    }

    // SPEED ADJUSTMENT STRATEGY: Medium drift
    final targetSpeed = _calculatePlaybackSpeed(driftMs);
    await _playbackController.setPlaybackSpeed(targetSpeed);
    _lastCorrectionAtMs = now;

    final status = driftMs > 0
        ? 'AD behind — speeding up'
        : 'AD ahead — slowing down';

    _state = baseState.copyWith(
      phase: SyncPhase.adjustingSpeed,
      status: status,
      playbackSpeed: _playbackController.getPlaybackSpeed(),
    );
  }

  /// Calculate target playback speed based on drift
  double _calculatePlaybackSpeed(int driftMs) {
    final delta = (driftMs / _speedAdjustDivisorMs).clamp(
      -_maxSpeedOffset,
      _maxSpeedOffset,
    );
    return (1.0 + delta).clamp(_minPlaybackSpeed, _maxPlaybackSpeed);
  }

  bool _isOutlierTimestamp({
    required int matchedMovieTimestampMs,
    required double confidenceScore,
  }) {
    final previousTs = _lastMatchedMovieTimestampMs;
    if (previousTs == null) {
      return false;
    }

    final jumpMs = (matchedMovieTimestampMs - previousTs).abs();
    return jumpMs > _maxTimestampJumpMs &&
        confidenceScore < _minConfidenceForOutlierOverride;
  }

  double _smoothDrift(int rawDriftMs) {
    final previous = _smoothedDriftMs;
    if (previous == null) {
      _smoothedDriftMs = rawDriftMs.toDouble();
      return _smoothedDriftMs!;
    }

    final smoothed =
        (_driftSmoothingAlpha * rawDriftMs) +
        ((1.0 - _driftSmoothingAlpha) * previous);
    _smoothedDriftMs = smoothed;
    return smoothed;
  }

  Stream<SyncState> _createStateStream() async* {
    while (true) {
      yield _state;
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
}
