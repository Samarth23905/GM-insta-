// ignore_for_file: file_names

import 'User.dart';

class StoryModel {
  const StoryModel({
    required this.id,
    required this.user,
    required this.media,
    required this.mediaType,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final AppUser user;
  final String media;
  final String mediaType;
  final DateTime createdAt;
  final DateTime expiresAt;

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['userId'] ?? json['user'];
    return StoryModel(
      id: (json['_id'] ?? '').toString(),
      user: userJson is Map<String, dynamic>
          ? AppUser.fromJson(userJson)
          : AppUser(
              id: userJson?.toString() ?? '',
              username: 'Unknown',
              email: '',
              bio: '',
              profilePic: '',
              followersCount: 0,
              followingCount: 0,
              postsCount: 0,
              isFollowing: false,
              hasRequested: false,
            ),
      media: (json['media'] ?? '').toString(),
      mediaType: (json['mediaType'] ?? 'image').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      expiresAt: DateTime.tryParse((json['expiresAt'] ?? '').toString()) ??
          DateTime.now().add(const Duration(hours: 24)),
    );
  }

  StoryModel copyWith({
    AppUser? user,
    String? media,
  }) {
    return StoryModel(
      id: id,
      user: user ?? this.user,
      media: media ?? this.media,
      mediaType: mediaType,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}

class StoryGroup {
  const StoryGroup({
    required this.user,
    required this.stories,
  });

  final AppUser user;
  final List<StoryModel> stories;

  factory StoryGroup.fromJson(Map<String, dynamic> json) {
    final user = AppUser.fromJson(json['user'] as Map<String, dynamic>);
    final storiesJson = (json['stories'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return StoryGroup(
      user: user,
      stories: storiesJson
          .map(
            (storyJson) => StoryModel.fromJson({
              ...storyJson,
              'user': json['user'],
            }),
          )
          .toList(),
    );
  }
}
