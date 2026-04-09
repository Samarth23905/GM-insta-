import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/Story.dart';

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    this.initialGroupIndex = 0,
  });

  final List<StoryGroup> groups;
  final int initialGroupIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late final List<StoryModel> _flattenedStories;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _flattenedStories = widget.groups.expand((group) => group.stories).toList();
    _controller = PageController(
      initialPage: _startingPageForGroup(widget.initialGroupIndex),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _startingPageForGroup(int groupIndex) {
    var storyIndex = 0;
    for (var index = 0; index < groupIndex; index++) {
      storyIndex += widget.groups[index].stories.length;
    }
    return storyIndex;
  }

  @override
  Widget build(BuildContext context) {
    if (_flattenedStories.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No active stories.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        itemCount: _flattenedStories.length,
        itemBuilder: (context, index) {
          final story = _flattenedStories[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              story.mediaType == 'video'
                  ? Container(
                      color: const Color(0xFF151515),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 72,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Video story preview',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            story.media,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: story.media,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF2A2A2A),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: story.user.profilePic.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    story.user.profilePic,
                                  )
                                : null,
                            child: story.user.profilePic.isEmpty
                                ? Text(
                                    story.user.username.characters.first
                                        .toUpperCase(),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              story.user.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (index + 1) / _flattenedStories.length,
                        color: const Color(0xFFF6C65B),
                        backgroundColor: Colors.white24,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
