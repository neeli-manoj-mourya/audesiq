import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/movie.dart';
import '../providers/movies_provider.dart';
import '../providers/search_provider.dart';
import '../theme/theme.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  static const _categories = ['Action', 'Comedy', 'Drama', 'Horror'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    ref.read(searchProvider.notifier).updateQuery(query);
  }

  void _searchFor(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _onQueryChanged(query);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final moviesAsync = ref.watch(moviesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: moviesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (movies) {
            final allMovies = [
              ...movies.trending,
              ...movies.newReleases,
              ...movies.recommendations,
            ];
            final trimmedQuery = searchState.query.trim();
            final results = trimmedQuery.isEmpty
                ? allMovies.take(3).toList()
                : allMovies.where((m) => m.matches(trimmedQuery)).toList();
            return ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                const SizedBox(height: 10),
                _SearchRow(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onQueryChanged,
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/dashboard');
                    }
                  },
                ),
                const SizedBox(height: 22),
                _SectionLabel(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'RECENT SEARCHES',
                  uppercase: true,
                ),
                const SizedBox(height: 12),
                _RecentSearches(
                  onTapChip: _searchFor,
                  searches: searchState.recentSearches.isEmpty
                      ? const [
                          'Interstellar',
                          'The Dark Knight',
                          'Action',
                          'Sci-Fi',
                        ]
                      : searchState.recentSearches,
                ),
                const SizedBox(height: 26),
                const _SectionLabel(
                  icon: Icons.trending_up_rounded,
                  title: 'Trending Now',
                ),
                const SizedBox(height: 14),
                _TrendingStrip(movies: movies.trending),
                const SizedBox(height: 24),
                const _SectionLabel(icon: null, title: 'Explore Categories'),
                const SizedBox(height: 12),
                _CategoryGrid(onTap: _searchFor),
                const SizedBox(height: 26),
                _ResultsHeader(resultsCount: results.length),
                const SizedBox(height: 12),
                ...List.generate(
                  results.length,
                  (i) => Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: _ResultCard(
                      movie: results[i],
                      displayTitle: 'Cinematic Masterpiece ${i + 1}',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack;

  const _SearchRow({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE1E3ED)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Color(0xFF242834),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1F6),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                autofocus: true,
                onSubmitted: onChanged,
                cursorColor: const Color(0xFF5A6072),
                selectionControls: materialTextSelectionControls,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontSize: 16,
                  color: const Color(0xFF3A3D49),
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(
                      color: Color(0xFFE1E3ED),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(
                      color: Color(0xFFE1E3ED),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(
                      color: Color(0xFFC9CDD8),
                      width: 1.2,
                    ),
                  ),
                  hintText: 'Search movies, series, or actors...',
                  hintStyle: AppTextStyles.searchPlaceholder.copyWith(
                    fontSize: 16,
                    color: const Color(0xFF6E7382),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: Color(0xFF808595),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFF101217),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_none_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData? icon;
  final String title;
  final bool uppercase;

  const _SectionLabel({
    required this.icon,
    required this.title,
    this.uppercase = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon!,
              size: uppercase ? 16 : 18,
              color: const Color(0xFF6A6F7F),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            title,
            style: AppTextStyles.subhead.copyWith(
              fontSize: uppercase ? 11 : 15,
              letterSpacing: uppercase ? 1.3 : 0,
              fontWeight: uppercase ? FontWeight.w700 : FontWeight.w800,
              color: const Color(0xFF262A37),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  final List<String> searches;
  final ValueChanged<String> onTapChip;

  const _RecentSearches({required this.searches, required this.onTapChip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: searches
            .map(
              (s) => GestureDetector(
                onTap: () => onTapChip(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EBF0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    s,
                    style: AppTextStyles.timestamp.copyWith(
                      fontSize: 12,
                      color: const Color(0xFF384051),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TrendingStrip extends StatelessWidget {
  final List<Movie> movies;

  const _TrendingStrip({required this.movies});

  @override
  Widget build(BuildContext context) {
    final displayTitles = [
      'The Silent Forest',
      'Neon Horizon',
      'Obsidian Rush',
      'Crimson Tide',
    ];
    final displayMovies = movies.take(4).toList();

    return SizedBox(
      height: 236,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 18),
        scrollDirection: Axis.horizontal,
        itemCount: displayMovies.length,
        itemBuilder: (_, i) {
          final movie = displayMovies[i];
          return GestureDetector(
            onTap: () => context.push('/player', extra: movie),
            child: Container(
              width: 130,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 170,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(movie.color, Colors.black, 0.12)!,
                          Color.lerp(movie.color, Colors.black, 0.44)!,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4E49E8),
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
                  const SizedBox(height: 8),
                  Text(
                    displayTitles[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subhead.copyWith(
                      color: const Color(0xFF1A1C29),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.closed_caption_outlined,
                        size: 11,
                        color: Color(0xFF5A52EB),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'CC',
                        style: AppTextStyles.timestamp.copyWith(
                          color: const Color(0xFF2B2D38),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.star_border_rounded,
                        size: 12,
                        color: Color(0xFF2B2D38),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '4.9',
                        style: AppTextStyles.timestamp.copyWith(
                          color: const Color(0xFF2B2D38),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final ValueChanged<String> onTap;

  const _CategoryGrid({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bgColors = [
      const Color(0xFFE2E3E7),
      const Color(0xFFEDE3D8),
      const Color(0xFFDDE5F3),
      const Color(0xFFDFE0E5),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _SearchScreenState._categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.55,
        ),
        itemBuilder: (_, i) {
          final label = _SearchScreenState._categories[i];
          return GestureDetector(
            onTap: () => onTap(label),
            child: Container(
              decoration: BoxDecoration(
                color: bgColors[i],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  label,
                  style: AppTextStyles.subhead.copyWith(
                    fontSize: 13,
                    color: const Color(0xFF222631),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final int resultsCount;

  const _ResultsHeader({required this.resultsCount});

  @override
  Widget build(BuildContext context) {
    final countText = '$resultsCount results found';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Text(
            'Search Results',
            style: AppTextStyles.headingLarge.copyWith(
              fontSize: 16,
              color: const Color(0xFF1E222D),
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            countText,
            style: AppTextStyles.timestamp.copyWith(
              fontSize: 12,
              color: const Color(0xFF585F70),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Movie movie;
  final String displayTitle;

  const _ResultCard({required this.movie, required this.displayTitle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/player', extra: movie),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE4E6EE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 86,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    movie.color,
                    Color.lerp(movie.color, Colors.black, 0.5)!,
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: AppTextStyles.subhead.copyWith(
                        color: const Color(0xFF1A1D28),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${movie.year} • ${movie.duration} • ${movie.genre}',
                      style: AppTextStyles.timestamp.copyWith(
                        color: const Color(0xFF5A6072),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _miniBadge('AD', dark: true),
                        const SizedBox(width: 6),
                        _miniBadge('CC'),
                        const Spacer(),
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFCE39),
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '4.8',
                          style: AppTextStyles.timestamp.copyWith(
                            color: const Color(0xFF242935),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  Widget _miniBadge(String label, {bool dark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1B1D23) : const Color(0xFFE7E8EC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? Colors.white : const Color(0xFF414758),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
