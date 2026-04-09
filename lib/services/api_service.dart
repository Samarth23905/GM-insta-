import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/Comment.dart';
import '../models/Message.dart';
import '../models/Post.dart';
import '../models/Story.dart';
import '../models/User.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class UserProfileResponse {
  const UserProfileResponse({required this.user, required this.relationship});

  final AppUser user;
  final Map<String, dynamic> relationship;
}

class ApiService {
  ApiService()
    : _storage = const FlutterSecureStorage(),
      _client = http.Client();

  static const _tokenKey = 'gminsta_jwt';
  static const baseUrl = 'https://gm-insta.onrender.com/api';

  final FlutterSecureStorage _storage;
  final http.Client _client;
  final StreamController<MessageModel> _messagesController =
      StreamController<MessageModel>.broadcast();

  io.Socket? _socket;

  String get socketBaseUrl => baseUrl.replaceFirst(RegExp(r'/api$'), '');

  Stream<MessageModel> get messagesStream => _messagesController.stream;

  Future<String?> getSavedToken() => _storage.read(key: _tokenKey);

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    disconnectSocket();
  }

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    String bio = '',
  }) async {
    final payload = await _request(
      method: 'POST',
      path: '/auth/register',
      body: {
        'username': username,
        'email': email,
        'password': password,
        'bio': bio,
      },
    );

    return _handleAuthResult(payload);
  }

  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    final payload = await _request(
      method: 'POST',
      path: '/auth/login',
      body: {'identifier': identifier, 'password': password},
    );

    return _handleAuthResult(payload);
  }

  Future<AppUser> getCurrentUser() async {
    final payload = await _request(
      method: 'GET',
      path: '/auth/me',
      requiresAuth: true,
    );

    return _mapUser(payload['user'] as Map<String, dynamic>);
  }

  Future<AppUser> updateProfilePicture(XFile file) async {
    final payload = await _multipart(
      method: 'PUT',
      path: '/auth/profile-picture',
      fieldName: 'profilePic',
      file: file,
    );

    return _mapUser(payload['user'] as Map<String, dynamic>);
  }

  Future<List<AppUser>> searchUsers(String query) async {
    final payload = await _request(
      method: 'GET',
      path: '/auth/search?q=${Uri.encodeQueryComponent(query)}',
      requiresAuth: true,
    );

    return (payload['users'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapUser)
        .toList();
  }

  Future<UserProfileResponse> getUserProfile(String userId) async {
    final payload = await _request(
      method: 'GET',
      path: '/auth/users/$userId',
      requiresAuth: true,
    );

    return UserProfileResponse(
      user: _mapUser(payload['user'] as Map<String, dynamic>),
      relationship: Map<String, dynamic>.from(
        payload['relationship'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Future<List<PostModel>> getFeed() async {
    final payload = await _request(
      method: 'GET',
      path: '/posts/feed',
      requiresAuth: true,
    );

    return (payload['posts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapPost)
        .toList();
  }

  Future<List<PostModel>> getReels() async {
    final payload = await _request(
      method: 'GET',
      path: '/posts/reels',
      requiresAuth: true,
    );

    return (payload['reels'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapPost)
        .toList();
  }

  Future<List<PostModel>> getPostsByUser(String userId) async {
    final payload = await _request(
      method: 'GET',
      path: '/posts/user/$userId',
      requiresAuth: true,
    );

    return (payload['posts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapPost)
        .toList();
  }

  Future<PostModel> createPost({
    required XFile file,
    required String caption,
  }) async {
    final payload = await _multipart(
      path: '/posts',
      fieldName: 'media',
      file: file,
      extraFields: {'caption': caption},
    );

    return _mapPost(payload['post'] as Map<String, dynamic>);
  }

  Future<PostModel> reactToPost(String postId, String reaction) async {
    final payload = await _request(
      method: 'PUT',
      path: '/posts/$postId/react',
      requiresAuth: true,
      body: {'reaction': reaction},
    );

    return _mapPost(payload['post'] as Map<String, dynamic>);
  }

  Future<void> deletePost(String postId) async {
    await _request(
      method: 'DELETE',
      path: '/posts/$postId',
      requiresAuth: true,
    );
  }

  Future<List<CommentModel>> getComments(String postId) async {
    final payload = await _request(
      method: 'GET',
      path: '/comments/$postId',
      requiresAuth: true,
    );

    return (payload['comments'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapComment)
        .toList();
  }

  Future<CommentModel> addComment(String postId, String commentText) async {
    final payload = await _request(
      method: 'POST',
      path: '/comments/$postId',
      requiresAuth: true,
      body: {'commentText': commentText},
    );

    return _mapComment(payload['comment'] as Map<String, dynamic>);
  }

  Future<CommentModel> updateComment({
    required String commentId,
    required String commentText,
  }) async {
    final payload = await _request(
      method: 'PUT',
      path: '/comments/edit/$commentId',
      requiresAuth: true,
      body: {'commentText': commentText},
    );

    return _mapComment(payload['comment'] as Map<String, dynamic>);
  }

  Future<StoryModel> addStory(XFile file) async {
    final payload = await _multipart(
      path: '/posts/stories',
      fieldName: 'media',
      file: file,
    );

    return _mapStory(payload['story'] as Map<String, dynamic>);
  }

  Future<List<StoryGroup>> getActiveStories() async {
    final payload = await _request(
      method: 'GET',
      path: '/posts/stories/active',
      requiresAuth: true,
    );

    return (payload['stories'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => StoryGroup(
            user: _mapUser(json['user'] as Map<String, dynamic>),
            stories: (json['stories'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map((story) => _mapStory({...story, 'user': json['user']}))
                .toList(),
          ),
        )
        .toList();
  }

  Future<void> sendFollowRequest(String userId) async {
    await _request(
      method: 'POST',
      path: '/follow/request/$userId',
      requiresAuth: true,
    );
  }

  Future<List<AppUser>> getIncomingFollowRequests() async {
    final payload = await _request(
      method: 'GET',
      path: '/follow/requests',
      requiresAuth: true,
    );

    return (payload['requests'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapUser)
        .toList();
  }

  Future<void> respondToFollowRequest({
    required String requesterId,
    required bool accept,
  }) async {
    await _request(
      method: 'POST',
      path: '/follow/respond/$requesterId',
      requiresAuth: true,
      body: {'action': accept ? 'accept' : 'reject'},
    );
  }

  Future<List<AppUser>> getMutualFollowers() async {
    final payload = await _request(
      method: 'GET',
      path: '/chat/mutuals',
      requiresAuth: true,
    );

    return (payload['users'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapUser)
        .toList();
  }

  Future<List<MessageModel>> getChatHistory(String receiverId) async {
    final payload = await _request(
      method: 'GET',
      path: '/chat/messages/$receiverId',
      requiresAuth: true,
    );

    return (payload['messages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_mapMessage)
        .toList();
  }

  Future<MessageModel> sendMessage({
    required String receiverId,
    required String messageText,
  }) async {
    final payload = await _request(
      method: 'POST',
      path: '/chat/messages/$receiverId',
      requiresAuth: true,
      body: {'messageText': messageText},
    );

    return _mapMessage(payload['data'] as Map<String, dynamic>);
  }

  Future<void> connectSocketWithSavedToken() async {
    final token = await getSavedToken();
    if (token != null && token.isNotEmpty) {
      connectSocket(token);
    }
  }

  void connectSocket(String token) {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
    }

    _socket = io.io(
      socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .build(),
    );

    _socket!.on('message:new', (data) {
      if (data is Map) {
        _messagesController.add(_mapMessage(Map<String, dynamic>.from(data)));
      }
    });
  }

  void disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  String resolveMediaUrl(String value) {
    if (value.isEmpty || value.startsWith('http')) {
      return value;
    }

    final normalizedValue = value.replaceAll('\\', '/');
    final uploadsIndex = normalizedValue.lastIndexOf('/uploads/');
    final relativePath = uploadsIndex >= 0
        ? normalizedValue.substring(uploadsIndex)
        : (normalizedValue.startsWith('uploads/')
              ? '/$normalizedValue'
              : normalizedValue);

    return '${socketBaseUrl}${relativePath.startsWith('/') ? '' : '/'}$relativePath';
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    bool requiresAuth = false,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (requiresAuth) {
      final token = await getSavedToken();
      if (token == null || token.isEmpty) {
        throw const ApiException('Please log in again.');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    late http.Response response;
    final encodedBody = body == null ? null : jsonEncode(body);

    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _client.post(uri, headers: headers, body: encodedBody);
        break;
      case 'PUT':
        response = await _client.put(uri, headers: headers, body: encodedBody);
        break;
      case 'DELETE':
        response = await _client.delete(
          uri,
          headers: headers,
          body: encodedBody,
        );
        break;
      default:
        throw ApiException('Unsupported method: $method');
    }

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _multipart({
    String method = 'POST',
    required String path,
    required String fieldName,
    required XFile file,
    Map<String, String>? extraFields,
  }) async {
    final token = await getSavedToken();
    if (token == null || token.isEmpty) {
      throw const ApiException('Please log in again.');
    }

    final request = http.MultipartRequest(method, Uri.parse('$baseUrl$path'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(extraFields ?? {});

    final Uint8List bytes = await file.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: file.name,
        contentType: _detectMediaType(file),
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _decodeResponse(response);
  }

  Future<AuthResult> _handleAuthResult(Map<String, dynamic> payload) async {
    final token = (payload['token'] ?? '').toString();
    final user = _mapUser(payload['user'] as Map<String, dynamic>);
    await _storage.write(key: _tokenKey, value: token);
    connectSocket(token);
    return AuthResult(token: token, user: user);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }

    throw ApiException(
      (payload['message'] ?? 'Request failed with ${response.statusCode}')
          .toString(),
    );
  }

  AppUser _mapUser(Map<String, dynamic> json) {
    final user = AppUser.fromJson(json);
    return user.copyWith(profilePic: resolveMediaUrl(user.profilePic));
  }

  PostModel _mapPost(Map<String, dynamic> json) {
    final post = PostModel.fromJson(json);
    return post.copyWith(
      media: resolveMediaUrl(post.media),
      user: post.user.copyWith(
        profilePic: resolveMediaUrl(post.user.profilePic),
      ),
    );
  }

  CommentModel _mapComment(Map<String, dynamic> json) {
    final comment = CommentModel.fromJson(json);
    return comment.copyWith(
      user: comment.user.copyWith(
        profilePic: resolveMediaUrl(comment.user.profilePic),
      ),
    );
  }

  StoryModel _mapStory(Map<String, dynamic> json) {
    final story = StoryModel.fromJson(json);
    return story.copyWith(
      media: resolveMediaUrl(story.media),
      user: story.user.copyWith(
        profilePic: resolveMediaUrl(story.user.profilePic),
      ),
    );
  }

  MessageModel _mapMessage(Map<String, dynamic> json) {
    final message = MessageModel.fromJson(json);
    return message.copyWith(
      sender: message.sender.copyWith(
        profilePic: resolveMediaUrl(message.sender.profilePic),
      ),
      receiver: message.receiver.copyWith(
        profilePic: resolveMediaUrl(message.receiver.profilePic),
      ),
    );
  }

  void dispose() {
    _client.close();
    disconnectSocket();
    _messagesController.close();
  }

  MediaType _detectMediaType(XFile file) {
    final mimeType = lookupMimeType(file.name, headerBytes: const []);
    if (mimeType == null || !mimeType.contains('/')) {
      return MediaType('application', 'octet-stream');
    }

    final parts = mimeType.split('/');
    return MediaType(parts.first, parts.last);
  }
}
