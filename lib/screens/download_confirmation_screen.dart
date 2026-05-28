
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movie.dart';
import '../providers/sync_provider.dart';

class DownloadConfirmationScreen extends ConsumerStatefulWidget {
  final Movie movie;
  const DownloadConfirmationScreen({super.key, required this.movie});

  @override
  ConsumerState<DownloadConfirmationScreen> createState() => _DownloadConfirmationScreenState();
}


class _DownloadConfirmationScreenState extends ConsumerState<DownloadConfirmationScreen> {
  bool _showLoader = false;
  String? _errorMessage;
  String? _progressMessage;

  static const String titleText = 'Download Movie';
  static const String message =
      'This movie will be downloaded to local storage and will be automatically deleted after 12 hours. Offline playback will use these local files once the download finishes.';
  static const String downloadLabel = 'Download';
  static const String cancelLabel = 'Cancel';

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFFF5F3FF);
    const Color primary = Color(0xFF5B4DFF);
    const Color accent = Color(0xFFFFD400);
    const Color card = Color(0xFFFFFFFF);
    const Color textPrimary = Color(0xFF1E1E1E);
    const Color textSecondary = Color(0xFF6B7280);
    const Color overlay = Color(0x612E2E2E);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          _buildBackgroundContent(context),
          if (!_showLoader) ...[
            Positioned.fill(
              child: ModalBarrier(
                dismissible: false,
                color: overlay,
              ),
            ),
            Center(
              child: _buildModalCard(
                context,
                card,
                primary,
                textPrimary,
                textSecondary,
              ),
            ),
          ] else ...[
            Positioned.fill(
              child: ModalBarrier(
                dismissible: false,
                color: overlay,
              ),
            ),
            Center(
              child: _buildLoaderCard(
                context,
                card,
                primary,
                accent,
                textPrimary,
                textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBackgroundContent(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B4DFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Audesiq',
                  style: GoogleFonts.montserrat(
                      fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1E1E1E)),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Expanded(
              child: Center(
                child: Text(
                  'Player / Detail screen preview\n(under modal)',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalCard(
    BuildContext context,
    Color cardBg,
    Color primary,
    Color textPrimary,
    Color textSecondary,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B4DFF).withOpacity(0.08),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              titleText,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.movie.title,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  setState(() {
                    _showLoader = true;
                    _errorMessage = null;
                    _progressMessage = null;
                  });
                  final notifier = ref.read(playerSetupProvider.notifier);
                  try {
                    await notifier.downloadAndPrepare();
                    if (!mounted) return;
                    GoRouter.of(context).go('/player', extra: widget.movie);
                  } catch (e, st) {
                    setState(() {
                      _showLoader = false;
                      _errorMessage = 'Download failed: $e';
                    });
                    // ignore: avoid_print
                    print('Download error: $e\n$st');
                  }
                },
                icon: const Icon(Icons.cloud_download, size: 20, color: Colors.white),
                label: Text(
                  downloadLabel,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_progressMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  _progressMessage!,
                  style: TextStyle(color: Colors.blueGrey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            GestureDetector(
              onTap: () {
                setState(() => _showLoader = false);
              },
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    cancelLabel,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaderCard(
    BuildContext context,
    Color cardBg,
    Color primary,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.08),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: null,
                      color: accent,
                      backgroundColor: const Color(0xFFEDEBFF),
                      strokeWidth: 8,
                    ),
                  ),
                  Text(
                    '0%',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Downloading audio descriptions and captions…',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This movie will be stored locally and will be automatically deleted after 12 hours.',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() => _showLoader = false);
              },
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    'Cancel Download',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
