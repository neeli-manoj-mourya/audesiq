import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audesiq/models/downloaded_assets.dart';

class GitHubDownloadManager {
  // GitHub raw content URLs for the assets
  static const String _originalMovieAudioUrl =
      'https://raw.githubusercontent.com/manojmourya2505/ac-cc/main/yandamuri_kathalu.mp3';
  static const String _audioDescriptionAudioUrl =
      'https://raw.githubusercontent.com/manojmourya2505/ac-cc/main/yandamuri_kathalu_two.mp3';
  static const String _subtitleFileUrl =
      'https://raw.githubusercontent.com/manojmourya2505/ac-cc/main/yandamuri_kathalu_description.srt';

  static const int _maxRetries = 3;
  static const int _retryBaseDelayMs = 1000;
  static const String _assetDirName = 'syncad_assets';

  final http.Client _httpClient;

  GitHubDownloadManager({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Download all assets from GitHub
  Future<DownloadedAssets> downloadAssets({
    required Function(AssetDownloadProgress) onProgress,
  }) async {
    try {
      final assetDir = await _getAssetDirectory();

      final specs = [
        _AssetSpec(_originalMovieAudioUrl, 'yandamuri_kathalu.mp3'),
        _AssetSpec(_audioDescriptionAudioUrl, 'yandamuri_kathalu_two.mp3'),
        _AssetSpec(_subtitleFileUrl, 'yandamuri_kathalu_description.srt'),
      ];

      final localPaths = <String, String>{};

      for (int i = 0; i < specs.length; i++) {
        final spec = specs[i];
        final file = await _ensureDownloaded(
          directory: assetDir,
          spec: spec,
          fileIndex: i + 1,
          totalFiles: specs.length,
          onProgress: onProgress,
        );
        localPaths[spec.url] = file.path;
      }

      return DownloadedAssets(
        originalMovieAudioPath: localPaths[_originalMovieAudioUrl]!,
        audioDescriptionAudioPath: localPaths[_audioDescriptionAudioUrl]!,
        subtitleFilePath: localPaths[_subtitleFileUrl]!,
      );
    } catch (e) {
      throw Exception('Failed to download assets: $e');
    }
  }

  Future<Directory> _getAssetDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final assetDir = Directory('${appDir.path}/$_assetDirName');

    if (!await assetDir.exists()) {
      await assetDir.create(recursive: true);
    }

    return assetDir;
  }

  Future<File> _ensureDownloaded({
    required Directory directory,
    required _AssetSpec spec,
    required int fileIndex,
    required int totalFiles,
    required Function(AssetDownloadProgress) onProgress,
  }) async {
    final destination = File('${directory.path}/${spec.fileName}');

    // Check if file already exists and is valid
    if (destination.existsSync() && destination.lengthSync() > 0) {
      onProgress(
        AssetDownloadProgress(
          fileName: spec.fileName,
          fileIndex: fileIndex,
          totalFiles: totalFiles,
          bytesDownloaded: destination.lengthSync(),
          totalBytes: destination.lengthSync(),
          fileProgressPercent: 100,
          message: 'Using cached file',
        ),
      );
      return destination;
    }

    return _downloadWithRetry(
      destination: destination,
      spec: spec,
      fileIndex: fileIndex,
      totalFiles: totalFiles,
      onProgress: onProgress,
    );
  }

  Future<File> _downloadWithRetry({
    required File destination,
    required _AssetSpec spec,
    required int fileIndex,
    required int totalFiles,
    required Function(AssetDownloadProgress) onProgress,
  }) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await _downloadOnce(
          destination: destination,
          spec: spec,
          fileIndex: fileIndex,
          totalFiles: totalFiles,
          onProgress: onProgress,
        );
      } catch (e) {
        if (attempt >= _maxRetries) {
          rethrow;
        }
        final delayMs = _retryBaseDelayMs * attempt;
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    throw Exception('Failed to download ${spec.fileName}');
  }

  Future<File> _downloadOnce({
    required File destination,
    required _AssetSpec spec,
    required int fileIndex,
    required int totalFiles,
    required Function(AssetDownloadProgress) onProgress,
  }) async {
    final tempFile = File('${destination.path}.tmp');
    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }

    try {
      // Use a streamed request so we write in chunks and report real-time
      // progress — mirrors Android's OkHttp streaming with 8 KB buffer.
      final request = http.Request('GET', Uri.parse(spec.url));
      final streamedResponse = await _httpClient.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception('HTTP ${streamedResponse.statusCode} for ${spec.url}');
      }

      final totalBytes = streamedResponse.contentLength ?? -1;
      var downloadedBytes = 0;

      final sink = tempFile.openWrite();
      try {
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          final pct = totalBytes > 0
              ? ((downloadedBytes * 100) ~/ totalBytes).clamp(0, 99)
              : -1;

          onProgress(
            AssetDownloadProgress(
              fileName: spec.fileName,
              fileIndex: fileIndex,
              totalFiles: totalFiles,
              bytesDownloaded: downloadedBytes,
              totalBytes: totalBytes,
              fileProgressPercent: pct,
              message: 'Downloading',
            ),
          );
        }
      } finally {
        await sink.close();
      }

      if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
        throw Exception('Downloaded file is empty: ${spec.fileName}');
      }

      onProgress(
        AssetDownloadProgress(
          fileName: spec.fileName,
          fileIndex: fileIndex,
          totalFiles: totalFiles,
          bytesDownloaded: downloadedBytes,
          totalBytes: downloadedBytes,
          fileProgressPercent: 100,
          message: 'Downloaded',
        ),
      );

      // Rename temp file to final destination
      if (destination.existsSync()) {
        destination.deleteSync();
      }
      await tempFile.rename(destination.path);

      return destination;
    } catch (e) {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
      throw Exception('Download failed for ${spec.fileName}: $e');
    }
  }
}

class _AssetSpec {
  final String url;
  final String fileName;

  _AssetSpec(this.url, this.fileName);
}
