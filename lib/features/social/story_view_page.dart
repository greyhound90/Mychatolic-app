import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class StoryViewPage extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final Map<String, dynamic> userProfile; // Must contain 'id'

  const StoryViewPage({
    super.key,
    required this.stories,
    required this.userProfile,
  });

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late PageController _pageController;
  late AnimationController _animController;
  late AnimationController _likeAnimController; // Controller for bouncing heart/fire
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  int _currentIndex = 0;
  bool _isPaused = false;
  bool _isLiked = false; // Optimistic Like State

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    
    // Bouncy animation for Like button
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 1.0,
      upperBound: 1.5,
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _animController.forward();
    
    // Pause story when typing
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _animController.stop();
        setState(() => _isPaused = true);
      } else {
        if (!_isPaused && _animController.status != AnimationStatus.completed) {
           _animController.forward();
        }
        setState(() => _isPaused = false);
      }
    });

    _checkLikeStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    _likeAnimController.dispose();
    _replyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- LIKE LOGIC ---
  Future<void> _checkLikeStatus() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    
    final storyId = widget.stories[_currentIndex]['id'];

    try {
      final count = await _supabase
          .from('story_likes')
          .count(CountOption.exact)
          .eq('story_id', storyId)
          .eq('user_id', myId);
      
      if (mounted) {
        setState(() {
          _isLiked = count > 0;
        });
      }
    } catch (_) {
      // Ignore error for visual smoothness
    }
  }

  Future<void> _toggleLike() async {
    final myId = _supabase.auth.currentUser?.id;
    final targetUserId = widget.userProfile['id'];
    if (myId == null || targetUserId == null) return;
    
    final storyId = widget.stories[_currentIndex]['id'];
    
    // 1. Optimistic UI Update
    setState(() {
      _isLiked = !_isLiked;
    });

    // 2. Play Animation if Liked
    if (_isLiked) {
      _likeAnimController.forward().then((_) => _likeAnimController.reverse());
    }

    try {
      if (_isLiked) {
        // --- ACTION: LIKE ---
        
        // A. Insert to Story Likes Table
        await _supabase.from('story_likes').insert({
          'user_id': myId,
          'story_id': storyId,
        });

        // B. TRIGGER CHAT NOTIFICATION (Background)
        // Only trigger if liking someone else's story
        if (myId != targetUserId) {
          _sendLikeNotification(myId, targetUserId);
        }

      } else {
        // --- ACTION: UNLIKE ---
        await _supabase.from('story_likes').delete()
          .eq('user_id', myId)
          .eq('story_id', storyId);
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() => _isLiked = !_isLiked);
        debugPrint("Toggle like error: $e");
        // Optional: Show snackbar
      }
    }
  }

  // Separate method for background chat trigger to keep toggleLike clean
  Future<void> _sendLikeNotification(String myId, String targetUserId) async {
    try {
       // 1. Check/Create Chat
       String? chatId;
       
       // Try to find existing chat with exact participants
       // Using contains for both is tricky with single query without RPC or exact match logic
       // Simplest robust approach: Get my chats, filter client side (for MVP scale)
       final myChats = await _supabase
          .from('social_chats')
          .select()
          .contains('participants', [myId]);

       for (var chat in myChats) {
        final participants = List<dynamic>.from(chat['participants'] ?? []);
        if (participants.contains(targetUserId)) {
          chatId = chat['id'];
          break;
        }
      }

      if (chatId == null) {
        final newChat = await _supabase.from('social_chats').insert({
          'participants': [myId, targetUserId],
          'updated_at': DateTime.now().toIso8601String(),
          'last_message': 'Reacted to story',
        }).select().single();
        chatId = newChat['id'];
      }

      // 2. Send Message
      await _supabase.from('social_messages').insert({
        'chat_id': chatId,
        'sender_id': myId,
        'content': widget.stories[_currentIndex]['media_url'], // Send Image URL
        'type': 'story_like', // Special type for styling
      });

      // 3. Update Chat Timestamp
      await _supabase.from('social_chats').update({
        'updated_at': DateTime.now().toIso8601String(),
        'last_message': '🔥 Menyukai story Anda', // Keep text for inbox preview
      }).eq('id', chatId!);

    } catch (e) {
      // Silently fail for notifications, don't revert the actual Like
      debugPrint("Failed to send like notification: $e");
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _isLiked = false; // Reset for next story (will fetch correctly)
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animController.reset();
      _animController.forward();
      _checkLikeStatus(); // Check for next story
    } else {
      Navigator.pop(context); 
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isLiked = false;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animController.reset();
      _animController.forward();
      _checkLikeStatus(); // Check for prev story
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
      return; 
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (dx < screenWidth / 3) {
      _previousStory();
    } else {
      _nextStory();
    }
  }

  // --- REPLY LOGIC (IMPROVED) ---
  Future<void> _handleReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final myId = _supabase.auth.currentUser?.id;
    final targetUserId = widget.userProfile['id'];
    
    // Prevent self-reply
    if (myId == null || targetUserId == null) return;
    if (myId == targetUserId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak bisa membalas story sendiri")));
      return;
    }

    // Dismiss Keyboard and Clear immediately for better UX
    _focusNode.unfocus(); // Close keyboard
    _replyController.clear(); // Clear input

    try {
      // 1. Check or Create Chat Room (Same logic as Like)
      String? chatId;

      final myChats = await _supabase
          .from('social_chats')
          .select()
          .contains('participants', [myId]); 
      
      for (var chat in myChats) {
        final participants = List<dynamic>.from(chat['participants'] ?? []);
        if (participants.contains(targetUserId)) {
          chatId = chat['id'];
          break;
        }
      }

      if (chatId == null) {
        final newChat = await _supabase.from('social_chats').insert({
          'participants': [myId, targetUserId],
          'updated_at': DateTime.now().toIso8601String(),
          'last_message': 'Replied to story',
        }).select().single();
        chatId = newChat['id'];
      }

      // 2. Format Message Content: URL ||| Text
      final currentStoryUrl = widget.stories[_currentIndex]['media_url'];
      final messageContent = '$currentStoryUrl|||$text';

      // 3. Insert Message
      await _supabase.from('social_messages').insert({
        'chat_id': chatId,
        'sender_id': myId,
        'content': messageContent,
        'type': 'story_reply', 
      });

      // 4. Update Chat Last Message
      await _supabase.from('social_chats').update({
        'updated_at': DateTime.now().toIso8601String(),
        'last_message': '💬 Membalas story Anda',
      }).eq('id', chatId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Balasan terkirim")));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final createdTime = DateTime.parse(story['created_at']);
    final isMyStory = widget.userProfile['id'] == _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true, // Allow layout to adjust for keyboard
      body: Stack(
        children: [
          // 1. Story Image & Gesture Area
          Positioned.fill(
            child: GestureDetector(
              onTapDown: _onTapDown,
              onLongPress: () {
                 _animController.stop();
              },
              onLongPressUp: () {
                 if (!_focusNode.hasFocus) _animController.forward();
              },
              child: Stack(
                children: [
                   Container(color: Colors.black), // Tap target background
                   Center(
                      child: SafeNetworkImage(
                        imageUrl: story['media_url'],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                        fallbackIcon: Icons.broken_image,
                      ),
                   ),
                   // Gradient at bottom for better text visibility
                   Positioned(
                     bottom: 0, left: 0, right: 0,
                     height: 150,
                     child: Container(
                       decoration: const BoxDecoration(
                         gradient: LinearGradient(
                           colors: [Colors.transparent, Colors.black54],
                           begin: Alignment.topCenter, end: Alignment.bottomCenter
                         )
                       ),
                     ),
                   )
                ],
              ),
            ),
          ),

          // 2. Progress Bar
          Positioned(
            top: 40,
            left: 10,
            right: 10,
            child: Row(
              children: List.generate(widget.stories.length, (index) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: index == _currentIndex
                        ? AnimatedBuilder(
                            animation: _animController,
                            builder: (context, child) {
                              return LinearProgressIndicator(
                                value: _animController.value,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(Colors.white),
                                minHeight: 3,
                                borderRadius: BorderRadius.circular(2),
                              );
                            },
                          )
                        : LinearProgressIndicator(
                            value: index < _currentIndex ? 1.0 : 0.0,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(2),
                          ),
                  ),
                );
              }),
            ),
          ),

          // 3. User Info Header
          Positioned(
            top: 55,
            left: 16,
            child: Row(
              children: [
                SafeNetworkImage(
                  imageUrl: widget.userProfile['avatar_url'],
                  width: 40, height: 40,
                  borderRadius: BorderRadius.circular(20),
                  fit: BoxFit.cover,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userProfile['full_name'] ?? 'User',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        shadows: [const Shadow(color: Colors.black, blurRadius: 4)]
                      ),
                    ),
                    Text(
                      timeago.format(createdTime, locale: 'id'),
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                        shadows: [const Shadow(color: Colors.black, blurRadius: 4)]
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Close Button
          Positioned(
            top: 55,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // 5. Reply & Like Bar
          if (!isMyStory)
          Positioned(
            bottom: Platform.isIOS ? 32 : 16, 
            left: 16, 
            right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    // INPUT FIELD
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _replyController,
                          focusNode: _focusNode,
                          style: GoogleFonts.outfit(color: Colors.white),
                          cursorColor: Colors.white,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleReply(),
                          decoration: InputDecoration(
                            hintText: "Kirim pesan...",
                            hintStyle: GoogleFonts.outfit(color: Colors.white70),
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // SEND BUTTON
                    GestureDetector(
                      onTap: _handleReply,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // LIKE BUTTON (FIRE)
                    ScaleTransition(
                      scale: _likeAnimController,
                      child: Container(
                        height: 44, width: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isLiked ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                          border: Border.all(color: Colors.white30, width: 1),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.local_fire_department_rounded,
                            color: _isLiked ? Colors.deepOrange : Colors.white,
                            size: 26,
                          ),
                          onPressed: _toggleLike,
                        ),
                      ),
                    )
                  ],
                ),
              ),
          ),
        ],
      ),
    );
  }
}
