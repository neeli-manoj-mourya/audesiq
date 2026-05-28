/// Result of matching a live audio chunk against the fingerprint index
class FingerprintMatchResult {
  /// Confidence score from 0.0 to 1.0
  final double confidence;

  /// The detected movie timestamp in milliseconds
  final int matchedTimestampMs;

  FingerprintMatchResult({
    required this.confidence,
    required this.matchedTimestampMs,
  });

  @override
  String toString() =>
      'FingerprintMatchResult(confidence=$confidence, timestamp=$matchedTimestampMs)';
}
