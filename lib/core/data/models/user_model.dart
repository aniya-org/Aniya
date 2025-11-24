import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.username,
    super.avatarUrl,
    required super.service,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      service: TrackingService.values.firstWhere(
        (e) => e.name == json['service'],
        orElse: () => TrackingService.anilist,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatarUrl': avatarUrl,
      'service': service.name,
    };
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      username: username,
      avatarUrl: avatarUrl,
      service: service,
    );
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    TrackingService? service,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      service: service ?? this.service,
    );
  }
}
