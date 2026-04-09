import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/Comment.dart';
import '../providers/app_providers.dart';

class CommentPopup extends ConsumerStatefulWidget {
  const CommentPopup({
    super.key,
    required this.postId,
    this.onUserTap,
  });

  final String postId;
  final ValueChanged<String>? onUserTap;

  @override
  ConsumerState<CommentPopup> createState() => _CommentPopupState();
}

class _CommentPopupState extends ConsumerState<CommentPopup> {
  final TextEditingController _commentController = TextEditingController();
  final List<CommentModel> _comments = <CommentModel>[];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _editingCommentId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadComments);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments =
          await ref.read(apiServiceProvider).getComments(widget.postId);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments
          ..clear()
          ..addAll(comments);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiServiceProvider);
      if (_editingCommentId != null) {
        final updatedComment = await api.updateComment(
          commentId: _editingCommentId!,
          commentText: text,
        );
        if (!mounted) {
          return;
        }
        final commentIndex =
            _comments.indexWhere((comment) => comment.id == _editingCommentId);
        if (commentIndex >= 0) {
          setState(() {
            _comments[commentIndex] = updatedComment;
            _commentController.clear();
            _editingCommentId = null;
          });
        }
        return;
      }

      final comment = await api.addComment(widget.postId, text);
      if (!mounted) {
        return;
      }
      setState(() {
        _comments.add(comment);
        _commentController.clear();
        _editingCommentId = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId =
        ref.watch(sessionControllerProvider).user?.id ?? '';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              Text(
                'Comments',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? Center(
                            child: Text(
                              'No comments yet. Start the conversation.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final comment = _comments[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundImage: comment.user.profilePic.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          comment.user.profilePic,
                                        )
                                      : null,
                                  child: comment.user.profilePic.isEmpty
                                      ? Text(
                                          comment.user.username.characters.first
                                              .toUpperCase(),
                                        )
                                      : null,
                                ),
                                title: GestureDetector(
                                  onTap: widget.onUserTap == null
                                      ? null
                                      : () => widget.onUserTap!(comment.user.id),
                                  child: Text(
                                    comment.user.username,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                subtitle: Text(comment.commentText),
                                trailing: comment.user.id == currentUserId
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _editingCommentId = comment.id;
                                            _commentController.text =
                                                comment.commentText;
                                          });
                                        },
                                        icon: const Icon(Icons.edit_outlined),
                                      )
                                    : null,
                              );
                            },
                          ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submitComment,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_editingCommentId == null ? 'Send' : 'Update'),
                  ),
                ],
              ),
              if (_editingCommentId != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _editingCommentId = null;
                        _commentController.clear();
                      });
                    },
                    child: const Text('Cancel edit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
