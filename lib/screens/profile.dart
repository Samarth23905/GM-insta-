import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/Post.dart';
import '../providers/app_providers.dart';
import '../widgets/comment_popup.dart';
import '../widgets/post_detail_sheet.dart';
import '../widgets/post_grid_tile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    this.userId,
  });

  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isSendingRequest = false;
  bool _isUpdatingProfilePicture = false;

  Future<void> _sendFollowRequest(String userId) async {
    if (_isSendingRequest) {
      return;
    }

    setState(() => _isSendingRequest = true);
    try {
      await ref.read(apiServiceProvider).sendFollowRequest(userId);
      ref.read(profileRefreshProvider(userId).notifier).state++;
      ref.read(homeRefreshProvider.notifier).state++;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow request sent.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingRequest = false);
      }
    }
  }

  Future<void> _updateProfilePicture(String userId) async {
    if (_isUpdatingProfilePicture) {
      return;
    }

    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return;
    }

    setState(() => _isUpdatingProfilePicture = true);
    try {
      await ref.read(apiServiceProvider).updateProfilePicture(file);
      await ref.read(sessionControllerProvider.notifier).refreshUser();
      ref.read(profileRefreshProvider(userId).notifier).state++;
      ref.read(homeRefreshProvider.notifier).state++;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingProfilePicture = false);
      }
    }
  }

  Future<void> _openPostDetails(
    String resolvedUserId,
    PostModel post,
    bool isOwner,
  ) async {
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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => CommentPopup(postId: post.id),
                );
              },
              onDelete: !isOwner
                  ? null
                  : () async {
                      setModalState(() => isDeleting = true);
                      try {
                        await ref.read(apiServiceProvider).deletePost(post.id);
                        ref.read(profileRefreshProvider(resolvedUserId).notifier)
                            .state++;
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
    final session = ref.watch(sessionControllerProvider);
    final resolvedUserId = widget.userId ?? session.user?.id;

    if (session.isLoading || resolvedUserId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bundle = ref.watch(profileBundleProvider(resolvedUserId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (widget.userId == null)
            IconButton(
              onPressed: () async {
                await ref.read(sessionControllerProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: bundle.when(
        data: (data) {
          final relationship = data.relationship;
          final isSelf = relationship['isSelf'] == true;
          final requestSent = relationship['requestSent'] == true;
          final isFollowing = relationship['isFollowing'] == true;

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(profileRefreshProvider(resolvedUserId).notifier).state++;
              await ref.read(sessionControllerProvider.notifier).refreshUser();
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 54,
                              backgroundImage: data.user.profilePic.isNotEmpty
                                  ? CachedNetworkImageProvider(data.user.profilePic)
                                  : null,
                              child: data.user.profilePic.isEmpty
                                  ? Text(
                                      data.user.username.characters.first
                                          .toUpperCase(),
                                      style: const TextStyle(fontSize: 28),
                                    )
                                  : null,
                            ),
                            if (isSelf)
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Material(
                                  color: const Color(0xFFB86834),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _isUpdatingProfilePicture
                                        ? null
                                        : () => _updateProfilePicture(
                                              resolvedUserId,
                                            ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: _isUpdatingProfilePicture
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.camera_alt_outlined,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          data.user.username,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data.user.bio.isEmpty
                              ? 'No bio written yet.'
                              : data.user.bio,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatTile(
                              label: 'Posts',
                              value: data.posts.length.toString(),
                            ),
                            _StatTile(
                              label: 'Followers',
                              value: data.user.followersCount.toString(),
                            ),
                            _StatTile(
                              label: 'Following',
                              value: data.user.followingCount.toString(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (!isSelf)
                          FilledButton(
                            onPressed:
                                isFollowing || requestSent || _isSendingRequest
                                    ? null
                                    : () => _sendFollowRequest(resolvedUserId),
                            child: _isSendingRequest
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isFollowing
                                        ? 'Following'
                                        : requestSent
                                            ? 'Request Sent'
                                            : 'Follow',
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: data.posts.isEmpty
                      ? SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Text(
                              'No posts yet. This grid will fill up when new posts arrive.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final post = data.posts[index];
                              return GestureDetector(
                                onTap: () => _openPostDetails(
                                  resolvedUserId,
                                  post,
                                  isSelf,
                                ),
                                child: PostGridTile(post: post),
                              );
                            },
                            childCount: data.posts.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                        ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}
