import 'package:equatable/equatable.dart';

enum TrackingService { anilist, mal, simkl }

class UserEntity extends Equatable {
  final String id;
  final String username;
  final String? avatarUrl;
  final TrackingService service;

  const UserEntity({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.service,
  });

  @override
  List<Object?> get props => [id, username, avatarUrl, service];
}
