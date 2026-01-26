import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Pages
import 'package:mychatolic_app/pages/home_screen.dart';
import 'package:mychatolic_app/pages/create_post_screen.dart';
// Replaced ChurchListPage with SchedulePage
import 'package:mychatolic_app/pages/schedule_page.dart';

import 'package:mychatolic_app/features/profile/pages/profile_page.dart';
import 'package:mychatolic_app/bible/presentation/bible_library_screen.dart';
import 'package:mychatolic_app/pages/radar_page.dart';
import 'package:mychatolic_app/pages/social_inbox_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;
  int _currentIndex = 0;

  final GlobalKey<HomeScreenState> _homeScreenKey =
      GlobalKey<HomeScreenState>();
  Key _profilePageKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _updateLastActive();
    _checkUserProfile();
  }

  void _checkUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (profile == null) {
        // Handle missing profile logic if needed (e.g., redirect to profile setup)
      }
    }
  }

  Future<void> _updateLastActive() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'last_active': DateTime.now().toIso8601String()})
            .eq('id', user.id);
      } catch (e) {
        debugPrint("Error updating last active: $e");
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // List of pages for the bottom navigation
    final List<Widget> children = [
      HomeScreen(key: _homeScreenKey),
      const SchedulePage(), // New Schedule Page
      const BibleLibraryScreen(), // Bible Screen
      const RadarPage(), // Radar Page
      const SocialInboxPage(), // Social Inbox
      ProfilePage(key: _profilePageKey), // Profile Page
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(index: _currentIndex, children: children),
      // Floating Action Button logic for Home screen (creating posts)
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              heroTag: 'home_fab',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                );

                // If a post was created, refresh the HomeScreen feed
                if (result == true) {
                  _homeScreenKey.currentState?.refreshPosts();
                  setState(() {
                    // Ensure explicit Home index if logic changed unexpectedly, and refresh Profile.
                    _currentIndex = 0;
                    _profilePageKey = UniqueKey();
                  });
                }
              },
              backgroundColor: const Color(0xFF0088CC),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xff570088,
              ).withValues(alpha: 0.05), // Light purple shadow
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: Theme.of(context).cardColor,
          selectedItemColor: const Color(0xFF0088CC), // Blue active color
          unselectedItemColor: Colors.grey, // Grey inactive color
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          iconSize: 22,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Jadwal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              label: 'Alkitab',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
