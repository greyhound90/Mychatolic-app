import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/story_model.dart';
import 'package:mychatolic_app/services/story_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/story/create_story_page.dart';
import 'package:mychatolic_app/pages/story/story_view_page.dart';

class StoryRail extends StatefulWidget {
  const StoryRail({super.key});

  @override
  State<StoryRail> createState() => _StoryRailState();
}

class _StoryRailState extends State<StoryRail> {
  final _storyService = StoryService();
  final _supabase = Supabase.instance.client;
  
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'stories': <UserStoryGroup>[], 'myAvatar': null};
    }

    try {
      // 1. Fetch Stories
      final stories = await _storyService.fetchActiveStories();
      
      // 2. Check if current user has a story
      final myStoryGroup = stories.where((s) => s.userId == user.id).firstOrNull;
      
      String? myAvatar;
      if (myStoryGroup != null) {
        myAvatar = myStoryGroup.userAvatar;
      } else {
        // 3. If no story, fetch profile avatar
        final profile = await _supabase
            .from('profiles')
            .select('avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        myAvatar = profile?['avatar_url'];
      }

      return {'stories': stories, 'myAvatar': myAvatar};
    } catch (e) {
      debugPrint("Error loading story rail: $e");
      return {'stories': <UserStoryGroup>[], 'myAvatar': null};
    }
  }

  void _refresh() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      color: Colors.grey[50],
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {'stories': <UserStoryGroup>[], 'myAvatar': null};
          final allStories = data['stories'] as List<UserStoryGroup>;
          final myAvatar = data['myAvatar'] as String?;
          final user = _supabase.auth.currentUser;

          if (user == null) return const SizedBox.shrink();

          // Separate My Story vs Friends
          UserStoryGroup? myStoryGroup;
          final List<UserStoryGroup> friendStories = [];
          
          for (var group in allStories) {
            if (group.userId == user.id) {
              myStoryGroup = group;
            } else {
              friendStories.add(group);
            }
          }

          final int itemCount = 1 + friendStories.length; // 1 for "My Story" + friends

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                // MY STORY ITEM
                return _buildMyStoryItem(myStoryGroup, myAvatar);
              } else {
                // FRIEND ITEM
                final friendGroup = friendStories[index - 1];
                return _buildFriendItem(friendGroup);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMyStoryItem(UserStoryGroup? group, String? avatarUrl) {
    final bool hasStory = group != null && group.stories.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        if (hasStory) {
          await Navigator.push(
            context,
            MaterialPageRoute(
               builder: (_) => StoryViewPage(
                 stories: group.stories,
                 userProfile: {
                   'full_name': 'Cerita Saya', // Placeholder name
                   'avatar_url': avatarUrl,
                 },
               ),
            ),
          );
        } else {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateStoryPage()),
          );
          if (result == true) _refresh(); // Refresh if story created
        }
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                children: [
                  // Avatar Border Ring
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasStory 
                          ? const LinearGradient(
                              colors: [Colors.purple, Colors.orange],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ) 
                          : null,
                      border: !hasStory 
                          ? Border.all(color: Colors.grey.shade300, width: 2) 
                          : null,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: SafeNetworkImage(
                          imageUrl: avatarUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.person,
                        ),
                      ),
                    ),
                  ),
                  
                  // "+" Badge if no story
                  if (!hasStory)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.add, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Cerita Saya",
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(UserStoryGroup group) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryViewPage(
              stories: group.stories,
              userProfile: {
                'full_name': group.userName,
                'avatar_url': group.userAvatar,
              },
            ),
          ),
        ).then((_) => _refresh()); // Refresh on return to update view status if needed
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                 shape: BoxShape.circle,
                 gradient: LinearGradient(
                   colors: [Colors.purple, Colors.orange, Colors.pink],
                   begin: Alignment.topRight,
                   end: Alignment.bottomLeft,
                 ),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: SafeNetworkImage(
                    imageUrl: group.userAvatar,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              group.userName,
              style: GoogleFonts.outfit(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
