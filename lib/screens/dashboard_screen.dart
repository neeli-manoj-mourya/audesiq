import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/movie.dart';
import '../theme/theme.dart';
import '../providers/movies_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      body: SafeArea(
        child: moviesAsync.when(
          data: (movies) => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const _Header(),
              const _SearchBar(),

              _MovieSection(
                title: 'Trending Movies',
                movies: movies.trending,
              ),

              _MovieSection(
                title: 'New Releases',
                movies: movies.newReleases,
              ),

              _MovieSection(
                title: 'Recommendations',
                movies: movies.recommendations,
              ),

              const SizedBox(height: 26),

              const _AccessibilityCard(),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  'PREMIUM CINEMA EXPERIENCE',
                  style: AppTextStyles.timestamp.copyWith(
                    fontSize: 8,
                    letterSpacing: 2,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => Center(
            child: Text(e.toString()),
          ),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'AUDES',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.primary,
                  ),
                ),
                TextSpan(
                  text: 'IQ',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 2),

          Text(
            'ACCESSIBLE CINEMA',
            style: AppTextStyles.timestamp.copyWith(
              fontSize: 8,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
              color: AppColors.textDisabled,
            ),
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
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F1F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: AppColors.textDisabled.withOpacity(0.7),
                size: 18,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Search movies, actors...',
                  style: AppTextStyles.searchPlaceholder.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary.withOpacity(0.8),
                  ),
                ),
              ),

              Icon(
                Icons.tune_rounded,
                color: AppColors.primary.withOpacity(0.8),
                size: 18,
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

  const _MovieSection({
    required this.title,
    required this.movies,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  title,
                  style: AppTextStyles.headingLarge.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const Spacer(),

                Text(
                  'View All',
                  style: AppTextStyles.subhead.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(width: 2),

                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 14,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 190,
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 20),
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              itemBuilder: (_, i) {
                return _MovieCard(movie: movies[i]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  final Movie movie;

  const _MovieCard({
    required this.movie,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/player', extra: movie),
      child: Container(
        width: 104,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 158,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            movie.color,
                            Color.lerp(
                              movie.color,
                              Colors.black,
                              0.25,
                            )!,
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          movie.genre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.55),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 2),

                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: AppColors.accent,
                                  size: 10,
                                ),

                                const SizedBox(width: 2),

                                Text(
                                  movie.rating,
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            Row(
                              children: [
                                if (movie.hasAD)
                                  const _MiniBadge(label: 'AD'),

                                if (movie.hasAD && movie.hasCC)
                                  const SizedBox(width: 4),

                                if (movie.hasCC)
                                  const _MiniBadge(label: 'CC'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;

  const _MiniBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 0.6,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7,
            fontWeight: FontWeight.w700,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.accessibility_new_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enhanced Accessibility',
                  style: AppTextStyles.subhead.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'Audio Description and Closed Captions available.',
                  style: AppTextStyles.timestamp.copyWith(
                    fontSize: 9,
                    color: AppColors.textSecondary,
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