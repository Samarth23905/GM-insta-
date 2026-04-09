import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/Story.dart';

class StoryWidget extends StatelessWidget {
  const StoryWidget({
    super.key,
    required this.group,
    required this.onTap,
  });

  final StoryGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFA6E5A), Color(0xFFF6C65B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 27,
                    backgroundImage: group.user.profilePic.isNotEmpty
                        ? CachedNetworkImageProvider(group.user.profilePic)
                        : null,
                    child: group.user.profilePic.isEmpty
                        ? Text(group.user.username.characters.first.toUpperCase())
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                group.user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
