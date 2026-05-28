import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:audesiq/models/audio_chunk.dart';

enum CaptureState {
  idle,
  starting,
  capturing,
  permissionDenied,
  error,
  stopped,
}

/// Continuously captures microphone audio and emits [AudioChunk] objects.
///
/// Uses the [record] package's [startStream] API to get a live stream of raw
/// PCM-16 LE bytes, accumulates them into 2-second chunks (32 000 samples at
/// 16 kHz), and broadcasts them via [audioChunks].
///
/// This mirrors the Android AudioCaptureManager.kt behaviour:
///  • 16 kHz, mono, PCM-16 — same as the fingerprint index sample rate.
///  • 2-second chunks (32 000 samples) for real-time fingerprint matching.
///  • Broadcast stream so multiple listeners can consume chunks independently.
class AudioCaptureManager {
  static const int _sampleRate = 16000;
  static const int _samplesPerChunk = 32000; // 2 seconds at 16 kHz
  static const int _bytesPerChunk = _samplesPerChunk * 2; // 16-bit = 2 bytes

  final _audioRecorder = AudioRecorder();

  CaptureState _captureState = CaptureState.idle;
  StreamController<AudioChunk>? _chunkController;
  StreamSubscription<List<int>>? _rawSub;
  final List<int> _byteBuffer = [];
  bool _isCapturing = false;

  CaptureState get captureState => _captureState;
  Stream<AudioChunk>? get audioChunks => _chunkController?.stream;
  bool get isCapturing => _isCapturing;

  /// Start capturing audio and emitting [AudioChunk] objects.
  Future<void> startCapture() async {
    if (_isCapturing) return;

    _captureState = CaptureState.starting;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _captureState = CaptureState.permissionDenied;
        return;
      }

      // Create broadcast controller so AudioSyncManager can subscribe after
      // startCapture() completes.
      _chunkController = StreamController<AudioChunk>.broadcast();
      _byteBuffer.clear();

      // Start streaming raw PCM-16 LE bytes from the microphone.
      final rawStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      _isCapturing = true;
      _captureState = CaptureState.capturing;

      _rawSub = rawStream.listen(
        (rawBytes) {
          _byteBuffer.addAll(rawBytes);

          // Emit complete 2-second chunks.
          while (_byteBuffer.length >= _bytesPerChunk) {
            final chunkBytes = Uint8List.fromList(
              _byteBuffer.sublist(0, _bytesPerChunk),
            );
            _byteBuffer.removeRange(0, _bytesPerChunk);

            final bd = chunkBytes.buffer.asByteData();
            final samples = List<int>.generate(
              _samplesPerChunk,
              (i) => bd.getInt16(i * 2, Endian.little),
            );

            _chunkController?.add(
              AudioChunk(pcm16: samples, sampleRateHz: _sampleRate),
            );
          }
        },
        onError: (Object error) {
          _captureState = CaptureState.error;
          _isCapturing = false;
          _chunkController?.close();
          _chunkController = null;
        },
        onDone: () {
          _isCapturing = false;
          _captureState = CaptureState.stopped;
          _chunkController?.close();
          _chunkController = null;
        },
      );
    } catch (e) {
      _captureState = CaptureState.error;
      _isCapturing = false;
      _chunkController?.close();
      _chunkController = null;
    }
  }

  /// Stop capturing audio.
  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    await _rawSub?.cancel();
    _rawSub = null;

    try {
      await _audioRecorder.stop();
    } catch (_) {}

    _isCapturing = false;
    _captureState = CaptureState.stopped;
    _byteBuffer.clear();

    await _chunkController?.close();
    _chunkController = null;
  }

  /// Release all resources.
  Future<void> release() async {
    await stopCapture();
    await _audioRecorder.dispose();
  }

  /// Check if microphone permission is granted.
  Future<bool> hasPermission() async {
    return _audioRecorder.hasPermission();
  }
}
