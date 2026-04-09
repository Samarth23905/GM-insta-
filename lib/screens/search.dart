import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/User.dart';
import '../providers/app_providers.dart';
import 'profile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  List<AppUser> _results = const <AppUser>[];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (value.trim().isEmpty) {
        if (mounted) {
          setState(() => _results = const <AppUser>[]);
        }
        return;
      }

      setState(() => _isLoading = true);
      try {
        final users = await ref.read(apiServiceProvider).searchUsers(value);
        if (!mounted) {
          return;
        }
        setState(() => _results = users);
      } catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search users by username',
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const LinearProgressIndicator(minHeight: 3)
            else if (_results.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Start typing to discover people on GMinsta.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      tileColor: Colors.white,
                      leading: CircleAvatar(
                        backgroundImage: user.profilePic.isNotEmpty
                            ? CachedNetworkImageProvider(user.profilePic)
                            : null,
                        child: user.profilePic.isEmpty
                            ? Text(user.username.characters.first.toUpperCase())
                            : null,
                      ),
                      title: Text(user.username),
                      subtitle: Text(
                        user.bio.isEmpty ? 'No bio yet' : user.bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '${user.followersCount} followers',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileScreen(userId: user.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
