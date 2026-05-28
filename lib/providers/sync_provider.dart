import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audesiq/services/audio_capture_manager.dart';
import 'package:audesiq/services/audio_playback_manager.dart';
import 'package:audesiq/services/fingerprint_manager.dart';
import 'package:audesiq/services/sync_engine.dart';
import 'package:audesiq/services/audio_sync_manager.dart';
import 'package:audesiq/services/srt_subtitle_parser.dart';
import 'package:audesiq/services/github_download_manager.dart';
import 'package:audesiq/models/sync_state.dart';
import 'package:audesiq/models/subtitle_entry.dart';
import 'package:audesiq/models/downloaded_assets.dart';

// ============================================================================
// SERVICES (singletons)
// ============================================================================

final audioPlaybackManagerProvider = Provider((ref) {
  final manager = AudioPlaybackManager();
  ref.onDispose(manager.release);
  return manager;
});

final audioCaptureMasterProvider = Provider((ref) {
  final manager = AudioCaptureManager();
  ref.onDispose(manager.release);
  return manager;
});

final fingerprintManagerProvider = Provider((ref) {
  return AudioFingerprintManager();
});

final syncPlaybackControllerProvider = Provider<SyncPlaybackController>((ref) {
  final playbackManager = ref.watch(audioPlaybackManagerProvider);
  return _PlaybackControllerAdapter(playbackManager);
});

final syncEngineProvider = Provider((ref) {
  final controller = ref.watch(syncPlaybackControllerProvider);
  return SyncEngine(controller);
});

