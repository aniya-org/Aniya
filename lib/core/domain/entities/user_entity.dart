import 'package:equatable/equatable.dart';

import '../../enums/tracking_service.dart';

// Re-export TrackingService for backward compatibility
export '../../enums/tracking_service.dart' show TrackingService;

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
