import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/movie.dart';
import '../theme/theme.dart';
import '../providers/player_provider.dart';

// ── Dummy script lines ───────────────────────────────────────────────────────

const _scriptLines = [
  _ScriptLine(text: 'In a world where silence speaks volumes,', isCurrent: false),
  _ScriptLine(text: 'The truth is often hidden in plain sight.', isCurrent: true),
  _ScriptLine(text: 'They called him the Architect of Echoes.', isCurrent: false),
  _ScriptLine(text: 'But echoes are just ghosts of the past.', isCurrent: false),
  _ScriptLine(text: 'Now, the frequency is changing.', isCurrent: false),
  _ScriptLine(text: 'Can you hear the light shifting?', isCurrent: false),
];

class _ScriptLine {
  final String text;
  final bool isCurrent;
  const _ScriptLine({required this.text, required this.isCurrent});
}

// ── Screen ───────────────────────────────────────────────────────────────────

class PlayerScreen extends ConsumerStatefulWidget {
  final Movie movie;

  const PlayerScreen({super.key, required this.movie});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late AnimationController _syncController;
  late Animation<double> _syncRotation;

  static const _totalSeconds = 35 * 60 + 21; // 35:21

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _syncRotation = Tween<double>(begin: 0, end: 1).animate(_syncController);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _syncController.dispose();
    super.dispose();
  }

  void _togglePlay(WidgetRef ref) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final playerState = ref.read(playerProvider);

    playerNotifier.togglePlayPause();

    if (!playerState.isPlaying) {
      _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!mounted) return;
        final current = ref.read(playerProvider);
        final newProgress = (current.progress + 0.0005).clamp(0.0, 1.0);
        playerNotifier.updateProgress(newProgress);

        if (newProgress >= 1.0) {
          playerNotifier.togglePlayPause();
          _ticker?.cancel();
        }
      });
    } else {
      _ticker?.cancel();
    }
  }

  String _formatTime(double fraction) {
    final secs = (fraction * _totalSeconds).round();
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final playerState = ref.watch(playerProvider);

    final elapsed = _formatTime(playerState.progress);
    final remaining = (() {
      final secs = ((1 - playerState.progress) * _totalSeconds).round();
      final m = secs ~/ 60;
      final s = secs % 60;
      return '-${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    })();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar
            _TopBar(movie: movie),
            // ── Movie info row
            _MovieInfoRow(movie: movie),
            const SizedBox(height: AppDimens.space3),
            // ── Script viewer
            Expanded(
              child: _ScriptViewer(
                lines: _scriptLines,
                currentIndex: playerState.currentLineIndex,
              ),
            ),
            const SizedBox(height: AppDimens.space3),
            // ── Seek bar
            _SeekBar(
              progress: playerState.progress,
              elapsed: elapsed,
              remaining: remaining,
              onChanged: (v) => ref.read(playerProvider.notifier).updateProgress(v),
            ),
            const SizedBox(height: AppDimens.space3),
            // ── Playback controls
            _PlaybackControls(
              isPlaying: playerState.isPlaying,
              onPlayPause: () => _togglePlay(ref),
              onSkipBack: () => ref.read(playerProvider.notifier).skipBackward(),
              onSkipForward: () => ref.read(playerProvider.notifier).skipForward(),
            ),
            const SizedBox(height: AppDimens.space4),
            // ── Sync button
            _SyncButton(rotation: _syncRotation),
            const SizedBox(height: AppDimens.space6),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final Movie movie;
  const _TopBar({required this.movie});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.screenHorizontalPadding,
        vertical: AppDimens.space2,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: AppColors.dividerSoft),
              ),
              child: const Icon(Icons.chevron_left_rounded, size: 20, color: AppColors.textPrimary),
            ),
          ),
          const Spacer(),
          // Play badge (centre top — purple circle with play+pause)
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26),
          ),
          const Spacer(),
          // invisible spacer to balance back button
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ── Movie Info Row ────────────────────────────────────────────────────────────

class _MovieInfoRow extends StatelessWidget {
  final Movie movie;
  const _MovieInfoRow({required this.movie});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenHorizontalPadding),
      child: Row(
        children: [
          // Poster avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [movie.color, Color.lerp(movie.color, Colors.black, 0.4)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipOval(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [movie.color, Color.lerp(movie.color, Colors.black, 0.4)!],
                  ),
                ),
                child: Center(
                  child: Text(
                    movie.title[0],
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(movie.title, style: AppTextStyles.subhead.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                '${movie.year}  ·  ${movie.duration}  ·  ${movie.genre}',
                style: AppTextStyles.timestamp.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          // AD/CC chips
          Row(
            children: [
              if (movie.hasAD) _InfoBadge(label: 'AD'),
              if (movie.hasAD && movie.hasCC) const SizedBox(width: 4),
              if (movie.hasCC) _InfoBadge(label: 'CC'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  const _InfoBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAccent,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: AppColors.dividerSoft),
      ),
      child: Text(
        label,
        style: AppTextStyles.badge.copyWith(color: AppColors.primary),
      ),
    );
  }
}

// ── Script Viewer ─────────────────────────────────────────────────────────────

class _ScriptViewer extends StatelessWidget {
  final List<_ScriptLine> lines;
  final int currentIndex;

  const _ScriptViewer({required this.lines, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenHorizontalPadding),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.dividerSoft),
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space5,
          vertical: AppDimens.space5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < lines.length; i++) ...[
              _ScriptLineWidget(line: lines[i], isCurrent: i == currentIndex),
              if (i < lines.length - 1) const SizedBox(height: AppDimens.space4),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScriptLineWidget extends StatelessWidget {
  final _ScriptLine line;
  final bool isCurrent;

  const _ScriptLineWidget({required this.line, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    if (isCurrent) {
      return Text(
        line.text,
        style: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          height: 1.4,
        ),
      );
    }
    return Text(
      line.text,
      style: AppTextStyles.bodyLarge.copyWith(
        color: AppColors.textDisabled,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    );
  }
}

// ── Seek Bar ──────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenHorizontalPadding),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.divider,
              thumbColor: AppColors.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              trackHeight: 3,
            ),
            child: Slider(
              value: progress,
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(elapsed, style: AppTextStyles.timestamp.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                Text(remaining, style: AppTextStyles.timestamp.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Playback Controls ─────────────────────────────────────────────────────────

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skip back
        _ControlButton(
          icon: Icons.skip_previous_rounded,
          size: 28,
          onTap: onSkipBack,
        ),
        const SizedBox(width: AppDimens.space5),
        // Play / Pause (big)
        GestureDetector(
          onTap: onPlayPause,
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.space5),
        // Skip forward
        _ControlButton(
          icon: Icons.skip_next_rounded,
          size: 28,
          onTap: onSkipForward,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.dividerSoft),
          boxShadow: AppShadows.card,
        ),
        child: Icon(icon, size: size, color: AppColors.textPrimary),
      ),
    );
  }
}

// ── Sync Button ───────────────────────────────────────────────────────────────

class _SyncButton extends StatelessWidget {
  final Animation<double> rotation;

  const _SyncButton({required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenHorizontalPadding),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF7B6FFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          ),
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.radiusPill)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotationTransition(
                  turns: rotation,
                  child: const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  'SYNC MOVIE  83%',
                  style: AppTextStyles.button.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
