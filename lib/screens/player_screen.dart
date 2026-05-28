import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';
import '../models/playback_status.dart';
import '../models/subtitle_entry.dart';
import '../models/sync_state.dart';
import '../providers/sync_provider.dart';
import '../theme/theme.dart';

// Fallback static script shown while AD audio is not yet downloaded
const _fallbackLines = [
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _formatMs(int ms) {
  final total = (ms ~/ 1000).clamp(0, 999999);
  final m = total ~/ 60;
  final s = total % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

int _subtitleIndexAt(List<SubtitleEntry> entries, int positionMs) {
  if (entries.isEmpty) return 0;
  for (int i = 0; i < entries.length; i++) {
    if (entries[i].containsTimestamp(positionMs)) return i;
    if (positionMs < entries[i].startMs)
      return (i - 1).clamp(0, entries.length - 1);
  }
  return entries.length - 1;
}

// ─────────────────────────────────────────────────────────────────────────────
// PlayerScreen
// ─────────────────────────────────────────────────────────────────────────────

class PlayerScreen extends ConsumerStatefulWidget {
  final Movie movie;

  const PlayerScreen({super.key, required this.movie});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _syncController;

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
    _syncController.dispose();
    super.dispose();
  }

  void _onPlayPause() {
    final playbackManager = ref.read(audioPlaybackManagerProvider);
    final status = ref.read(playbackStatusStreamProvider).valueOrNull;
    if (status?.state == AdPlaybackState.playing) {
      playbackManager.pause();
    } else {
      playbackManager.resume();
    }
  }

  void _onSkipBack() {
    final pm = ref.read(audioPlaybackManagerProvider);
    pm.seekTo((pm.getCurrentPlaybackTimestampMs() - 5000).clamp(0, 999999999));
  }

  void _onSkipForward() {
    final pm = ref.read(audioPlaybackManagerProvider);
    pm.seekTo(pm.getCurrentPlaybackTimestampMs() + 5000);
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final setupState = ref.watch(playerSetupProvider);
    final playbackStatus = ref.watch(playbackStatusStreamProvider).valueOrNull;
    final subtitleTrack = ref.watch(subtitleTrackProvider);

    // Determine script lines and highlighted index
    final List<String> scriptLines;
    final int currentLineIndex;

    if (subtitleTrack != null && subtitleTrack.entries.isNotEmpty) {
      scriptLines = subtitleTrack.entries.map((e) => e.text).toList();
      currentLineIndex = _subtitleIndexAt(
        subtitleTrack.entries,
        playbackStatus?.currentPositionMs ?? 0,
      );
    } else {
      scriptLines = _fallbackLines;
      currentLineIndex = 0;
    }

    // Seek bar values from real AD audio playback
    final durationMs = playbackStatus?.durationMs ?? 0;
    final positionMs = playbackStatus?.currentPositionMs ?? 0;
    final progress = durationMs > 0
        ? (positionMs / durationMs).clamp(0.0, 1.0)
        : 0.0;
    final elapsed = _formatMs(positionMs);
    final remaining =
        '-${_formatMs((durationMs - positionMs).clamp(0, durationMs))}';
    final isPlaying = playbackStatus?.state == AdPlaybackState.playing;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2FA),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),
            const _TopBar(),
            const SizedBox(height: 14),
            _MovieInfoRow(movie: movie),
            const SizedBox(height: 8),

            // ── AD subtitle viewer (replaces static lyrics) ──────────────
            Expanded(
              child: _ScriptViewer(
                lines: scriptLines,
                currentIndex: currentLineIndex,
              ),
            ),
            const SizedBox(height: 10),

            // ── Seek bar — real AD audio position ────────────────────────
            _SeekBar(
              progress: progress,
              elapsed: elapsed,
              remaining: remaining,
              onChanged: setupState.isReady
                  ? (v) {
                      ref
                          .read(audioPlaybackManagerProvider)
                          .seekTo((v * durationMs).round());
                    }
                  : null,
            ),
            const SizedBox(height: 14),

            // ── Playback controls — real AD audio ────────────────────────
            _PlaybackControls(
              isPlaying: isPlaying,
              onPlayPause: setupState.isReady ? _onPlayPause : null,
              onSkipBack: setupState.isReady ? _onSkipBack : null,
              onSkipForward: setupState.isReady ? _onSkipForward : null,
            ),
            const SizedBox(height: 18),

            // ── Sync button ───────────────────────────────────────────────
            const _SyncButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setup banner — shows download button, progress, or ready state
// ─────────────────────────────────────────────────────────────────────────────

class _SetupBanner extends ConsumerWidget {
  final PlayerSetupState setupState;

  const _SetupBanner({required this.setupState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = setupState.phase;

    Color bgColor;
    Color borderColor;
    Widget leading;

    switch (phase) {
      case SetupPhase.initial:
        bgColor = const Color(0xFFEEF0FF);
        borderColor = const Color(0xFF5A52EB);
        leading = const Icon(
          Icons.download_rounded,
          color: Color(0xFF5A52EB),
          size: 18,
        );
      case SetupPhase.downloading:
      case SetupPhase.indexing:
        bgColor = const Color(0xFFFFF9E6);
        borderColor = const Color(0xFFFFD966);
        leading = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB8860B)),
          ),
        );
      case SetupPhase.ready:
        bgColor = const Color(0xFFE6F9EE);
        borderColor = const Color(0xFF22BB66);
        leading = const Icon(
          Icons.check_circle_outline_rounded,
          color: Color(0xFF22BB66),
          size: 18,
        );
      case SetupPhase.error:
        bgColor = const Color(0xFFFFEEEE);
        borderColor = const Color(0xFFFF6B6B);
        leading = const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFFF6B6B),
          size: 18,
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: (phase == SetupPhase.initial || phase == SetupPhase.error)
            ? () => ref.read(playerSetupProvider.notifier).downloadAndPrepare()
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  phase == SetupPhase.initial
                      ? 'Tap to download audio description'
                      : setupState.message,
                  style: AppTextStyles.timestamp.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF2A2C37),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (phase == SetupPhase.initial || phase == SetupPhase.error)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF7C7F8B),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Caption display — current AD subtitle at the AD playback position
