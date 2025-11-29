import 'dart:convert';

import '../../enums/tracking_service.dart';

/// Represents an OAuth authentication token for a tracking service.
///
/// This entity stores all token-related data including access token,
/// optional refresh token, and expiration information.
class AuthToken {
  /// The access token used for API requests
  final String accessToken;

  /// The refresh token used to obtain new access tokens (MAL only)
  final String? refreshToken;

  /// When the access token expires (null means never expires)
  final DateTime? expiresAt;

  /// The token type (usually "Bearer")
  final String tokenType;

  /// The tracking service this token belongs to
  final TrackingService service;

  const AuthToken({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.tokenType = 'Bearer',
    required this.service,
  });

  /// Check if the token is expired
  ///
  /// Returns false if expiresAt is null (token never expires).
  /// Uses a 5-minute buffer to refresh before actual expiration.
  bool get isExpired {
    if (expiresAt == null) return false;
    // Add 5 minute buffer before actual expiration
    final bufferTime = expiresAt!.subtract(const Duration(minutes: 5));
    return DateTime.now().isAfter(bufferTime);
  }

  /// Check if the token can be refreshed
  bool get canRefresh => refreshToken != null && refreshToken!.isNotEmpty;

  /// Check if the token is valid (not expired or can be refreshed)
  bool get isValid => !isExpired || canRefresh;

  /// Create a copy with updated fields
  AuthToken copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? tokenType,
    TrackingService? service,
  }) {
    return AuthToken(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      tokenType: tokenType ?? this.tokenType,
      service: service ?? this.service,
    );
  }

  /// Convert to JSON map for storage
  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt?.toIso8601String(),
      'tokenType': tokenType,
      'service': service.name,
    };
  }

  /// Create from JSON map
  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      service: TrackingService.values.firstWhere(
        (s) => s.name == json['service'],
        orElse: () => TrackingService.mal,
      ),
    );
  }

  /// Encode to JSON string for secure storage
  String encode() => jsonEncode(toJson());

  /// Decode from JSON string
  factory AuthToken.decode(String encoded) {
    return AuthToken.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
  }

  @override
  String toString() {
    return 'AuthToken(service: ${service.name}, '
        'hasRefresh: ${refreshToken != null}, '
        'expiresAt: $expiresAt, '
        'isExpired: $isExpired)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthToken &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.expiresAt == expiresAt &&
        other.tokenType == tokenType &&
        other.service == service;
  }

  @override
  int get hashCode {
    return Object.hash(
      accessToken,
      refreshToken,
      expiresAt,
      tokenType,
      service,
    );
  }
}
