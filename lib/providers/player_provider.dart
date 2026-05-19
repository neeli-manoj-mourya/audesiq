import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerState {
  final bool isPlaying;
  final double progress; // 0.0 to 1.0
  final int currentLineIndex;

  PlayerState({
    required this.isPlaying,
    required this.progress,
    required this.currentLineIndex,
  });

  factory PlayerState.initial() => PlayerState(
    isPlaying: false,
    progress: 0.0,
    currentLineIndex: 0,
  );

  PlayerState copyWith({
    bool? isPlaying,
    double? progress,
    int? currentLineIndex,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      progress: progress ?? this.progress,
      currentLineIndex: currentLineIndex ?? this.currentLineIndex,
    );
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier() : super(PlayerState.initial());

  void togglePlayPause() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void updateProgress(double newProgress) {
    final normalized = newProgress.clamp(0.0, 1.0);
    state = state.copyWith(progress: normalized);
  }

  void skipForward() {
    final newProgress = (state.progress + 0.05).clamp(0.0, 1.0);
    state = state.copyWith(progress: newProgress);
  }

  void skipBackward() {
    final newProgress = (state.progress - 0.05).clamp(0.0, 1.0);
    state = state.copyWith(progress: newProgress);
  }

  void updateCurrentLine(int lineIndex) {
    state = state.copyWith(currentLineIndex: lineIndex);
  }
}
