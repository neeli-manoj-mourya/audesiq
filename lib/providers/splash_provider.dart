import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple state class for splash animation completion
class SplashAnimationState {
  final bool isAnimating;

  SplashAnimationState({required this.isAnimating});

  factory SplashAnimationState.initial() => SplashAnimationState(isAnimating: true);
}

final splashAnimationProvider = StateNotifierProvider<SplashAnimationNotifier, SplashAnimationState>((ref) {
  return SplashAnimationNotifier();
});

class SplashAnimationNotifier extends StateNotifier<SplashAnimationState> {
  SplashAnimationNotifier() : super(SplashAnimationState.initial());

  void completeAnimation() {
    state = SplashAnimationState(isAnimating: false);
  }
}
