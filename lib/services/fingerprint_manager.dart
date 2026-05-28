import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audesiq/models/fingerprint_match_result.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

/// A single audio fingerprint hash paired with its anchor timestamp.
class FingerprintHash {
  final int hash;
  final int anchorTimeMs;

  const FingerprintHash({required this.hash, required this.anchorTimeMs});
}

/// Internal spectral frame produced by [SpectrogramBuilder].
class _SpectralFrame {
  final int timeMs;
  final int frameIndex;
  final Float32List magnitudes;

  const _SpectralFrame({
    required this.timeMs,
    required this.frameIndex,
    required this.magnitudes,
  });
}

// ============================================================================
// SPECTROGRAM BUILDER — Hann window + Cooley-Tukey FFT
// (mirrors Android SpectrogramBuilder.kt exactly)
// ============================================================================

class SpectrogramBuilder {
  static const int fftSize = 1024;
  static const int hopSize = 512;

  static final Float32List _hannCoefficients = _buildHannWindow();

  static Float32List _buildHannWindow() {
    final w = Float32List(fftSize);
    for (int i = 0; i < fftSize; i++) {
      w[i] = (0.5 * (1.0 - math.cos(2.0 * math.pi * i / (fftSize - 1))));
    }
    return w;
  }

  /// Build spectral frames from mono PCM-16 samples.
  static List<_SpectralFrame> buildFrames(
    List<int> pcm16, {
    int sampleRate = 16000,
    int offsetMs = 0,
  }) {
    final floats = Float32List(pcm16.length);
    for (int i = 0; i < pcm16.length; i++) {
      floats[i] = pcm16[i] / 32768.0;
    }

    final frames = <_SpectralFrame>[];
    int frameStart = 0;
    int frameIndex = 0;

    while (frameStart + fftSize <= floats.length) {
      final re = Float32List(fftSize);
      final im = Float32List(fftSize);

      for (int i = 0; i < fftSize; i++) {
        re[i] = floats[frameStart + i] * _hannCoefficients[i];
      }

      _fft(re, im);

      final numBins = fftSize ~/ 2 + 1;
      final mags = Float32List(numBins);
      for (int k = 0; k < numBins; k++) {
        mags[k] = math.sqrt(re[k] * re[k] + im[k] * im[k]);
      }

      final timeMs = offsetMs + (frameStart * 1000) ~/ sampleRate;
      frames.add(
        _SpectralFrame(
          timeMs: timeMs,
          frameIndex: frameIndex,
          magnitudes: mags,
        ),
      );

      frameStart += hopSize;
      frameIndex++;
    }

    return frames;
  }

  /// In-place Cooley-Tukey DIT FFT (identical to Android SpectrogramBuilder.kt).
  static void _fft(Float32List re, Float32List im) {
    final n = re.length;

    // Bit-reversal permutation
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        double t = re[i];
        re[i] = re[j];
        re[j] = t;
        t = im[i];
        im[i] = im[j];
        im[j] = t;
      }
    }

    // Butterfly stages
    int len = 2;
    while (len <= n) {
      final halfLen = len >> 1;
      final angle = -2.0 * math.pi / len;
      final wBaseRe = math.cos(angle);
      final wBaseIm = math.sin(angle);
      int k = 0;
      while (k < n) {
        double curRe = 1.0;
        double curIm = 0.0;
        for (int p = 0; p < halfLen; p++) {
          final uRe = re[k + p];
          final uIm = im[k + p];
          final tRe = curRe * re[k + p + halfLen] - curIm * im[k + p + halfLen];
          final tIm = curRe * im[k + p + halfLen] + curIm * re[k + p + halfLen];
          re[k + p] = uRe + tRe;
          im[k + p] = uIm + tIm;
          re[k + p + halfLen] = uRe - tRe;
          im[k + p + halfLen] = uIm - tIm;
          final nextRe = curRe * wBaseRe - curIm * wBaseIm;
          curIm = curRe * wBaseIm + curIm * wBaseRe;
          curRe = nextRe;
        }
        k += len;
      }
      len <<= 1;
    }
  }
}