final audioSyncManagerProvider = Provider((ref) {
  final captureManager = ref.watch(audioCaptureMasterProvider);
  final fingerprintManager = ref.watch(fingerprintManagerProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return AudioSyncManager(
    captureManager: captureManager,
    fingerprintManager: fingerprintManager,
    syncEngine: syncEngine,
  );
});

final githubDownloadManagerProvider = Provider((ref) {
  return GitHubDownloadManager();
});

final srtParserProvider = Provider((ref) {
  return SrtSubtitleParser();
});

// ============================================================================
// STATE STREAMS
// ============================================================================

final syncStateStreamProvider = StreamProvider<SyncState>((ref) {
  final syncEngine = ref.watch(syncEngineProvider);
  return syncEngine.stateStream;
});

final playbackStatusStreamProvider = StreamProvider((ref) {
  final playbackManager = ref.watch(audioPlaybackManagerProvider);
  return playbackManager.statusStream;
});

// ============================================================================
// SUBTITLE STATE
// ============================================================================

final subtitleTrackProvider = StateProvider<SubtitleTrack?>((ref) => null);

final downloadProgressProvider = StateProvider<AssetDownloadProgress?>(
  (ref) => null,
);

// ============================================================================
// PLAYER SETUP STATE — mirrors Android MainViewModel
// ============================================================================

enum SetupPhase { initial, downloading, indexing, ready, error }

class PlayerSetupState {
  final SetupPhase phase;
  final String message;
  final bool isSyncing;
  final bool isAwaitingSyncResult;
  final bool hasSyncSuccess;
  final bool hasSyncFailure;

  const PlayerSetupState({
    this.phase = SetupPhase.initial,
    this.message = 'Tap to download audio description',
    this.isSyncing = false,
    this.isAwaitingSyncResult = false,
    this.hasSyncSuccess = false,
    this.hasSyncFailure = false,
  });

  bool get isReady => phase == SetupPhase.ready;

  PlayerSetupState copyWith({
    SetupPhase? phase,
    String? message,
    bool? isSyncing,
    bool? isAwaitingSyncResult,
    bool? hasSyncSuccess,
    bool? hasSyncFailure,
  }) {
    return PlayerSetupState(
      phase: phase ?? this.phase,
      message: message ?? this.message,
      isSyncing: isSyncing ?? this.isSyncing,
      isAwaitingSyncResult: isAwaitingSyncResult ?? this.isAwaitingSyncResult,
      hasSyncSuccess: hasSyncSuccess ?? this.hasSyncSuccess,
      hasSyncFailure: hasSyncFailure ?? this.hasSyncFailure,
    );
  }
}

/// Orchestrates the full setup + sync session flow, mirroring Android MainViewModel.
class PlayerSetupNotifier extends StateNotifier<PlayerSetupState> {
  final Ref _ref;
  Timer? _syncTimeoutTimer;
  StreamSubscription<SyncState>? _syncStateSub;
  static const _syncTimeoutMs = 22000;

  PlayerSetupNotifier(this._ref) : super(const PlayerSetupState());

  @override
  void dispose() {
    _syncTimeoutTimer?.cancel();
    _syncStateSub?.cancel();
    super.dispose();
  }

  /// Download assets from GitHub, parse SRT, build fingerprint index, and
  /// prepare the AD audio for playback — same as Android downloadAssets().
  Future<void> downloadAndPrepare() async {
    if (state.phase == SetupPhase.downloading ||
        state.phase == SetupPhase.indexing)
      return;

    state = state.copyWith(
      phase: SetupPhase.downloading,
      message: 'Downloading audio description…',
    );

    try {
      final downloadManager = _ref.read(githubDownloadManagerProvider);
      DownloadedAssets? assets;

      try {
        assets = await downloadManager.downloadAssets(
          onProgress: (progress) {
            final pct = progress.fileProgressPercent;
            _ref.read(downloadProgressProvider.notifier).state = progress;
            state = state.copyWith(
              message:
                  '[${progress.fileIndex}/${progress.totalFiles}] ${progress.fileName} ($pct%)',
            );
          },
        );
      } catch (e) {
        state = state.copyWith(
          phase: SetupPhase.error,
          message: 'Download failed: $e',
        );
        return;
      }

      // Parse the SRT subtitle file
      final parser = _ref.read(srtParserProvider);
      final subtitleTrack = await parser.parseTrackFromFile(
        assets.subtitleFilePath,
      );
      _ref.read(subtitleTrackProvider.notifier).state = subtitleTrack;

      // Build fingerprint index from original movie audio
      state = state.copyWith(
        phase: SetupPhase.indexing,
        message: 'Building fingerprint index…',
      );

      final fingerprintManager = _ref.read(fingerprintManagerProvider);
      await fingerprintManager.buildIndexFromFile(
        assets.originalMovieAudioPath,
      );

      if (fingerprintManager.indexState == IndexState.error) {
        state = state.copyWith(
          phase: SetupPhase.error,
          message: 'Fingerprint index build failed',
        );
        return;
      }

      // Prepare the AD audio for playback (load without auto-play)
      final playbackManager = _ref.read(audioPlaybackManagerProvider);
      await playbackManager.prepareFile(assets.audioDescriptionAudioPath);

      state = state.copyWith(
        phase: SetupPhase.ready,
        message:
            'Ready — ${fingerprintManager.indexedHashCount} fingerprint hashes',
      );
    } catch (e) {
      state = state.copyWith(
        phase: SetupPhase.error,
        message: 'Setup failed: $e',
      );
    }
  }

  /// Handle Sync button press — mirrors Android onSyncPressed().
  Future<void> onSyncPressed() async {
    if (!state.isReady) return;

    final playbackManager = _ref.read(audioPlaybackManagerProvider);
    final syncManager = _ref.read(audioSyncManagerProvider);

    // Pause AD audio before listening for sync
    await playbackManager.pause();

    // Cancel any previous sync attempt
    _syncTimeoutTimer?.cancel();
    await _syncStateSub?.cancel();

    // Start mic capture + fingerprint pipeline
    await syncManager.startSync();

    // If the capture manager failed to start (permission denied, device error),
    // startSync() returns early with _isSyncing = false and audioChunks = null.
    // Detect this BEFORE setting isSyncing:true so the UI shows a clear error
    // immediately instead of "LISTENING…" for 22 seconds.
    if (!syncManager.isSyncing) {
      final captureManager = _ref.read(audioCaptureMasterProvider);
      final denied =
          captureManager.captureState == CaptureState.permissionDenied;
      // Engine was started inside startSync() before the failure — clean it up.
      await _ref.read(syncEngineProvider).stop();
      state = state.copyWith(
        isSyncing: false,
        isAwaitingSyncResult: false,
        message: denied
            ? 'Microphone permission denied — allow it in Settings'
            : 'Microphone unavailable — try again',
      );
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      isAwaitingSyncResult: true,
      hasSyncSuccess: false,
      hasSyncFailure: false,
      message: 'Listening for movie audio…',
    );

    // Listen for a successful sync match
    _syncStateSub = _ref.read(syncEngineProvider).stateStream.listen((
      syncState,
    ) {
      if (!state.isAwaitingSyncResult) return;
      if (_hasResolvedSyncMatch(syncState)) {
        _onSyncSuccess(syncState);
      }
    });

    // 12-second timeout — if no match, report failure
    _syncTimeoutTimer = Timer(const Duration(milliseconds: _syncTimeoutMs), () {
      if (state.isAwaitingSyncResult) {
        _onSyncTimeout();
      }
    });
  }

  Future<void> _onSyncSuccess(SyncState syncState) async {
    _syncTimeoutTimer?.cancel();
    _syncStateSub?.cancel();
    _syncStateSub = null;

    // Update state first so the UI reflects sync success immediately.
    state = state.copyWith(
      isSyncing: false,
      isAwaitingSyncResult: false,
      hasSyncSuccess: true,
      hasSyncFailure: false,
      message: 'Synced successfully',
    );

    final syncManager = _ref.read(audioSyncManagerProvider);
    final playbackManager = _ref.read(audioPlaybackManagerProvider);
    // Stop capture/engine fully before resuming so speed-reset from stop()
    // cannot race with active playback.
    await syncManager.stopSync();
    playbackManager.resume();
  }

  void _onSyncTimeout() {
    _syncStateSub?.cancel();
    _syncStateSub = null;

    final syncManager = _ref.read(audioSyncManagerProvider);
    syncManager.stopSync();

    state = state.copyWith(
      isSyncing: false,
      isAwaitingSyncResult: false,
      hasSyncSuccess: false,
      hasSyncFailure: true,
      message: 'Unable to sync — try again',
    );
  }

  /// Cancel an ongoing sync attempt.
  Future<void> cancelSync() async {
    _syncTimeoutTimer?.cancel();
    _syncStateSub?.cancel();
    _syncStateSub = null;

    final syncManager = _ref.read(audioSyncManagerProvider);
    await syncManager.stopSync();

    state = state.copyWith(
      isSyncing: false,
      isAwaitingSyncResult: false,
      message: state.isReady ? 'Ready' : state.message,
    );
  }

  static bool _hasResolvedSyncMatch(SyncState s) {
    // Only accept phases that mean a real correction was applied:
    //   seeking        → large drift: seekTo() was called
    //   adjustingSpeed → medium drift: speed was changed
    //   stable         → small drift: already in sync, no correction needed
    // Deliberately excludes SyncPhase.monitoring, which is also set for
    // low-confidence matches and cooldown holds where NO correction was made.
    return s.currentMovieTimestampMs > 0 &&
        (s.phase == SyncPhase.seeking ||
            s.phase == SyncPhase.stable ||
            s.phase == SyncPhase.adjustingSpeed);
  }
}

final playerSetupProvider =
    StateNotifierProvider<PlayerSetupNotifier, PlayerSetupState>((ref) {
      return PlayerSetupNotifier(ref);
    });

// ============================================================================
// UTILITY
// ============================================================================

/// Adapter connecting [AudioPlaybackManager] to the [SyncPlaybackController]
/// interface expected by [SyncEngine].
class _PlaybackControllerAdapter implements SyncPlaybackController {
  final AudioPlaybackManager _playbackManager;

  _PlaybackControllerAdapter(this._playbackManager);

  @override
  int getCurrentPlaybackTimestampMs() =>
      _playbackManager.getCurrentPlaybackTimestampMs();

  @override
  double getPlaybackSpeed() => _playbackManager.getPlaybackSpeed();

  @override
  Future<void> seekTo(int positionMs) => _playbackManager.seekTo(positionMs);

  @override
  Future<void> setPlaybackSpeed(double speed) =>
      _playbackManager.setPlaybackSpeed(speed);

  @override
  Future<void> resetPlaybackSpeed() => _playbackManager.resetPlaybackSpeed();
}
