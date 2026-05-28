import 'dart:io';
import 'package:audesiq/models/subtitle_entry.dart';

/// Parses SRT subtitle files
class SrtSubtitleParser {
  static const String _timeSeparator = '-->';
  static final RegExp _timestampRegex = RegExp(
    r'(\d{2,}):(\d{2}):(\d{2}),(\d{3})',
  );

  /// Parse SRT content from a string
  List<SubtitleEntry> parse(String srtContent) {
    if (srtContent.trim().isEmpty) return [];

    return srtContent
        .normalizeLineEndings()
        .split('\n\n')
        .mapNotNull((block) => _parseBlock(block))
        .toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
  }

  /// Parse SRT content from a local file path
  Future<List<SubtitleEntry>> parseFile(String filePath) async {
    try {
      final content = await File(filePath).readAsString();
      return parse(content);
    } catch (e) {
      return [];
    }
  }

  /// Parse a subtitle track from a string
  SubtitleTrack parseTrack(String srtContent) {
    return SubtitleTrack(parse(srtContent));
  }

  /// Parse a subtitle track from a local file path
  Future<SubtitleTrack> parseTrackFromFile(String filePath) async {
    final entries = await parseFile(filePath);
    return SubtitleTrack(entries);
  }

  /// Parse block of subtitle (number + timestamp + text)
  SubtitleEntry? _parseBlock(String block) {
    final lines = block
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.length < 2) return null;

    // Find line with timestamp separator
    int timestampLineIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains(_timeSeparator)) {
        timestampLineIndex = i;
        break;
      }
    }

    if (timestampLineIndex < 0 || timestampLineIndex >= lines.length)
      return null;

    final timestampLine = lines[timestampLineIndex];
    final parts = timestampLine
        .split(_timeSeparator)
        .map((p) => p.trim())
        .toList();

    if (parts.length != 2) return null;

    final startMs = _parseTimestamp(parts[0]);
    final endMs = _parseTimestamp(parts[1]);

    if (startMs == null || endMs == null || endMs < startMs) return null;

    final text = lines.sublist(timestampLineIndex + 1).join('\n').trim();

    if (text.isEmpty) return null;

    return SubtitleEntry(startMs: startMs, endMs: endMs, text: text);
  }

  /// Parse timestamp in format HH:MM:SS,mmm
  int? _parseTimestamp(String raw) {
    final match = _timestampRegex.firstMatch(raw);
    if (match == null) return null;

    try {
      final hours = int.parse(match.group(1)!);
      final minutes = int.parse(match.group(2)!);
      final seconds = int.parse(match.group(3)!);
      final millis = int.parse(match.group(4)!);

      if (minutes > 59 || seconds > 59 || millis > 999) return null;

      return hours * 3600000 + minutes * 60000 + seconds * 1000 + millis;
    } catch (e) {
      return null;
    }
  }
}

extension on String {
  /// Normalize line endings to \n
  String normalizeLineEndings() {
    return replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  }
}

extension<T> on List<T> {
  /// Map-like operation that filters out nulls
  List<R> mapNotNull<R>(R? Function(T) f) {
    return map(f).whereType<R>().toList();
  }
}
