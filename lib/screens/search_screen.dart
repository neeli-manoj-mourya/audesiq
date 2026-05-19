import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/movie.dart';
import '../theme/theme.dart';
import '../providers/search_provider.dart';
import '../providers/movies_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  // Genre categories
  static const _categories = ['Action', 'Comedy', 'Drama', 'Horror', 'Sci-Fi', 'Thriller'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
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
    final hasSearched = searchState.query.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: moviesAsync.when(
                data: (movies) => hasSearched
                    ? _buildResults(searchState.results)
                    : _buildDiscovery(movies),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenHorizontalPadding,
        AppDimens.space3,
        AppDimens.screenHorizontalPadding,
        AppDimens.space3,
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: AppColors.dividerSoft),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: AppDimens.space3),
          // Search field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _onQueryChanged,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search movies, genres, actors…',
                hintStyle: AppTextStyles.searchPlaceholder,
                prefixIcon: const Icon(Icons.search, color: AppColors.textDisabled, size: 20),
                suffixIcon: _controller.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                        child: const Icon(Icons.close, size: 18, color: AppColors.textDisabled),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.dividerSoft),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.dividerSoft),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space2),
          // Filter icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            ),
            child: const Icon(Icons.tune, color: AppColors.primary, size: 18),
          ),
        ],
      ),
    );
  }

  // ── Discovery (no query yet) ──────────────────────────────────────────────

  Widget _buildDiscovery(MoviesData movies) {
    final recentSearches = ref.watch(searchProvider).recentSearches;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
      children: [
        // Recent Searches
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenHorizontalPadding),
          child: Row(
            children: [
              const Icon(Icons.history, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('Recent Searches', style: AppTextStyles.subhead.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.space3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenHorizontalPadding),
          child: Wrap(
            spacing: AppDimens.space2,
            runSpacing: AppDimens.space2,
            children: recentSearches.isEmpty
                ? ['Interstellar', 'The Dark Knight', 'Action', 'Sci-Fi']
                    .map((s) => _RecentChip(label: s, onTap: () => _searchFor(s)))
                    .toList()
                : recentSearches
                    .map((s) => _RecentChip(label: s, onTap: () => _searchFor(s)))
                    .toList(),
          ),
        ),
        const SizedBox(height: AppDimens.space6),
        // Trending Now (mini cards)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenHorizontalPadding),
          child: Row(
            children: [
              const Icon(Icons.trending_up_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Trending Now', style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.space3),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: AppDimens.screenHorizontalPadding),
            itemCount: movies.trending.take(6).length,
            itemBuilder: (context, i) => _TrendingMiniCard(movie: movies.trending[i]),
          ),
        ),
        const SizedBox(height: AppDimens.space6),
        // Explore Categories
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenHorizontalPadding),
          child: Text('Explore Categories', style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary)),
        ),
        const SizedBox(height: AppDimens.space3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenHorizontalPadding),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppDimens.space3,
              crossAxisSpacing: AppDimens.space3,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, i) => _CategoryChip(
              label: _categories[i],
              onTap: () => _searchFor(_categories[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults(List<Movie> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: AppColors.textDisabled),
            const SizedBox(height: AppDimens.space3),
            Text('No results found', style: AppTextStyles.subhead.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppDimens.space2),
            Text(
              'Try a different keyword or browse\nthe categories below',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textDisabled),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screenHorizontalPadding,
            AppDimens.space4,
            AppDimens.screenHorizontalPadding,
            AppDimens.space3,
          ),
          child: Text(
            '${results.length} result${results.length == 1 ? '' : 's'} found',
            style: AppTextStyles.subhead.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenHorizontalPadding),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppDimens.space3),
            itemBuilder: (context, i) => _SearchResultCard(movie: results[i]),
          ),
        ),
        const SizedBox(height: AppDimens.space4),
      ],
    );
  }
}

// ── Recent Chip ───────────────────────────────────────────────────────────────

class _RecentChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RecentChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          border: Border.all(color: AppColors.dividerSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 13, color: AppColors.textDisabled),
            const SizedBox(width: 5),
            Text(label, style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Trending Mini Card ────────────────────────────────────────────────────────

class _TrendingMiniCard extends StatelessWidget {
  final Movie movie;

  const _TrendingMiniCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      margin: const EdgeInsets.only(right: AppDimens.space3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        gradient: LinearGradient(
          colors: [movie.color, Color.lerp(movie.color, Colors.black, 0.5)!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              bottom: 8,
              left: 6,
              right: 6,
              child: Text(
                movie.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Chip ──────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: AppColors.dividerSoft),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.subhead.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

// ── Search Result Card ────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final Movie movie;

  const _SearchResultCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/player', extra: movie),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          boxShadow: AppShadows.card,
        ),
        child: Row(
        children: [
          // Poster thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppDimens.radiusMd),
              bottomLeft: Radius.circular(AppDimens.radiusMd),
            ),
            child: Container(
              width: 72,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [movie.color, Color.lerp(movie.color, Colors.black, 0.5)!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: Text(
                    movie.genre,
                    style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 9),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space3),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, style: AppTextStyles.subhead, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    '${movie.year} · ${movie.duration}',
                    style: AppTextStyles.timestamp.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.accent, size: 13),
                      const SizedBox(width: 3),
                      Text(movie.rating, style: AppTextStyles.badge.copyWith(color: AppColors.accent)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (movie.hasAD) _SmallBadge(label: 'AD'),
                      if (movie.hasAD && movie.hasCC) const SizedBox(width: 4),
                      if (movie.hasCC) _SmallBadge(label: 'CC'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space3),
          Icon(Icons.chevron_right, color: AppColors.textDisabled, size: 18),
          const SizedBox(width: AppDimens.space2),
        ],
      ),
    ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;

  const _SmallBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.dividerSoft),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
