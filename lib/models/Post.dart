// ignore_for_file: file_names

import 'User.dart';

class PostModel {
  const PostModel({
    required this.id,
    required this.user,
    required this.caption,
    required this.media,
    required this.mediaType,
    required this.likesCount,
    required this.dislikesCount,
    required this.hasLiked,
    required this.hasDisliked,
    required this.createdAt,
  });

  final String id;
  final AppUser user;
  final String caption;
  final String media;
  final String mediaType;
  final int likesCount;
  final int dislikesCount;
  final bool hasLiked;
  final bool hasDisliked;
  final DateTime createdAt;

  bool get isVideo => mediaType == 'video';

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['userId'];
    return PostModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
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
      caption: (json['caption'] ?? '').toString(),
      media: (json['media'] ?? json['image'] ?? '').toString(),
      mediaType: (json['mediaType'] ?? 'image').toString(),
      likesCount: _readInt(json['likesCount'], json['likes']),
      dislikesCount: _readInt(json['dislikesCount'], json['dislikes']),
      hasLiked: json['hasLiked'] == true,
      hasDisliked: json['hasDisliked'] == true,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  PostModel copyWith({
    AppUser? user,
    String? media,
    String? mediaType,
    int? likesCount,
    int? dislikesCount,
    bool? hasLiked,
    bool? hasDisliked,
  }) {
    return PostModel(
      id: id,
      user: user ?? this.user,
      caption: caption,
      media: media ?? this.media,
      mediaType: mediaType ?? this.mediaType,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      hasLiked: hasLiked ?? this.hasLiked,
      hasDisliked: hasDisliked ?? this.hasDisliked,
      createdAt: createdAt,
    );
  }

  static int _readInt(dynamic value, dynamic fallbackList) {
    if (value is int) {
      return value;
    }
    if (fallbackList is List) {
      return fallbackList.length;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
