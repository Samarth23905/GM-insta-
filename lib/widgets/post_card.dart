import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/Post.dart';
import '../providers/app_providers.dart';
import 'comment_popup.dart';

class PostCard extends ConsumerStatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onRefreshRequested,
    this.onUserTap,
    this.onPostTap,
  });

  final PostModel post;
  final VoidCallback onRefreshRequested;
  final ValueChanged<String>? onUserTap;
  final VoidCallback? onPostTap;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _isUpdatingReaction = false;
  VideoPlayerController? _videoController;
  late PostModel _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _configureMediaController();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _post = widget.post;
    }
    if (oldWidget.post.media != widget.post.media ||
        oldWidget.post.mediaType != widget.post.mediaType) {
      _configureMediaController();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _configureMediaController() async {
    await _videoController?.dispose();
    _videoController = null;

    if (!_post.isVideo) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(_post.media));
    await controller.initialize();
    await controller.setLooping(true);
    await controller.setVolume(0);
    await controller.play();

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() => _videoController = controller);
  }

  Future<void> _updateReaction(String reaction) async {
    if (_isUpdatingReaction) {
      return;
    }

    final previousPost = _post;
    final optimisticPost = _buildOptimisticPost(reaction, previousPost);

    setState(() {
      _post = optimisticPost;
      _isUpdatingReaction = true;
    });
    try {
      final updatedPost = await ref
          .read(apiServiceProvider)
          .reactToPost(_post.id, reaction);
      if (!mounted) {
        return;
      }
      setState(() => _post = updatedPost);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _post = previousPost);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingReaction = false);
      }
    }
  }

  Future<void> _openComments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFAF6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          CommentPopup(postId: widget.post.id, onUserTap: widget.onUserTap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14A66A44),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: widget.onUserTap == null
                ? null
                : () => widget.onUserTap!(_post.user.id),
            leading: CircleAvatar(
              backgroundImage: _post.user.profilePic.isNotEmpty
                  ? CachedNetworkImageProvider(_post.user.profilePic)
                  : null,
              child: _post.user.profilePic.isEmpty
                  ? Text(_post.user.username.characters.first.toUpperCase())
                  : null,
            ),
            title: Text(_post.user.username, style: theme.textTheme.titleSmall),
            subtitle: Text(_formatTime(_post.createdAt)),
          ),
          InkWell(
            onTap: widget.onPostTap,
            child: AspectRatio(
              aspectRatio: _post.isVideo
                  ? (_videoController?.value.isInitialized == true
                        ? _videoController!.value.aspectRatio
                        : 9 / 16)
                  : 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                child: _post.isVideo
                    ? _buildVideoPlayer()
                    : CachedNetworkImage(
                        imageUrl: _post.media,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFF0E0D4),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_post.isVideo)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE7D5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Reel'),
                  ),
                Text(_post.caption, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              children: [
                IconButton(
                  onPressed: _isUpdatingReaction
                      ? null
                      : () =>
                            _updateReaction(_post.hasLiked ? 'clear' : 'like'),
                  icon: Icon(
                    _post.hasLiked ? Icons.favorite : Icons.favorite_border,
                    color: _post.hasLiked
                        ? const Color(0xFFD9515C)
                        : const Color(0xFF51443A),
                  ),
                ),
                Text('${_post.likesCount}'),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _isUpdatingReaction
                      ? null
                      : () => _updateReaction(
                          _post.hasDisliked ? 'clear' : 'dislike',
                        ),
                  icon: Icon(
                    _post.hasDisliked
                        ? Icons.thumb_down
                        : Icons.thumb_down_outlined,
                  ),
                ),
                Text('${_post.dislikesCount}'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _openComments,
                  icon: const Icon(Icons.mode_comment_outlined),
                  label: const Text('Comments'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }

  PostModel _buildOptimisticPost(String reaction, PostModel post) {
    final hadLiked = post.hasLiked;
    final hadDisliked = post.hasDisliked;
    var likesCount = post.likesCount;
    var dislikesCount = post.dislikesCount;
    var hasLiked = false;
    var hasDisliked = false;

    if (reaction == 'clear') {
      likesCount -= hadLiked ? 1 : 0;
      dislikesCount -= hadDisliked ? 1 : 0;
    } else if (reaction == 'like') {
      hasLiked = true;
      likesCount += hadLiked ? 0 : 1;
      dislikesCount -= hadDisliked ? 1 : 0;
    } else if (reaction == 'dislike') {
      hasDisliked = true;
      dislikesCount += hadDisliked ? 0 : 1;
      likesCount -= hadLiked ? 1 : 0;
    }

    return post.copyWith(
      likesCount: likesCount < 0 ? 0 : likesCount,
      dislikesCount: dislikesCount < 0 ? 0 : dislikesCount,
      hasLiked: hasLiked,
      hasDisliked: hasDisliked,
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController?.value.isInitialized != true) {
      return Container(
        color: const Color(0xFF221A15),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
        const Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
      ],
    );
  }
}
