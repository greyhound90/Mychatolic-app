import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/models/story_model.dart';
import 'package:mychatolic_app/services/story_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class StoryViewPage extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;
  final Map<String, dynamic>?
  userProfile; // Kept for compatibility with StoryRail

  const StoryViewPage({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    this.userProfile,
  });

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;

  int _currentIndex = 0;
  final StoryService _storyService = StoryService();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onNext();
      }
    });

    _loadStory(index: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _loadStory({required int index, bool animatePage = false}) {
    if (index >= widget.stories.length) return;

    _currentIndex = index;

    // View Tracking
    _storyService.viewStory(widget.stories[index].id);

    // Reset & Start Timer
    _animController.stop();
    _animController.reset();
    _animController.forward();

    if (animatePage && _pageController.hasClients) {
      _pageController.jumpToPage(index);
    }

    if (mounted) setState(() {});
  }

  // --- NAVIGATION LOGIC ---

  void _onNext() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _loadStory(index: _currentIndex, animatePage: true);
    } else {
      Navigator.pop(context);
    }
  }

  void _onPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadStory(index: _currentIndex, animatePage: true);
    } else {
      // If at first story, restart timer
      _animController.reset();
      _animController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    // Requirements: Tap Left (30%) -> Prev, Tap Right (70%) -> Next
    if (dx < screenWidth * 0.3) {
      _onPrevious();
    } else {
      _onNext();
    }
  }

  void _onLongPressStart() {
    _animController.stop(); // Pause Timer
  }

  void _onLongPressEnd() {
    _animController.forward(); // Resume Timer
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    // Determine Author Info
    final name = story.authorName ?? widget.userProfile?['full_name'] ?? 'User';
    final avatar = story.authorAvatar ?? widget.userProfile?['avatar_url'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: _onTapUp,
        onLongPressStart: (_) => _onLongPressStart(),
        onLongPressEnd: (_) => _onLongPressEnd(),
        // Also handle cancel/up just in case
        onLongPressCancel: () => _onLongPressEnd(),
        child: Stack(
          children: [
            // 1. MAIN CONTENT (Image)
            Center(
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: SafeNetworkImage(
                  imageUrl: story.mediaUrl,
                  fit: BoxFit.contain, // Requirement: Contain
                  fallbackIcon: Icons.broken_image,
                  fallbackColor: Colors.grey[900],
                ),
              ),
            ),

            // 2. OVERLAYS (SafeArea)
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // A. PROGRESS BAR ROW
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: widget.stories.asMap().entries.map((entry) {
                        return _buildSegmentedProgressBar(entry.key);
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // B. HEADER INFO
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey,
                          ),
                          child: ClipOval(
                            child: SafeNetworkImage(
                              imageUrl: avatar,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Name & Time
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              timeago.format(
                                story.createdAt,
                                locale: 'en_short',
                              ),
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Close Button
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. CAPTION (Optional Overlay)
            if (story.caption != null && story.caption!.isNotEmpty)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Text(
                  story.caption!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [
                      const Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedProgressBar(int index) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Background (Grey)
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),

                // Foreground (White)
                if (index < _currentIndex)
                  Container(
                    height: 3,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  )
                else if (index == _currentIndex)
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Container(
                        height: 3,
                        width: constraints.maxWidth * _animController.value,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
