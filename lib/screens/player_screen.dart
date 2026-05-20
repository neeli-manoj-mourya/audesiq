import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';
import '../providers/player_provider.dart';
import '../theme/theme.dart';

const _scriptLines = [
  'In a world where silence speaks volumes,',
  'The truth is often hidden in plain sight.',
  'They called him the Architect of Echoes.',
  'But echoes are just ghosts of the past.',
  'Now, the frequency is changing.',
  'Can you hear the light shifting?',
  'City lights flicker under a silent sky.',
  'Every heartbeat maps another memory.',
  'Neon rain writes secrets on the glass.',
  'Footsteps fade, but the rhythm remains.',
  'Static turns to signals in the dark.',
  'Shadows dance between the bass and breath.',
  'Hold the line, the night is listening.',
  'Every chorus carries a coded prayer.',
  'Lost voices rise through open wires.',
  'Time bends softly at the edge of sound.',
  'We were never truly out of tune.',
  'One last pulse, then everything aligns.',
  'Stay with the beat, stay with the light.',
];

// Timed script markers (seconds) for lyric-like highlighting.
const _lineStartSeconds = [
  0,
  8,
  16,
  24,
  32,
  40,
  48,
  56,
  64,
  72,
  80,
  88,
  96,
  104,
  112,
  120,
  128,
  136,
  144,
];

class PlayerScreen extends ConsumerStatefulWidget {
  final Movie movie;

  const PlayerScreen({super.key, required this.movie});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late final AnimationController _syncController;

  static const _totalSeconds = 150;

  int _lineIndexForProgress(double progress) {
    final elapsedSec = (progress * _totalSeconds).floor();
    for (int i = _lineStartSeconds.length - 1; i >= 0; i--) {
      if (elapsedSec >= _lineStartSeconds[i]) {
        return i;
      }
    }
    return 0;
  }

  void _updateProgressAndLine(WidgetRef ref, double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    final notifier = ref.read(playerProvider.notifier);
    notifier.updateProgress(clamped);
    notifier.updateCurrentLine(_lineIndexForProgress(clamped));
  }

  void _skipBy(WidgetRef ref, double delta) {
    final current = ref.read(playerProvider).progress;
    _updateProgressAndLine(ref, current + delta);
  }

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _syncController.dispose();
    super.dispose();
  }

  void _togglePlay(WidgetRef ref) {
    final notifier = ref.read(playerProvider.notifier);
    final state = ref.read(playerProvider);

    notifier.togglePlayPause();

    if (!state.isPlaying) {
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        final current = ref.read(playerProvider);
        final newProgress = (current.progress + (0.25 / _totalSeconds)).clamp(
          0.0,
          1.0,
        );
        _updateProgressAndLine(ref, newProgress);
        if (newProgress >= 1.0) {
          notifier.togglePlayPause();
          _ticker?.cancel();
        }
      });
    } else {
      _ticker?.cancel();
    }
  }

  String _formatTime(double progress) {
    final seconds = (progress * _totalSeconds).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final playerState = ref.watch(playerProvider);

    final currentLineIndex = _lineIndexForProgress(playerState.progress);

    final elapsed = _formatTime(playerState.progress);
    final remainingSeconds = ((1 - playerState.progress) * _totalSeconds)
        .round();
    final remaining =
        '-${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2FA),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),
            const _TopBar(),
            const SizedBox(height: 14),
            _MovieInfoRow(movie: movie),
            const SizedBox(height: 12),
            Expanded(
              child: _ScriptViewer(
                lines: _scriptLines,
                currentIndex: currentLineIndex,
              ),
            ),
            const SizedBox(height: 10),
            _SeekBar(
              progress: playerState.progress,
              elapsed: elapsed,
              remaining: remaining,
              onChanged: (v) => _updateProgressAndLine(ref, v),
            ),
            const SizedBox(height: 14),
            _PlaybackControls(
              isPlaying: playerState.isPlaying,
              onPlayPause: () => _togglePlay(ref),
              onSkipBack: () => _skipBy(ref, -0.05),
              onSkipForward: () => _skipBy(ref, 0.05),
            ),
            const SizedBox(height: 18),
            _SyncButton(rotation: _syncController),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 24),
                color: const Color(0xFF191B23),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE4E5EC)),
      ],
    );
  }
}

