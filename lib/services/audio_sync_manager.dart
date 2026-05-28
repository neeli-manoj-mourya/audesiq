import 'dart:async';

import 'package:audesiq/services/audio_capture_manager.dart';
import 'package:audesiq/services/fingerprint_manager.dart';
import 'package:audesiq/services/sync_engine.dart';
import 'package:audesiq/models/audio_chunk.dart';
import 'package:audesiq/models/fingerprint_match_result.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// Coordinates audio capture and fingerprint matching.
///
/// Mirrors Android AudioSyncManager.kt exactly:
///  • startSync() calls captureManager.startCapture() then launches a
///    sequential chunk-processing loop — equivalent to Kotlin's
///    syncScope.launch { captureManager.audioChunks.collect { processChunk(it) } }
///  • Each AudioChunk is fully processed (awaited) before the next one is
///    consumed, preventing concurrent seeks / speed adjustments that would
///    corrupt the SyncEngine state machine.
class AudioSyncManager {
  final AudioCaptureManager _captureManager;
  final AudioFingerprintManager _fingerprintManager;
  final SyncEngine _syncEngine;

  String _status = 'Idle';
  bool _isSyncing = false;
  final _matchTracker = _MatchConsensusTracker();

  String get status => _status;
  bool get isSyncing => _isSyncing;
  Stream<String> get statusStream => _createStatusStream();

  AudioSyncManager({
    required AudioCaptureManager captureManager,
    required AudioFingerprintManager fingerprintManager,
    required SyncEngine syncEngine,
  }) : _captureManager = captureManager,
       _fingerprintManager = fingerprintManager,
       _syncEngine = syncEngine;

  /// Start listening for audio and running the fingerprint pipeline.
  ///
  /// Equivalent to Android:
  ///   captureManager.startCapture()
  ///   syncEngine.start()
  ///   syncScope.launch { captureManager.audioChunks.collect { processChunk(it) } }
  Future<void> startSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _matchTracker.reset();
    _status = 'Sync started — waiting for audio chunks…';

    await _captureManager.startCapture();
    _syncEngine.start();

    final stream = _captureManager.audioChunks;
    if (stream == null) {
      _isSyncing = false;
      _status = 'Failed to start audio capture';
      return;
    }

    // Launch sequential processing loop in background — like Android's
    // syncScope.launch{}.  Not awaited so startSync() returns immediately.
    // ignore: discarded_futures
    _runChunkLoop(stream);
  }

  /// Stop the fingerprint pipeline and audio capture.
  Future<void> stopSync() async {
    if (!_isSyncing) return;

    _isSyncing = false;
    _matchTracker.reset();
    // stopCapture() closes the audioChunks stream, which terminates the
    // await-for loop in _runChunkLoop — same as Android's syncJob.cancel().
    await _captureManager.stopCapture();
    await _syncEngine.stop();
    _status = 'Stopped';
  }

  /// Release all resources.
  Future<void> release() async {
    await stopSync();
    await _captureManager.release();
  }

  // ── Sequential chunk loop ─────────────────────────────────────────────────
  //
  // `await for` suspends until _processChunk() completes before consuming the
  // next element.  This is the exact Kotlin-coroutine collect {} semantics:
  // no chunk is processed concurrently with another.

  Future<void> _runChunkLoop(Stream<AudioChunk> stream) async {
    try {
      await for (final chunk in stream) {
        if (!_isSyncing) break;
        await _processChunk(chunk);
      }
    } catch (e) {
      _status = 'Sync error: $e';
    } finally {
      if (_isSyncing) {
        _isSyncing = false;
        _status = 'Stopped';
      }
    }
  }

  // ── Chunk processing ──────────────────────────────────────────────────────

  Future<void> _processChunk(AudioChunk chunk) async {
    if (!_isSyncing) return;

    final captureState = _captureManager.captureState;
    if (captureState == CaptureState.permissionDenied) {
      _status = 'Sync unavailable: microphone permission denied';
      return;
    }
    if (captureState == CaptureState.error) {
      _status = 'Sync unavailable: audio capture error';
      return;
    }

    try {
      final match = _fingerprintManager.matchPcmFrame(
        chunk.pcm16,
        sampleRateHz: chunk.sampleRateHz,
      );

      if (match != null) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        _matchTracker.add(match, observedAtMs: nowMs);
        final stableMatch = _matchTracker.tryBuildConsensus(nowMs: nowMs);

        if (stableMatch != null) {
          await _syncEngine.onMatchedTimestamp(
            matchedMovieTimestampMs: stableMatch.matchedTimestampMs,
            confidenceScore: stableMatch.confidence,
          );
          _status = _syncEngine.state.status;
        } else {
          _status = 'Match candidate — validating…';
        }
        return;
      }

      _matchTracker.onNoMatchChunk();
      _syncEngine.onNoMatch();
      _status = _syncEngine.state.status;
    } catch (e) {
      _status = 'Error processing chunk: $e';
    }
  }

  Stream<String> _createStatusStream() async* {
    while (true) {
      yield _status;
      await Future.delayed(Duration(milliseconds: 500));
    }
  }
}