// ============================================================================
// FINGERPRINT GENERATOR — Shazam-like constellation map
// (mirrors Android FingerprintGenerator.kt exactly)
// ============================================================================

/// Generates combinatorial fingerprint hashes from spectral frames.
///
/// Algorithm (Shazam "constellation map"):
///  1. Silence gate — skip frames below RMS threshold.
///  2. Peak extraction — strongest FFT bin in each of 6 log-spaced bands.
///  3. Hash pairs — anchor peak + partner peak in DT_MIN..DT_MAX look-ahead.
///  4. Hash encoding — (anchorBin:9)(partnerBin:9)(Δt:6) = 24-bit int.
class FingerprintGenerator {
  // Frequency band boundaries (bin indices for FFT_SIZE=1024, SR=16 kHz)
  static const _bandBoundaries = [2, 10, 20, 50, 120, 250, 513];
  static const _numBands = 6;

  // Look-ahead zone: [DT_MIN..DT_MAX] frames ahead (32 ms/frame → 32–160 ms)
  static const _dtMin = 1;
  static const _dtMax = 5;

  // Hash bit layout: [anchorBin:9][partnerBin:9][Δt:6]
  static const _binBits = 9;
  static const _dtBits = 6;
  static const _binMask = (1 << _binBits) - 1; // 0x1FF
  static const _dtMask = (1 << _dtBits) - 1; // 0x03F

  // Silence gate — skip frames that are genuinely silent.
  // IMPORTANT: this threshold must be low enough to pass mic-captured room
  // audio.  A phone mic recording a TV/speaker at 2–3 m produces FFT magnitude
  // RMS in the 0.0005–0.002 range (the room attenuates the signal and the mic
  // gain normalises it at a lower level than a decoded audio file).  The old
  // value of 0.005 filtered EVERYTHING from mic input, producing zero live
  // hashes and making sync impossible.  0.0002 still reliably silences true
  // dead-air while allowing low-level room captures through.
  static const _silenceRmsThreshold = 0.0002;

  /// Generate hashes from a list of spectral frames.
  static List<FingerprintHash> generate(List<_SpectralFrame> frames) {
    if (frames.isEmpty) return [];

    final maxIdx = frames.last.frameIndex;
    final peaksByFrame = List<List<_FreqPeak>?>.filled(maxIdx + 1, null);

    for (final frame in frames) {
      if (_rms(frame.magnitudes) >= _silenceRmsThreshold) {
        peaksByFrame[frame.frameIndex] = _extractPeaks(frame);
      }
    }

    final hashes = <FingerprintHash>[];
    for (final frame in frames) {
      final anchors = peaksByFrame[frame.frameIndex];
      if (anchors == null) continue;
      for (final anchor in anchors) {
        for (int dt = _dtMin; dt <= _dtMax; dt++) {
          final partnerIdx = frame.frameIndex + dt;
          if (partnerIdx > maxIdx) break;
          final partners = peaksByFrame[partnerIdx];
          if (partners == null) continue;
          for (final partner in partners) {
            final hash =
                ((anchor.binIndex & _binMask) << (_binBits + _dtBits)) |
                ((partner.binIndex & _binMask) << _dtBits) |
                (dt & _dtMask);
            hashes.add(
              FingerprintHash(hash: hash, anchorTimeMs: anchor.timeMs),
            );
          }
        }
      }
    }
    return hashes;
  }

  /// Convenience: build spectrogram then generate hashes.
  static List<FingerprintHash> generateFromPcm(
    List<int> pcm16, {
    int sampleRate = 16000,
    int offsetMs = 0,
  }) {
    if (pcm16.isEmpty) return [];
    final frames = SpectrogramBuilder.buildFrames(
      pcm16,
      sampleRate: sampleRate,
      offsetMs: offsetMs,
    );
    return generate(frames);
  }

