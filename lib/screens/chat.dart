import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/Message.dart';
import '../models/User.dart';
import '../providers/app_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(mutualFollowersRefreshProvider.notifier).state++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mutuals = ref.watch(mutualFollowersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: mutuals.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chat unlocks when both people follow each other.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(mutualFollowersRefreshProvider.notifier).state++;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage: user.profilePic.isNotEmpty
                        ? CachedNetworkImageProvider(user.profilePic)
                        : null,
                    child: user.profilePic.isEmpty
                        ? Text(user.username.characters.first.toUpperCase())
                        : null,
                  ),
                  title: Text(user.username),
                  subtitle: Text(
                    user.bio.isEmpty ? 'Mutual follower' : user.bio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ConversationScreen(partner: user),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.partner,
  });

  final AppUser partner;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _knownMessageIds = <String>{};
  final List<MessageModel> _messages = <MessageModel>[];
  StreamSubscription<MessageModel>? _subscription;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initializeConversation);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeConversation() async {
    try {
      final history =
          await ref.read(apiServiceProvider).getChatHistory(widget.partner.id);

      _messages
        ..clear()
        ..addAll(history);
      _knownMessageIds
        ..clear()
        ..addAll(history.map((message) => message.id));

      _subscription = ref.read(apiServiceProvider).messagesStream.listen((message) {
        final currentUserId = ref.read(sessionControllerProvider).user?.id ?? '';
        final isRelevant =
            (message.sender.id == widget.partner.id &&
                    message.receiver.id == currentUserId) ||
                (message.sender.id == currentUserId &&
                    message.receiver.id == widget.partner.id);

        if (isRelevant) {
          _appendMessage(message);
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _scrollToBottom();
    }
  }

  void _appendMessage(MessageModel message) {
    if (_knownMessageIds.contains(message.id)) {
      return;
    }

    _knownMessageIds.add(message.id);
    if (mounted) {
      setState(() => _messages.add(message));
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final message = await ref.read(apiServiceProvider).sendMessage(
            receiverId: widget.partner.id,
            messageText: text,
          );
      _messageController.clear();
      _appendMessage(message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(sessionControllerProvider).user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.partner.profilePic.isNotEmpty
                  ? CachedNetworkImageProvider(widget.partner.profilePic)
                  : null,
              child: widget.partner.profilePic.isEmpty
                  ? Text(widget.partner.username.characters.first.toUpperCase())
                  : null,
            ),
            const SizedBox(width: 12),
            Text(widget.partner.username),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(18),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine = message.isMine(currentUserId);

                      return Align(
                        alignment:
                            isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 280),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isMine
                                ? const Color(0xFFB86834)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            message.messageText,
                            style: TextStyle(
                              color: isMine ? Colors.white : const Color(0xFF46362C),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Send a message',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSending ? null : _sendMessage,
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
