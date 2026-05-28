import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audesiq/models/playback_status.dart';

class AudioPlaybackManager {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  AdPlaybackStatus _status = AdPlaybackStatus();
  bool _isPositionPolling = false;

  AdPlaybackStatus get status => _status;
  Stream<AdPlaybackStatus> get statusStream => _createStatusStream();

  AudioPlaybackManager() {
    _setupPlayerListener();
    _configureAudioSession();
  }

  /// Configure the audio session for media playback:
  ///   iOS  — uses AVAudioSessionCategoryPlayback, ignores silent switch,
  ///           routes to speaker/headphones at media volume.
  ///   Android — requests audio focus (AUDIOFOCUS_GAIN), uses STREAM_MUSIC.
  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));
  }

  void _setupPlayerListener() {
    _audioPlayer.playerStateStream.listen((playerState) {
      _updateStatus();
    });

    _audioPlayer.positionStream.listen((_) {
      _updateStatus();
    });
  }

  /// Load and play a local audio file
  Future<void> playFile(String filePath) async {
    try {
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
      _updateStatus();
    } catch (e) {
      _status = _status.copyWith(
        state: AdPlaybackState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Load a file without auto-starting playback
  Future<void> prepareFile(String filePath) async {
    try {
      await _audioPlayer.setFilePath(filePath);
      _updateStatus();
    } catch (e) {
      _status = _status.copyWith(
        state: AdPlaybackState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Pause playback
  Future<void> pause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      _updateStatus();
    }
  }

  /// Resume playback
  Future<void> resume() async {
    if (!_audioPlayer.playing && _audioPlayer.playerState.processingState != ProcessingState.idle) {
      await _audioPlayer.play();
      _updateStatus();
    }
  }

  /// Stop playback and reset position
  Future<void> stop() async {
    await _audioPlayer.stop();
    await _audioPlayer.seek(Duration.zero);
    _updateStatus();
  }

  /// Seek to specific position
  Future<void> seekTo(int positionMs) async {
    try {
      await _audioPlayer.seek(Duration(milliseconds: positionMs));
      _status = _status.copyWith(currentPositionMs: positionMs);
    } catch (e) {
      print('Error seeking: $e');
    }
  }

  /// Get current playback position in milliseconds
  int getCurrentPlaybackTimestampMs() {
    return _audioPlayer.position.inMilliseconds;
  }

  /// Get playback speed
  double getPlaybackSpeed() {
    return _audioPlayer.speed;
  }

  /// Set playback speed (0.8x - 1.2x)
  Future<void> setPlaybackSpeed(double speed) async {
    final clampedSpeed = speed.clamp(0.8, 1.2);
    try {
      await _audioPlayer.setSpeed(clampedSpeed);
      _status = _status.copyWith(playbackSpeed: clampedSpeed);
    } catch (e) {
      print('Error setting playback speed: $e');
    }
  }

  /// Reset playback speed to normal
  Future<void> resetPlaybackSpeed() async {
    await setPlaybackSpeed(1.0);
  }

  void _updateStatus() {
    final playerState = _audioPlayer.playerState;
    final processingState = playerState.processingState;

    final state = _getPlaybackState(processingState);
    
    _status = AdPlaybackStatus(
      state: state,
      currentPositionMs: _audioPlayer.position.inMilliseconds,
      durationMs: _audioPlayer.duration?.inMilliseconds ?? 0,
      playbackSpeed: _audioPlayer.speed,
      errorMessage: playerState.playing ? null : null,
    );

    if (playerState.playing) {
      _startPositionPolling();
    } else {
      _stopPositionPolling();
    }
  }

  AdPlaybackState _getPlaybackState(ProcessingState processingState) {
    switch (processingState) {
      case ProcessingState.idle:
        return AdPlaybackState.idle;
      case ProcessingState.loading:
        return AdPlaybackState.loading;
      case ProcessingState.buffering:
        return AdPlaybackState.loading;
      case ProcessingState.ready:
        return _audioPlayer.playing ? AdPlaybackState.playing : AdPlaybackState.paused;
      case ProcessingState.completed:
        return AdPlaybackState.stopped;
    }
  }

  void _startPositionPolling() {
    if (_isPositionPolling) return;
    
    _isPositionPolling = true;
    // Position updates are already streamed by positionStream
  }

  void _stopPositionPolling() {
    _isPositionPolling = false;
  }

  Stream<AdPlaybackStatus> _createStatusStream() async* {
    while (true) {
      yield _status;
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  /// Release resources
  Future<void> release() async {
    _stopPositionPolling();
    await _audioPlayer.dispose();
  }
}