  static List<_FreqPeak> _extractPeaks(_SpectralFrame frame) {
    final peaks = <_FreqPeak>[];
    for (int b = 0; b < _numBands; b++) {
      final lo = _bandBoundaries[b];
      final hi = _bandBoundaries[b + 1];
      double maxMag = 0;
      int maxBin = lo;
      for (int bin = lo; bin < hi && bin < frame.magnitudes.length; bin++) {
        if (frame.magnitudes[bin] > maxMag) {
          maxMag = frame.magnitudes[bin];
          maxBin = bin;
        }
      }
      peaks.add(_FreqPeak(maxBin, frame.timeMs));
    }
    return peaks;
  }

  static double _rms(Float32List mags) {
    double sum = 0;
    for (final v in mags) sum += v * v;
    return math.sqrt(sum / mags.length);
  }
}

class _FreqPeak {
  final int binIndex;
  final int timeMs;
  const _FreqPeak(this.binIndex, this.timeMs);
}

// ============================================================================
// FINGERPRINT REPOSITORY — hash → list of reference timestamps
// ============================================================================

class FingerprintRepository {
  // hash → list of anchorTimeMs values from the reference audio
  final Map<int, List<int>> _index = {};
  bool _isReady = false;

  bool get isReady => _isReady;
  int get entryCount => _index.values.fold(0, (s, v) => s + v.length);

  void add(List<FingerprintHash> hashes) {
    for (final fp in hashes) {
      _index.putIfAbsent(fp.hash, () => []).add(fp.anchorTimeMs);
    }
  }

  void finalizeAndSort() {
    _isReady = true;
  }

  void clear() {
    _index.clear();
    _isReady = false;
  }

  /// Returns all reference timestamps for a given hash.
  List<int>? getTimestamps(int hash) => _index[hash];
}

// ============================================================================
// FINGERPRINT MATCHER — time-offset alignment histogram
// (mirrors Android FingerprintMatcher.kt exactly)
// ============================================================================

class FingerprintMatcher {
  /// Width of histogram bins in ms (absorbs Bluetooth latency + clock drift).
  static const int _binWidthMs = 50;

  /// Minimum aligned hashes in the best histogram bucket to accept a raw
  /// match.  Raised from 5 → 10 to reduce noise false-positives.
  static const int _minAlignedHashes = 10;

  FingerprintMatchResult? match(
    List<FingerprintHash> liveHashes,
    FingerprintRepository repository,
  ) {
    if (liveHashes.isEmpty || !repository.isReady) return null;

    // offset histogram: quantised bucket (ms) → hit count
    final histogram = <int, int>{};
    int totalHits = 0;

    for (final live in liveHashes) {
      final refTimestamps = repository.getTimestamps(live.hash);
      if (refTimestamps == null) continue;
      for (final refTs in refTimestamps) {
        final rawOffset = refTs - live.anchorTimeMs;
        final bucket = (rawOffset ~/ _binWidthMs) * _binWidthMs;
        histogram[bucket] = (histogram[bucket] ?? 0) + 1;
        totalHits++;
      }
    }

    if (histogram.isEmpty) return null;

    int? bestBucket;
    int peakCount = 0;
    histogram.forEach((bucket, count) {
      if (count > peakCount) {
        peakCount = count;
        bestBucket = bucket;
      }
    });

    if (bestBucket == null || peakCount < _minAlignedHashes) return null;

    final confidence = totalHits > 0 ? peakCount / totalHits : 0.0;

    // bestBucket is the estimated movie timestamp
    final matchedTs = bestBucket! < 0 ? 0 : bestBucket!;

    return FingerprintMatchResult(
      confidence: confidence.clamp(0.0, 1.0),
      matchedTimestampMs: matchedTs,
    );
  }
}

