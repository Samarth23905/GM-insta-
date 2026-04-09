import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/Post.dart';
import '../providers/app_providers.dart';
import '../widgets/comment_popup.dart';
import '../widgets/follow_request_widget.dart';
import '../widgets/post_card.dart';
import '../widgets/post_detail_sheet.dart';
import '../widgets/story_widget.dart';
import 'profile.dart';
import 'story.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.onSearchRequested});

  final VoidCallback onSearchRequested;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingStory = false;

  Future<void> _refreshAll() async {
    ref.read(homeRefreshProvider.notifier).state++;
    ref.read(mutualFollowersRefreshProvider.notifier).state++;
    final currentUserId = ref.read(sessionControllerProvider).user?.id;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      ref.read(profileRefreshProvider(currentUserId).notifier).state++;
    }
    await ref.read(sessionControllerProvider.notifier).refreshUser();
  }

  Future<void> _uploadStory(bool isVideo) async {
    if (_isUploadingStory) {
      return;
    }

    final file = isVideo
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery);

    if (file == null) {
      return;
    }

    setState(() => _isUploadingStory = true);
    try {
      await ref.read(apiServiceProvider).addStory(file);
      await _refreshAll();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Story uploaded.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isUploadingStory = false);
      }
    }
  }

  Future<void> _openStoryPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Upload image story'),
                onTap: () {
                  Navigator.of(context).pop();
                  _uploadStory(false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: const Text('Upload video story'),
                onTap: () {
                  Navigator.of(context).pop();
                  _uploadStory(true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleFollowRequest(String requesterId, bool accept) async {
    try {
      await ref
          .read(apiServiceProvider)
          .respondToFollowRequest(requesterId: requesterId, accept: accept);
      final currentUserId = ref.read(sessionControllerProvider).user?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        ref.read(profileRefreshProvider(currentUserId).notifier).state++;
      }
      ref.read(profileRefreshProvider(requesterId).notifier).state++;
      await _refreshAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  Future<void> _openPostDetails(PostModel post) async {
    final currentUserId = ref.read(sessionControllerProvider).user?.id;
    final isOwner = currentUserId == post.user.id;
    var isDeleting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFAF6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return PostDetailSheet(
              post: post,
              isDeleting: isDeleting,
              onOpenComments: () async {
                Navigator.of(sheetContext).pop();
                await showModalBottomSheet<void>(
                  context: this.context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFFFFFAF6),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (_) =>
                      CommentPopup(postId: post.id, onUserTap: _openProfile),
                );
              },
              onDelete: !isOwner
                  ? null
                  : () async {
                      setModalState(() => isDeleting = true);
                      try {
                        await ref.read(apiServiceProvider).deletePost(post.id);
                        ref.read(homeRefreshProvider.notifier).state++;
                        ref.read(reelsRefreshProvider.notifier).state++;
                        if (!mounted) {
                          return;
                        }
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Post deleted.')),
                        );
                      } catch (error) {
                        if (!mounted) {
                          return;
                        }
                        setModalState(() => isDeleting = false);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ref.watch(homeBundleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: bundle.when(
        data: (data) {
          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    GestureDetector(
                      onTap: widget.onSearchRequested,
                      child: AbsorbPointer(
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search creators, friends, stories...',
                            suffixIcon: IconButton(
                              onPressed: widget.onSearchRequested,
                              icon: const Icon(Icons.arrow_forward),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 130,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: InkWell(
                              onTap: _isUploadingStory
                                  ? null
                                  : _openStoryPicker,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 86,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCE7D5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: const Color(0xFFB86834),
                                      child: _isUploadingStory
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.add_a_photo_outlined,
                                              color: Colors.white,
                                            ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Add Story',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          ...data.stories.asMap().entries.map(
                            (entry) => StoryWidget(
                              group: entry.value,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => StoryViewerScreen(
                                      groups: data.stories,
                                      initialGroupIndex: entry.key,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (data.followRequests.isNotEmpty) ...[
                      Text(
                        'Incoming requests',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      ...data.followRequests.map(
                        (user) => FollowRequestWidget(
                          user: user,
                          onAccept: () => _handleFollowRequest(user.id, true),
                          onReject: () => _handleFollowRequest(user.id, false),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Latest feed',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    if (data.posts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Your feed is empty. Start by adding a post or following people.',
                        ),
                      )
                    else
                      ...data.posts.map(
                        (post) => PostCard(
                          post: post,
                          onRefreshRequested: _refreshAll,
                          onUserTap: _openProfile,
                          onPostTap: () => _openPostDetails(post),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _refreshAll, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
