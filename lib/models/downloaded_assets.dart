/// Container for downloaded asset paths
class DownloadedAssets {
  final String originalMovieAudioPath;
  final String audioDescriptionAudioPath;
  final String subtitleFilePath;

  DownloadedAssets({
    required this.originalMovieAudioPath,
    required this.audioDescriptionAudioPath,
    required this.subtitleFilePath,
  });

  @override
  String toString() =>
      'DownloadedAssets(original=$originalMovieAudioPath, ad=$audioDescriptionAudioPath, subtitles=$subtitleFilePath)';
}

/// Progress update for asset download
class AssetDownloadProgress {
  final String fileName;
  final int fileIndex;
  final int totalFiles;
  final int bytesDownloaded;
  final int totalBytes;
  final int fileProgressPercent;
  final String message;

  AssetDownloadProgress({
    required this.fileName,
    required this.fileIndex,
    required this.totalFiles,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.fileProgressPercent,
    required this.message,
  });

  @override
  String toString() =>
      'AssetDownloadProgress(file=$fileName, $fileIndex/$totalFiles, progress=$fileProgressPercent%, msg=$message)';
}