// ============================================================================
// AUDIO FINGERPRINT MANAGER — orchestrates build + match
// ============================================================================

enum IndexState { uninitialized, building, ready, error }

class AudioFingerprintManager {
  final FingerprintRepository _repository = FingerprintRepository();
  final FingerprintMatcher _matcher = FingerprintMatcher();

  IndexState _indexState = IndexState.uninitialized;
  int _indexedHashCount = 0;

  IndexState get indexState => _indexState;
  int get indexedHashCount => _indexedHashCount;
  bool get isReady => _repository.isReady;

  /// Build fingerprint index from a local audio file (MP3, AAC, etc.).
  ///
  /// Uses ffmpeg to decode the file to raw PCM-16 LE mono at 16 kHz, then
  /// processes it in 30-second chunks to limit peak memory usage.
  Future<void> buildIndexFromFile(String absolutePath) async {
    _indexState = IndexState.building;
    _repository.clear();

    try {
      final tempDir = await getTemporaryDirectory();
      final tempPcmPath = '${tempDir.path}/fp_index_audio.raw';

      // Decode to raw PCM-16 LE mono 16 kHz via native MediaExtractor/MediaCodec.
      const _channel = MethodChannel('com.inouiw.audesiq/audio_decoder');
      await _channel.invokeMethod<void>('decodeToPcm', {
        'inputPath': absolutePath,
        'outputPath': tempPcmPath,
      });

      // Read and process in 30-second chunks (960 KB each)
      const sampleRate = 16000;
      const samplesPerChunk = 30 * sampleRate;
      const bytesPerChunk = samplesPerChunk * 2;

      final file = File(tempPcmPath);
      final raf = await file.open(mode: FileMode.read);
      int sampleOffset = 0;

      try {
        while (true) {
          final buffer = await raf.read(bytesPerChunk);
          if (buffer.isEmpty) break;

          final bd = buffer.buffer.asByteData(
            buffer.offsetInBytes,
            buffer.length,
          );
          final numSamples = buffer.length ~/ 2;
          final samples = List<int>.generate(
            numSamples,
            (i) => bd.getInt16(i * 2, Endian.little),
          );

          final chunkOffsetMs = (sampleOffset * 1000) ~/ sampleRate;
          final hashes = FingerprintGenerator.generateFromPcm(
            samples,
            sampleRate: sampleRate,
            offsetMs: chunkOffsetMs,
          );
          _repository.add(hashes);
          sampleOffset += numSamples;
        }
      } finally {
        await raf.close();
        try {
          await file.delete();
        } catch (_) {}
      }

      _repository.finalizeAndSort();
      _indexedHashCount = _repository.entryCount;
      _indexState = IndexState.ready;
    } catch (e) {
      _indexState = IndexState.error;
    }
  }

  /// Match a live 2-second PCM chunk against the reference index.
  FingerprintMatchResult? matchPcmFrame(
    List<int> pcm16, {
    int sampleRateHz = 16000,
  }) {
    if (!_repository.isReady) return null;

    final liveHashes = FingerprintGenerator.generateFromPcm(
      pcm16,
      sampleRate: sampleRateHz,
    );

    if (liveHashes.isEmpty) return null;

    return _matcher.match(liveHashes, _repository);
  }

  /// Same as [matchPcmFrame] but also returns the number of live hashes
  /// generated — useful for on-screen diagnostics.
  ({FingerprintMatchResult? match, int liveHashCount}) matchPcmFrameDebug(
    List<int> pcm16, {
    int sampleRateHz = 16000,
  }) {
    if (!_repository.isReady) return (match: null, liveHashCount: 0);

    final liveHashes = FingerprintGenerator.generateFromPcm(
      pcm16,
      sampleRate: sampleRateHz,
    );

    return (
      match: liveHashes.isEmpty
          ? null
          : _matcher.match(liveHashes, _repository),
      liveHashCount: liveHashes.length,
    );
  }
}
