// ignore_for_file: file_names

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.bio,
    required this.profilePic,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.isFollowing,
    required this.hasRequested,
  });

  final String id;
  final String username;
  final String email;
  final String bio;
  final String profilePic;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool isFollowing;
  final bool hasRequested;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      bio: (json['bio'] ?? '').toString(),
      profilePic: (json['profilePic'] ?? '').toString(),
      followersCount: _readCount(json, 'followersCount', 'followers'),
      followingCount: _readCount(json, 'followingCount', 'following'),
      postsCount: _readInt(json['postsCount']),
      isFollowing: json['isFollowing'] == true,
      hasRequested: json['hasRequested'] == true,
    );
  }

  AppUser copyWith({
    String? profilePic,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    bool? isFollowing,
    bool? hasRequested,
  }) {
    return AppUser(
      id: id,
      username: username,
      email: email,
      bio: bio,
      profilePic: profilePic ?? this.profilePic,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      isFollowing: isFollowing ?? this.isFollowing,
      hasRequested: hasRequested ?? this.hasRequested,
    );
  }

  static int _readCount(
    Map<String, dynamic> json,
    String countKey,
    String listKey,
  ) {
    if (json[countKey] != null) {
      return _readInt(json[countKey]);
    }

    final value = json[listKey];
    if (value is List) {
      return value.length;
    }

    return 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
