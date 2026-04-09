import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/User.dart';

class FollowRequestWidget extends StatelessWidget {
  const FollowRequestWidget({
    super.key,
    required this.user,
    required this.onAccept,
    required this.onReject,
  });

  final AppUser user;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8D8CC)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: user.profilePic.isNotEmpty
                ? CachedNetworkImageProvider(user.profilePic)
                : null,
            child: user.profilePic.isEmpty
                ? Text(user.username.characters.first.toUpperCase())
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  user.bio.isEmpty ? 'Wants to follow you' : user.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onAccept,
            icon: const Icon(Icons.check),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onReject,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF7EDE5),
            ),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
