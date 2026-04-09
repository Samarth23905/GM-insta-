import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/Post.dart';

class PostDetailSheet extends StatelessWidget {
  const PostDetailSheet({
    super.key,
    required this.post,
    required this.onOpenComments,
    this.onDelete,
    this.isDeleting = false,
  });

  final PostModel post;
  final VoidCallback onOpenComments;
  final VoidCallback? onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Wrap(
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4C2B6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 320,
                width: double.infinity,
                child: post.isVideo
                    ? Container(
                        color: const Color(0xFF2C231E),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 58,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Reel post',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: post.media,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFF1DED1),
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              post.caption.isEmpty ? 'No caption added.' : post.caption,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.favorite, size: 18),
                const SizedBox(width: 6),
                Text('${post.likesCount} likes'),
                const SizedBox(width: 14),
                const Icon(Icons.thumb_down_outlined, size: 18),
                const SizedBox(width: 6),
                Text('${post.dislikesCount} dislikes'),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenComments,
                icon: const Icon(Icons.mode_comment_outlined),
                label: const Text('View and Edit Comments'),
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isDeleting ? null : onDelete,
                  icon: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(isDeleting ? 'Deleting...' : 'Delete Post'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD9515C),
                    side: const BorderSide(color: Color(0xFFD9515C)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