class _MovieInfoRow extends StatelessWidget {
  final Movie movie;

  const _MovieInfoRow({required this.movie});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  movie.color,
                  Color.lerp(movie.color, Colors.black, 0.45)!,
                ],
              ),
            ),
            child: Center(
              child: Text(
                movie.title.isNotEmpty ? movie.title[0].toUpperCase() : 'A',
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.playerTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF171922),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9E8EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        movie.year,
                        style: AppTextStyles.timestamp.copyWith(
                          color: const Color(0xFF2A2C37),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${movie.duration}  ·  ${movie.genre.toUpperCase()}',
                      style: AppTextStyles.timestamp.copyWith(
                        color: const Color(0xFF424550),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScriptViewer extends StatefulWidget {
  final List<String> lines;
  final int currentIndex;

  const _ScriptViewer({required this.lines, required this.currentIndex});

  @override
  State<_ScriptViewer> createState() => _ScriptViewerState();
}

class _ScriptViewerState extends State<_ScriptViewer> {
  final _scrollController = ScrollController();
  late List<GlobalKey> _lineKeys;

  @override
  void initState() {
    super.initState();
    _lineKeys = List.generate(widget.lines.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant _ScriptViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines.length != widget.lines.length) {
      _lineKeys = List.generate(widget.lines.length, (_) => GlobalKey());
    }
    if (oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final targetContext = _lineKeys[widget.currentIndex].currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            alignment: 0.32,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FA),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD0D1DB), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ListView.separated(
          controller: _scrollController,
          itemCount: widget.lines.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            return KeyedSubtree(
              key: _lineKeys[i],
              child: Text(
                widget.lines[i],
                style: AppTextStyles.bodyLarge.copyWith(
                  fontSize: 17,
                  height: 1.35,
                  color: i == widget.currentIndex
                      ? const Color(0xFF5A52EB)
                      : const Color(0xFFDCDDDF),
                  fontWeight: i == widget.currentIndex
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  final double progress;
  final String elapsed;
  final String remaining;
  final ValueChanged<double> onChanged;

  const _SeekBar({
    required this.progress,
    required this.elapsed,
    required this.remaining,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF5A52EB),
              inactiveTrackColor: const Color(0xFFE2E3F4),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 7,
                elevation: 2,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              overlayColor: const Color(0x225A52EB),
              trackHeight: 4,
            ),
            child: Slider(value: progress, onChanged: onChanged),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  elapsed,
                  style: AppTextStyles.timestamp.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF5A52EB),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  remaining,
                  style: AppTextStyles.timestamp.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF7C7F8B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;

  const _PlaybackControls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSkipBack,
    required this.onSkipForward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF0F4),
        borderRadius: BorderRadius.circular(33),
        border: Border.all(color: const Color(0xFFE5E7EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: onSkipBack,
            icon: const Icon(
              Icons.skip_previous_rounded,
              color: Color(0xFF14161D),
              size: 28,
            ),
          ),
          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF5A52EB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          IconButton(
            onPressed: onSkipForward,
            icon: const Icon(
              Icons.skip_next_rounded,
              color: Color(0xFF14161D),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncButton extends StatelessWidget {
  final AnimationController rotation;

  const _SyncButton({required this.rotation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF5047EA), Color(0xFF6E65F4)],
          ),
        ),
        child: TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: rotation,
                child: const Icon(
                  Icons.sync_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'SYNC MOVIE  88%',
                style: AppTextStyles.button.copyWith(
                  fontSize: 11,
                  color: Colors.white,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
