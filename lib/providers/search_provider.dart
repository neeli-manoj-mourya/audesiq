import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import 'movies_provider.dart';

class SearchState {
  final String query;
  final List<Movie> results;
  final List<String> recentSearches;

  SearchState({
    required this.query,
    required this.results,
    required this.recentSearches,
  });

  factory SearchState.initial() => SearchState(
    query: '',
    results: [],
    recentSearches: [],
  );

  SearchState copyWith({
    String? query,
    List<Movie>? results,
    List<String>? recentSearches,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      recentSearches: recentSearches ?? this.recentSearches,
    );
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final moviesAsync = ref.watch(moviesProvider);
  return SearchNotifier(moviesAsync);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final AsyncValue<MoviesData> moviesAsync;

  SearchNotifier(this.moviesAsync) : super(SearchState.initial());

  void updateQuery(String query) {
    state = state.copyWith(query: query);

    moviesAsync.whenData((movies) {
      final allMovies = [
        ...movies.trending,
        ...movies.newReleases,
        ...movies.recommendations,
      ];

      if (query.isEmpty) {
        state = state.copyWith(results: []);
      } else {
        final results = allMovies.where((m) => m.matches(query)).toList();
        state = state.copyWith(results: results);
      }
    });
  }

  void addRecentSearch(String search) {
    if (search.isEmpty) return;
    final updated = [search, ...state.recentSearches];
    state = state.copyWith(recentSearches: updated.take(5).toList());
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: []);
  }
}
