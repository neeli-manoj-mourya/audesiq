import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';
import '../providers/movies_provider.dart';
import '../theme/theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF0F4),
      body: SafeArea(
        child: moviesAsync.when(
          data: (movies) => ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              const SizedBox(height: 8),
              const _Header(),
              const SizedBox(height: 14),
              const _SearchBar(),
              const SizedBox(height: 18),
              _MovieSection(
                title: 'Trending Movies',
                movies: movies.trending,
                useBackgroundCard: false,
                titleOverrides: const [
                  'The Silent Forest',
                  'Neon Horizon',
                  'Obsidian Rush',
                  'Crimson Tide',
                ],
              ),
              const SizedBox(height: 14),
              _MovieSection(
                title: 'New Releases',
                movies: movies.newReleases,
                useBackgroundCard: true,
                titleOverrides: const [
                  'Velvet Nights',
                  'Star-Crossed',
                  'The Last Call',
                  'Phoenix Lane',
                ],
              ),
              const SizedBox(height: 14),
              _MovieSection(
                title: 'Recommendations',
                movies: movies.recommendations,
                useBackgroundCard: false,
                titleOverrides: const [
                  'Midnight Echo',
                  'Golden Sands',
                  'Crystal Wave',
                  'Nova Drift',
                ],
              ),
              const SizedBox(height: 18),
              const _AccessibilityCard(),
              const SizedBox(height: 34),
              const _FooterTagline(),
              const SizedBox(height: 16),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/audesiq-launcher.png',
            width: 44,
            height: 44,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AUDESIQ',
                style: AppTextStyles.titleLarge.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: const Color(0xFF191A2A),
                ),
              ),
              Text(
                'DISCOVER',
                style: AppTextStyles.timestamp.copyWith(
                  fontSize: 9,
                  letterSpacing: 2.7,
                  color: const Color(0xFF6D66FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/search'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EAF0),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF262733),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search movies, genres, actors...',
                  style: AppTextStyles.searchPlaceholder.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF444455),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieSection extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final List<String> titleOverrides;
  final bool useBackgroundCard;

  const _MovieSection({
    required this.title,
    required this.movies,
    required this.titleOverrides,
    required this.useBackgroundCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: useBackgroundCard ? Colors.white : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  title,
                  style: AppTextStyles.headingLarge.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: const Color(0xFF1D1D29),
                  ),
                ),
                const Spacer(),
                Text(
                  'View All',
                  style: AppTextStyles.subhead.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 275,
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 20),
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              itemBuilder: (_, i) => _MovieCard(
                movie: movies[i],
                titleOverride: i < titleOverrides.length
                    ? titleOverrides[i]
                    : movies[i].title,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  final Movie movie;
  final String titleOverride;

  const _MovieCard({required this.movie, required this.titleOverride});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/player', extra: movie),
      child: SizedBox(
        width: 170,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.lerp(movie.color, Colors.black, 0.16)!,
                              Color.lerp(movie.color, Colors.black, 0.45)!,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5146FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'AD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                titleOverride,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subhead.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1B28),
                ),
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(
                    Icons.closed_caption_outlined,
                    size: 11,
                    color: Color(0xFF6258FF),
                  ),
                  SizedBox(width: 3),
                  Text(
                    'CC',
                    style: TextStyle(
                      fontSize: 8,
                      color: Color(0xFF2E2E38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.star_border_rounded,
                    size: 11,
                    color: Color(0xFF2E2E38),
                  ),
                  SizedBox(width: 2),
                  Text(
                    '4.9',
                    style: TextStyle(
                      fontSize: 8,
                      color: Color(0xFF2E2E38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessibilityCard extends StatelessWidget {
  const _AccessibilityCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE9EAF2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.7),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F4FA),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tv, color: AppColors.primary, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enhanced Accessibility',
                    style: AppTextStyles.subhead.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F1D2B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All movies in Audesiq include high-quality\nAudio Descriptions (AD) and Closed\nCaptions (CC) for an inclusive experience.',
                    style: AppTextStyles.timestamp.copyWith(
                      fontSize: 8,
                      height: 1.35,
                      color: const Color(0xFF4A4B59),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterTagline extends StatelessWidget {
  const _FooterTagline();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _FooterLine(),
            SizedBox(width: 10),
            Icon(Icons.grid_view_rounded, size: 13, color: Color(0xFF8D8F99)),
            SizedBox(width: 10),
            _FooterLine(),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'PREMIUM CINEMA EXPERIENCE',
          style: AppTextStyles.timestamp.copyWith(
            fontSize: 8,
            letterSpacing: 3.1,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8D8F99),
          ),
        ),
      ],
    );
  }
}

class _FooterLine extends StatelessWidget {
  const _FooterLine();

  @override
  Widget build(BuildContext context) {
    return Container(width: 34, height: 1, color: const Color(0xFFA3A5AF));
  }
}
