/// Represents a single subtitle/caption entry
class SubtitleEntry {
  /// Start time in milliseconds
  final int startMs;

  /// End time in milliseconds
  final int endMs;

  /// Caption text
  final String text;

  SubtitleEntry({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  /// Check if a given timestamp falls within this entry
  bool containsTimestamp(int timestampMs) {
    return timestampMs >= startMs && timestampMs <= endMs;
  }

  @override
  String toString() =>
      'SubtitleEntry(start=$startMs, end=$endMs, text=${text.substring(0, (text.length).clamp(0, 50))}...)';
}

/// Container for subtitle track
class SubtitleTrack {
  final List<SubtitleEntry> entries;

  SubtitleTrack(List<SubtitleEntry> entries)
    : entries = (List<SubtitleEntry>.from(entries))
        ..sort((a, b) => a.startMs.compareTo(b.startMs));

  /// Find subtitle at given timestamp using binary search
  SubtitleEntry? subtitleAt(int timestampMs) {
    if (entries.isEmpty) return null;

    // Binary search
    int left = 0;
    int right = entries.length - 1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      SubtitleEntry candidate = entries[mid];

      if (candidate.containsTimestamp(timestampMs)) {
        return candidate;
      } else if (timestampMs < candidate.startMs) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    return null;
  }

  @override
  String toString() => 'SubtitleTrack(entries=${entries.length})';
}