// ─────────────────────────────────────────────────────────────────────────────

class _CaptionDisplay extends ConsumerWidget {
  final int positionMs;

  const _CaptionDisplay({required this.positionMs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitleTrack = ref.watch(subtitleTrackProvider);
    final captionText = subtitleTrack?.subtitleAt(positionMs)?.text ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD966), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Captions',
              style: AppTextStyles.timestamp.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8B7500),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              captionText.isEmpty ? 'No caption at this moment' : captionText,
              style: AppTextStyles.bodyLargeSecondary.copyWith(
                fontSize: 13,
                color: const Color(0xFF3E3E3E),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync button — mirrors Android MainViewModel.onSyncPressed() flow
// ─────────────────────────────────────────────────────────────────────────────

class _SyncButton extends ConsumerWidget {
  const _SyncButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupState = ref.watch(playerSetupProvider);
    final syncPhase = ref.watch(syncStateStreamProvider).valueOrNull?.phase;

    final isSyncing = setupState.isSyncing;
    final isConnected =
        setupState.hasSyncSuccess || syncPhase == SyncPhase.stable;
    final canTap = setupState.isReady;

    return SizedBox(
      width: 220,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: !canTap
                ? [const Color(0xFFB0B0C8), const Color(0xFFB0B0C8)]
                : isConnected
                ? [const Color(0xFF00AA44), const Color(0xFF22DD66)]
                : [const Color(0xFF5047EA), const Color(0xFF6E65F4)],
          ),
        ),
        child: TextButton(
          onPressed: !canTap
              ? null
              : isSyncing
              ? () => ref.read(playerSetupProvider.notifier).cancelSync()
              : () => ref.read(playerSetupProvider.notifier).onSyncPressed(),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSyncing)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
              else if (isConnected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 15,
                )
              else
                const Icon(Icons.sync_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              Text(
                isSyncing
                    ? 'LISTENING…'
                    : isConnected
                    ? 'IN SYNC  ✓'
                    : !canTap
                    ? 'DOWNLOAD FIRST'
                    : 'SYNC AD',
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

// ─────────────────────────────────────────────────────────────────────────────
// Unchanged widgets (visual design preserved exactly)
// ─────────────────────────────────────────────────────────────────────────────

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
        _scrollToIndex(widget.currentIndex);
      });
    }
  }

  /// Scrolls the ListView so that item [idx] is visible and centred.
  ///
  /// ListView.separated is lazy — items outside the current viewport are not
  /// built, so their GlobalKey.currentContext is null.  When that happens we
  /// first jump to an estimated offset (which forces Flutter to build the
  /// surrounding items on the next layout pass), then schedule a second
  /// post-frame callback that calls Scrollable.ensureVisible once the target
  /// RenderObject actually exists.
  void _scrollToIndex(int idx) {
    if (!_scrollController.hasClients) return;
    if (idx < 0 || idx >= _lineKeys.length) return;

    final targetCtx = _lineKeys[idx].currentContext;
    if (targetCtx != null) {
      Scrollable.ensureVisible(
        targetCtx,
        alignment: 0.35,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    } else {
      // Item is virtualised — jump to an approximate offset first so Flutter
      // builds it, then refine with ensureVisible on the next frame.
      // ~50 px per item (2 lines × 17 px × 1.35 leading ≈ 46 px) + 16 px separator.
      const estimatedItemHeight = 50.0;
      const separatorHeight = 16.0;
      final approxOffset = (idx * (estimatedItemHeight + separatorHeight))
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(approxOffset);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _lineKeys[idx].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.35,
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
  final ValueChanged<double>? onChanged;

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
              disabledActiveTrackColor: const Color(0xFFB0B0C8),
              disabledInactiveTrackColor: const Color(0xFFE2E3F4),
              disabledThumbColor: const Color(0xFFD0D0D0),
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
  final VoidCallback? onPlayPause;
  final VoidCallback? onSkipBack;
  final VoidCallback? onSkipForward;

  const _PlaybackControls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSkipBack,
    required this.onSkipForward,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPlayPause != null;
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
            icon: Icon(
              Icons.skip_previous_rounded,
              color: enabled
                  ? const Color(0xFF14161D)
                  : const Color(0xFFB0B0C8),
              size: 28,
            ),
          ),
          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFF5A52EB)
                    : const Color(0xFFB0B0C8),
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
            icon: Icon(
              Icons.skip_next_rounded,
              color: enabled
                  ? const Color(0xFF14161D)
                  : const Color(0xFFB0B0C8),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
