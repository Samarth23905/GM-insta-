import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/Post.dart';
import '../models/Story.dart';
import '../models/User.dart';
import '../services/api_service.dart';

class SessionState {
  const SessionState({
    required this.isLoading,
    required this.user,
    required this.token,
    required this.errorMessage,
  });

  final bool isLoading;
  final AppUser? user;
  final String? token;
  final String? errorMessage;

  bool get isAuthenticated =>
      user != null && token != null && token!.isNotEmpty;

  factory SessionState.initial() => const SessionState(
        isLoading: true,
        user: null,
        token: null,
        errorMessage: null,
      );

  SessionState copyWith({
    bool? isLoading,
    AppUser? user,
    String? token,
    String? errorMessage,
    bool clearUser = false,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return SessionState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      token: clearToken ? null : (token ?? this.token),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class HomeBundle {
  const HomeBundle({
    required this.posts,
    required this.stories,
    required this.followRequests,
  });

  final List<PostModel> posts;
  final List<StoryGroup> stories;
  final List<AppUser> followRequests;
}

class ProfileBundle {
  const ProfileBundle({
    required this.user,
    required this.relationship,
    required this.posts,
  });

  final AppUser user;
  final Map<String, dynamic> relationship;
  final List<PostModel> posts;
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._api) : super(SessionState.initial()) {
    bootstrap();
  }

  final ApiService _api;

  Future<void> bootstrap() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final token = await _api.getSavedToken();

    if (token == null || token.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        clearToken: true,
        clearUser: true,
      );
      return;
    }

    try {
      _api.connectSocket(token);
      final user = await _api.getCurrentUser();
      state = state.copyWith(
        isLoading: false,
        token: token,
        user: user,
        clearError: true,
      );
    } catch (error) {
      await _api.clearSession();
      state = state.copyWith(
        isLoading: false,
        clearToken: true,
        clearUser: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<String?> login({
    required String identifier,
    required String password,
  }) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      final result = await _api.login(
        identifier: identifier,
        password: password,
      );
      state = state.copyWith(
        isLoading: false,
        user: result.user,
        token: result.token,
      );
      return null;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      return error.toString();
    }
  }

  Future<String?> register({
    required String username,
    required String email,
    required String password,
    required String bio,
  }) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      final result = await _api.register(
        username: username,
        email: email,
        password: password,
        bio: bio,
      );
      state = state.copyWith(
        isLoading: false,
        user: result.user,
        token: result.token,
      );
      return null;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      return error.toString();
    }
  }

  Future<void> refreshUser() async {
    if (state.token == null || state.token!.isEmpty) {
      return;
    }

    try {
      final user = await _api.getCurrentUser();
      state = state.copyWith(user: user, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> logout() async {
    await _api.clearSession();
    state = state.copyWith(
      isLoading: false,
      clearUser: true,
      clearToken: true,
      clearError: true,
    );
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService();
  ref.onDispose(service.dispose);
  return service;
});

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref.watch(apiServiceProvider));
});

final homeRefreshProvider = StateProvider<int>((ref) => 0);

final homeBundleProvider = FutureProvider<HomeBundle>((ref) async {
  ref.watch(homeRefreshProvider);
  final api = ref.watch(apiServiceProvider);

  final posts = await api.getFeed();
  final stories = await api.getActiveStories();
  final requests = await api.getIncomingFollowRequests();

  return HomeBundle(
    posts: posts,
    stories: stories,
    followRequests: requests,
  );
});

final reelsRefreshProvider = StateProvider<int>((ref) => 0);

final reelsProvider = FutureProvider<List<PostModel>>((ref) async {
  ref.watch(reelsRefreshProvider);
  return ref.watch(apiServiceProvider).getReels();
});

final mutualFollowersRefreshProvider = StateProvider<int>((ref) => 0);

final mutualFollowersProvider = FutureProvider<List<AppUser>>((ref) async {
  ref.watch(mutualFollowersRefreshProvider);
  return ref.watch(apiServiceProvider).getMutualFollowers();
});

final profileRefreshProvider =
    StateProvider.family<int, String>((ref, userId) => 0);

final profileBundleProvider =
    FutureProvider.family<ProfileBundle, String>((ref, userId) async {
  ref.watch(profileRefreshProvider(userId));
  final api = ref.watch(apiServiceProvider);
  final response = await api.getUserProfile(userId);
  final posts = await api.getPostsByUser(userId);

  return ProfileBundle(
    user: response.user,
    relationship: response.relationship,
    posts: posts,
  );
});
