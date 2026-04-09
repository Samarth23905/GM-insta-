// ignore_for_file: file_names

import 'User.dart';

class MessageModel {
  const MessageModel({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.messageText,
    required this.sentAt,
  });

  final String id;
  final AppUser sender;
  final AppUser receiver;
  final String messageText;
  final DateTime sentAt;

  bool isMine(String currentUserId) => sender.id == currentUserId;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final senderJson = json['senderId'];
    final receiverJson = json['receiverId'];

    return MessageModel(
      id: (json['_id'] ?? '').toString(),
      sender: senderJson is Map<String, dynamic>
          ? AppUser.fromJson(senderJson)
          : AppUser(
              id: senderJson?.toString() ?? '',
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
      receiver: receiverJson is Map<String, dynamic>
          ? AppUser.fromJson(receiverJson)
          : AppUser(
              id: receiverJson?.toString() ?? '',
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
      messageText: (json['messageText'] ?? '').toString(),
      sentAt: DateTime.tryParse((json['sentAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  MessageModel copyWith({
    AppUser? sender,
    AppUser? receiver,
  }) {
    return MessageModel(
      id: id,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      messageText: messageText,
      sentAt: sentAt,
    );
  }
}
