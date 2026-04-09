import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gm_insta/main.dart';

import 'package:gm_insta/models/Story.dart';
import 'package:gm_insta/models/User.dart';
import 'package:gm_insta/widgets/story_widget.dart';

void main() {
  test('GMinstaApp compiles', () {
    expect(const GMinstaApp(), isA<GMinstaApp>());
  });

  testWidgets('StoryWidget renders username', (WidgetTester tester) async {
    const user = AppUser(
      id: '1',
      username: 'sam',
      email: 'sam@example.com',
      bio: 'bio',
      profilePic: '',
      followersCount: 0,
      followingCount: 0,
      postsCount: 0,
      isFollowing: false,
      hasRequested: false,
    );

    final group = StoryGroup(
      user: user,
      stories: [
        StoryModel(
          id: 'story1',
          user: user,
          media: '',
          mediaType: 'image',
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryWidget(
            group: group,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('sam'), findsOneWidget);
  });
}
