import 'dart:typed_data';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../providers/app_providers.dart';

class AddPostScreen extends ConsumerStatefulWidget {
  const AddPostScreen({
    super.key,
    required this.onPostCreated,
  });

  final VoidCallback onPostCreated;

  @override
  ConsumerState<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends ConsumerState<AddPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;
  VideoPlayerController? _videoController;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  bool get _isVideoSelection =>
      _pickedFile != null && _isVideoFile(_pickedFile!);

  bool _isVideoFile(XFile file) {
    final lowerName = file.name.toLowerCase();
    return lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.mov') ||
        lowerName.endsWith('.m4v') ||
        lowerName.endsWith('.webm') ||
        lowerName.endsWith('.avi');
  }

  Future<void> _setPickedFile(XFile file) async {
    await _videoController?.dispose();
    _videoController = null;

    if (_isVideoFile(file)) {
      final controller = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(file.path))
          : VideoPlayerController.file(io.File(file.path));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      _videoController = controller;
    }

    if (mounted) {
      setState(() => _pickedFile = file);
    }
  }

  Future<void> _pickMedia(bool isVideo) async {
    final file = isVideo
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      await _setPickedFile(file);
    }
  }

  Future<void> _submit() async {
    if (_pickedFile == null || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
          await ref.read(apiServiceProvider).createPost(
            file: _pickedFile!,
            caption: _captionController.text.trim(),
          );
      ref.read(homeRefreshProvider.notifier).state++;
      ref.read(reelsRefreshProvider.notifier).state++;
      if (!mounted) {
        return;
      }
      _captionController.clear();
      await _videoController?.dispose();
      _videoController = null;
      setState(() => _pickedFile = null);
      widget.onPostCreated();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published successfully.')),
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          InkWell(
            onTap: () => _pickMedia(false),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFFF4E5D9),
              ),
              child: _pickedFile == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.perm_media_outlined, size: 48),
                        SizedBox(height: 12),
                        Text('Tap to choose a photo'),
                      ],
                    )
                  : _isVideoSelection && _videoController != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              VideoPlayer(_videoController!),
                              const Align(
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white,
                                  size: 56,
                                ),
                              ),
                            ],
                          ),
                        )
                      : FutureBuilder<Uint8List>(
                      future: _pickedFile!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                            ),
                          );
                        }

                        return Center(
                          child: Text(
                            _pickedFile!.name,
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickMedia(false),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickMedia(true),
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Video / Reel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _captionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Caption',
              hintText: 'Tell the story behind your post',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: const Icon(Icons.send_outlined),
            label: _isSubmitting
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Text('Publish Post'),
          ),
        ],
      ),
    );
  }
}
