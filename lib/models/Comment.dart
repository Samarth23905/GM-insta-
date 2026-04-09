// ignore_for_file: file_names

import 'User.dart';

class CommentModel {
  const CommentModel({
    required this.id,
    required this.postId,
    required this.user,
    required this.commentText,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final AppUser user;
  final String commentText;
  final DateTime createdAt;

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['userId'];
    return CommentModel(
      id: (json['_id'] ?? '').toString(),
      postId: (json['postId'] ?? '').toString(),
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
      commentText: (json['commentText'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  CommentModel copyWith({AppUser? user}) {
    return CommentModel(
      id: id,
      postId: postId,
      user: user ?? this.user,
      commentText: commentText,
      createdAt: createdAt,
    );
  }

  CommentModel copyWithText({
    String? commentText,
    AppUser? user,
  }) {
    return CommentModel(
      id: id,
      postId: postId,
      user: user ?? this.user,
      commentText: commentText ?? this.commentText,
      createdAt: createdAt,
    );
  }
}
