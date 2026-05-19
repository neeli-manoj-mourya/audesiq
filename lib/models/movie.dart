import 'package:flutter/material.dart';

class Movie {
  final String id;
  final String title;
  final String year;
  final String genre;
  final String rating;
  final String duration;
  final bool hasAD;
  final bool hasCC;
  final Color color;

  const Movie({
    required this.id,
    required this.title,
    required this.year,
    required this.genre,
    required this.rating,
    required this.duration,
    required this.hasAD,
    required this.hasCC,
    required this.color,
  });

  factory Movie.fromJson(Map<String, dynamic> j) => Movie(
        id: j['id'] as String,
        title: j['title'] as String,
        year: j['year'] as String,
        genre: j['genre'] as String,
        rating: j['rating'] as String,
        duration: j['duration'] as String,
        hasAD: j['hasAD'] as bool,
        hasCC: j['hasCC'] as bool,
        color: Color(int.parse(j['color'] as String)),
      );

  /// Returns true if [query] matches title, genre or year (case-insensitive).
  bool matches(String query) {
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        genre.toLowerCase().contains(q) ||
        year.contains(q);
  }
}