class _TimedMatch {
  final FingerprintMatchResult match;
  final int observedAtMs;

  const _TimedMatch({required this.match, required this.observedAtMs});
}

class _MatchConsensusTracker {
  static const int _maxWindowSize = 5;
  static const int _maxNoMatchChunksBeforeReset = 4;

  // Projection inlier window.
  // Genuine audio: all projected timestamps land within 0–100 ms of each other.
  // Random/wrong audio: timestamps scatter randomly and rarely cluster.
  // 800 ms is still very generous for real audio and tight enough to reject noise.
  static const int _inlierWindowMs = 800;

  // Confidence scale from device logs: peakCount/totalHits ≈ 0.0004–0.0015.
  static const double _minConsensusConfidence = 0.0003; // 0.03 %

  // Require 3 agreeing chunks (6 seconds of audio) before accepting a sync.
  // Probability of 3 random consecutive timestamps all projecting within
  // 800 ms of each other AND passing the rate check is < 0.001 %.
  static const int _minConsensusVotes = 3;

  // Single chunk instant-sync threshold (0.2 % — rarely reached; requires
  // also passing the rate check against the previous window entry).
  static const double _highConfidenceSingleShot = 0.002; // 0.2 %

  final List<_TimedMatch> _window = [];
  int _consecutiveNoMatchChunks = 0;

  void reset() {
    _window.clear();
    _consecutiveNoMatchChunks = 0;
  }

  void onNoMatchChunk() {
    _consecutiveNoMatchChunks++;
    if (_consecutiveNoMatchChunks >= _maxNoMatchChunksBeforeReset) {
      _window.clear();
    }
  }

  void add(FingerprintMatchResult match, {required int observedAtMs}) {
    _consecutiveNoMatchChunks = 0;
    _window.add(_TimedMatch(match: match, observedAtMs: observedAtMs));
    if (_window.length > _maxWindowSize) {
      _window.removeAt(0);
    }
  }

  FingerprintMatchResult? tryBuildConsensus({required int nowMs}) {
    final latest = _window.isNotEmpty ? _window.last.match : null;

    // Single-shot: one very high-confidence chunk.
    // Still require the rate check against the previous entry so a random
    // spike from wrong audio can't sneak through.
    if (latest != null && latest.confidence >= _highConfidenceSingleShot) {
      if (_window.length >= 2) {
        final prev = _window[_window.length - 2];
        if (!_isTimestampRateValid([prev, _window.last])) {
          return null;
        }
      }
      return latest;
    }

    if (_window.length < _minConsensusVotes) {
      return null;
    }

    final projectedTimestamps =
        _window
            .map(
              (entry) =>
                  entry.match.matchedTimestampMs + (nowMs - entry.observedAtMs),
            )
            .toList()
          ..sort();

    final medianProjectedTs =
        projectedTimestamps[projectedTimestamps.length ~/ 2];

    final inliers = _window.where((entry) {
      final projectedTs =
          entry.match.matchedTimestampMs + (nowMs - entry.observedAtMs);
      return (projectedTs - medianProjectedTs).abs() <= _inlierWindowMs;
    }).toList();

    if (inliers.length < _minConsensusVotes) {
      return null;
    }

    // Rate check: verify matched timestamps are advancing at roughly real-time
    // speed (~2000 ms of movie per 2000 ms of listening).
    if (!_isTimestampRateValid(inliers)) {
      return null;
    }

    final meanConfidence =
        inliers.fold<double>(0.0, (sum, e) => sum + e.match.confidence) /
        inliers.length;

    if (meanConfidence < _minConsensusConfidence) {
      return null;
    }

    return FingerprintMatchResult(
      confidence: meanConfidence,
      matchedTimestampMs: medianProjectedTs,
    );
  }

  /// Returns true when the match timestamps inside [entries] are advancing at
  /// approximately the same rate as real-world observation time.
  ///
  /// For a 2-second mic chunk the next match timestamp should be ~2000 ms later.
  /// Genuine audio satisfies this perfectly.  Random/wrong-movie audio produces
  /// random timestamps that almost never satisfy it for all consecutive pairs.
  ///
  /// Tolerance: ±600 ms on any consecutive pair (handles minor encoder jitter).
  bool _isTimestampRateValid(List<_TimedMatch> entries) {
    if (entries.length < 2) return true;
    final sorted = List.of(entries)
      ..sort((a, b) => a.observedAtMs.compareTo(b.observedAtMs));
    for (int i = 1; i < sorted.length; i++) {
      final dtObserved = sorted[i].observedAtMs - sorted[i - 1].observedAtMs;
      final dtMatch =
          sorted[i].match.matchedTimestampMs -
          sorted[i - 1].match.matchedTimestampMs;
      if ((dtMatch - dtObserved).abs() > 600) {
        return false;
      }
    }
    return true;
  }
}
