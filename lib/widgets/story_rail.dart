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

  late Future<List<UserStoryGroup>> _storiesFuture;
  String? _myAvatarUrl;
  bool _isNavigating = false; // Prevent double taps

  @override
  void initState() {
    super.initState();
    _refresh();
    _fetchMyAvatar();
  }

  void _refresh() {
    setState(() {
      _storiesFuture = _storyService.fetchActiveStories();
    });
  }

  Future<void> _fetchMyAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final res = await _supabase.from('profiles').select('avatar_url').eq('id', user.id).maybeSingle();
      if (mounted && res != null) {
        setState(() {
          _myAvatarUrl = res['avatar_url'];
        });
      }
    }
  }

  Future<void> _handleNavigation(Future<void> Function() action) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      color: Colors.transparent, 
      child: FutureBuilder<List<UserStoryGroup>>(
        future: _storiesFuture,
        builder: (context, snapshot) {
          final groups = snapshot.data ?? [];
          final user = _supabase.auth.currentUser;

          if (user == null) return const SizedBox.shrink();

          // 1. Find My Story Group
          UserStoryGroup? myGroup;
          try {
            myGroup = groups.firstWhere((g) => g.userId == user.id);
          } catch (e) {
            myGroup = null;
          }

          // 2. Filter Friend Groups
          final friendGroups = groups.where((g) => g.userId != user.id).toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: 1 + friendGroups.length, // 1 for MyStory
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildMyStoryItem(myGroup);
              } else {
                return _buildFriendItem(friendGroups[index - 1]);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMyStoryItem(UserStoryGroup? group) {
    final bool hasStory = group != null && group.stories.isNotEmpty;
    final avatar = hasStory ? group!.userAvatar : _myAvatarUrl;

    return GestureDetector(
      onTap: () => _handleNavigation(() async {
        if (hasStory) {
          await showModalBottomSheet(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   ListTile(
                     leading: const Icon(Icons.visibility),
                     title: const Text("Lihat Story"),
                     onTap: () async {
                        Navigator.pop(ctx);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StoryViewPage(stories: group!.stories, userProfile: {'full_name': 'Cerita Saya', 'avatar_url': avatar}),
                          ),
                        );
                        _refresh();
                     },
                   ),
                   ListTile(
                     leading: const Icon(Icons.add_circle_outline),
                     title: const Text("Tambah Story Baru"),
                     onTap: () async {
                       Navigator.pop(ctx);
                       final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStoryPage()));
                       if (res == true) _refresh();
                     },
                   )
                ],
              ),
            ),
          );
        } else {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStoryPage()));
          if (res == true) _refresh();
        }
      }),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Gradient Border if has story
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasStory 
                      ? const LinearGradient(colors: [Colors.purple, Colors.orange, Colors.pink], begin: Alignment.topRight, end: Alignment.bottomLeft)
                      : null,
                    border: !hasStory ? Border.all(color: Colors.grey.shade300, width: 2) : null,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: SafeNetworkImage(
                        imageUrl: avatar,
                        fit: BoxFit.cover,
                        width: double.infinity, height: double.infinity,
                        fallbackIcon: Icons.person,
                      ),
                    ),
                  ),
                ),
                
                if (!hasStory)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue, 
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Cerita Saya",
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.black87),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(UserStoryGroup group) {
    return GestureDetector(
      onTap: () => _handleNavigation(() async {
        await Navigator.push(
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
        );
        _refresh();
      }),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 68, height: 68,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.purple, Colors.orange, Colors.pink], begin: Alignment.topRight, end: Alignment.bottomLeft),
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: SafeNetworkImage(
                    imageUrl: group.userAvatar,
                    fit: BoxFit.cover,
                    width: double.infinity, height: double.infinity,
                    fallbackIcon: Icons.person,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              group.userName,
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.black87),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
