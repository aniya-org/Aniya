import 'package:equatable/equatable.dart';

class ChapterEntity extends Equatable {
  final String id;
  final String mediaId;
  final String title;
  final double number;
  final DateTime? releaseDate;
  final int? pageCount;

  const ChapterEntity({
    required this.id,
    required this.mediaId,
    required this.title,
    required this.number,
    this.releaseDate,
    this.pageCount,
  });

  @override
  List<Object?> get props => [
    id,
    mediaId,
    title,
    number,
    releaseDate,
    pageCount,
  ];
}
