import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';

class MoviesData {
  final List<Movie> trending;
  final List<Movie> newReleases;
  final List<Movie> recommendations;

  MoviesData({
    required this.trending,
    required this.newReleases,
    required this.recommendations,
  });
}

final moviesProvider = FutureProvider<MoviesData>((ref) async {
  final raw = await rootBundle.loadString('assets/data/movies.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return MoviesData(
    trending: (data['trending'] as List)
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList(),
    newReleases: (data['new_releases'] as List)
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList(),
    recommendations: (data['recommendations'] as List)
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
});
