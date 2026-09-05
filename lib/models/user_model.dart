
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool isGuest;
  final DateTime joinedAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.isGuest = false,
    required this.joinedAt,
    this.updatedAt,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    bool? isGuest,
    DateTime? joinedAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGuest: isGuest ?? this.isGuest,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserModel.fromSupabase({
    required String id,
    required String email,
    required Map<String, dynamic>? profileData,
    DateTime? createdAt,
  }) {
    final displayName = profileData?['display_name'] as String?;
    final joined = profileData?['created_at'] != null
        ? DateTime.tryParse(profileData!['created_at'] as String) ?? (createdAt ?? DateTime.now())
        : (createdAt ?? DateTime.now());
    final updated = profileData?['updated_at'] != null
        ? DateTime.tryParse(profileData!['updated_at'] as String)
        : null;

    return UserModel(
      id: id,
      name: (displayName != null && displayName.isNotEmpty)
          ? displayName
          : email.split('@').first,
      email: email,
      isGuest: false,
      joinedAt: joined,
      updatedAt: updated,
    );
  }

  factory UserModel.guest() {
    return UserModel(
      id: 'guest_user',
      name: 'Guest Traveler',
      email: 'guest@happyway.my',
      isGuest: true,
      joinedAt: DateTime.now(),
    );
  }
}
