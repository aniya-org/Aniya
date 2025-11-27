import 'package:equatable/equatable.dart';

class ChapterEntity extends Equatable {
  final String id;
  final String mediaId;
  final String title;
  final double number;
  final DateTime? releaseDate;
  final int? pageCount;

  /// Provider that supplied this chapter data
  final String? sourceProvider;

  const ChapterEntity({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.number,
    this.releaseDate,
    this.pageCount,
    this.sourceProvider,
  });

  @override
  List<Object?> get props => [
    id,
    mediaId,
    title,
    number,
    releaseDate,
    pageCount,
    sourceProvider,
  ];

  ChapterEntity copyWith({
    String? id,
    String? mediaId,
    String? title,
    double? number,
    DateTime? releaseDate,
    int? pageCount,
    String? sourceProvider,
  }) {
    return ChapterEntity(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      title: title ?? this.title,
      number: number ?? this.number,
      releaseDate: releaseDate ?? this.releaseDate,
      pageCount: pageCount ?? this.pageCount,
      sourceProvider: sourceProvider ?? this.sourceProvider,
    );
  }
}
