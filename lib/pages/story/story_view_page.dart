import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:mychatolic_app/models/story_model.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/services/story_service.dart';
import 'package:mychatolic_app/features/social/data/chat_repository.dart';

class StoryViewPage extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;
  final Map<String, dynamic> userProfile;

  const StoryViewPage({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    required this.userProfile,
  });

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final ChatRepository _chatRepository = ChatRepository();
  final StoryService _storyService = StoryService();
  final TextEditingController _messageController = TextEditingController();

  late AnimationController _progressController;
  late int _currentIndex;
  
  VideoPlayerController? _videoController;
  bool _isPaused = false;
  final Duration _imageDuration = const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    if (_currentIndex >= widget.stories.length) _currentIndex = 0;

    _progressController = AnimationController(vsync: this);
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onStoryFinished();
      }
    });

    _loadStory(_currentIndex);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _videoController?.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _loadStory(int index) {
    if (index < 0 || index >= widget.stories.length) return;

    setState(() {
      _currentIndex = index;
      _videoController?.dispose();
      _videoController = null;
    });

    final story = widget.stories[index];

    // Mark as viewed
    _storyService.viewStory(story.id);

    if (story.mediaType == 'video') {
      _playVideo(story);
    } else {
      _playImage();
    }
  }

  void _playImage() {
    _progressController.stop();
    _progressController.duration = _imageDuration;
    _progressController.forward(from: 0.0);
  }

  Future<void> _playVideo(Story story) async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl));
    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() {}); 
        _videoController!.play();
        _progressController.duration = _videoController!.value.duration;
        _progressController.forward(from: 0.0);
      }
    } catch (e) {
      debugPrint("Video Error: $e");
      _onStoryFinished(); // Skip on error
    }
  }

  void _onStoryFinished() {
    if (_currentIndex < widget.stories.length - 1) {
      _loadStory(_currentIndex + 1);
    } else {
      Navigator.pop(context); // Close if last story finishes
    }
  }

  void _onTapNext() {
    if (_currentIndex < widget.stories.length - 1) {
      _loadStory(_currentIndex + 1);
    } else {
      Navigator.pop(context);
    }
  }

  void _onTapPrev() {
    if (_currentIndex > 0) {
      _loadStory(_currentIndex - 1);
    } else {
      _loadStory(0); // Restart first story
    }
  }

  void _onLongPressStart() {
    setState(() => _isPaused = true);
    _progressController.stop();
    _videoController?.pause();
  }

  void _onLongPressEnd() {
    setState(() => _isPaused = false);
    _progressController.forward();
    _videoController?.play();
  }

  Future<void> _deleteStory() async {
    final story = widget.stories[_currentIndex];
    final myId = _supabase.auth.currentUser?.id;
    
    if (story.userId != myId) return;

    try {
      _onLongPressStart();
      await _supabase.from('stories').delete().eq('id', story.id);

      setState(() {
        widget.stories.removeAt(_currentIndex);
      });

      if (widget.stories.isEmpty) {
        if (mounted) Navigator.pop(context);
      } else {
        if (_currentIndex >= widget.stories.length) {
          _currentIndex = widget.stories.length - 1;
        }
        _loadStory(_currentIndex);
      }
    } catch (e) {
      debugPrint("Delete Err: $e");
      _onLongPressEnd(); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menghapus story")));
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    FocusScope.of(context).unfocus();

    final story = widget.stories[_currentIndex];
    final myId = _supabase.auth.currentUser?.id;
    final ownerId = story.userId;

    if (myId == null) return;

    try {
      final chatId = await _chatRepository.getOrCreatePrivateChat(ownerId);

      final content = "$text\n\n[Balasan untuk Story]";
      
      await _supabase.from('social_messages').insert({
        'chat_id': chatId,
        'sender_id': myId,
        'content': content,
        'type': 'text', 
        'reply_context': {
           'story_id': story.id,
           'story_url': story.mediaUrl,
           'is_story_reply': true
        }
      });

      await _supabase.from('social_chats').update({
        'last_message': "💬 Membalas story",
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', chatId);

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pesan terkirim!"), duration: Duration(seconds: 1)));
    } catch (e) {
      debugPrint("Send Reply Err: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal kirim: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) return const SizedBox();

    final story = widget.stories[_currentIndex];
    final myId = _supabase.auth.currentUser?.id;
    final isMe = story.userId == myId;

    return Scaffold(
      backgroundColor: Colors.black, // Background for letterbox
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _onTapPrev();
          } else {
            _onTapNext();
          }
        },
        onLongPress: _onLongPressStart,
        onLongPressEnd: (_) => _onLongPressEnd(),
        child: Stack(
          children: [
            // 1. Media Layer (Letterbox)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: _buildMedia(story),
              ),
            ),

            // 2. Gradient Overlay for Text Readability
            Positioned.fill(
              child: Column(
                children: [
                  Container(
                    height: 120, // Increase slightly to cover notch
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withOpacity(0.8), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  ),
                  const Spacer(),
                  Container(
                    height: 120, 
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.8)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  ),
                ],
              ),
            ),

            // 3. Caption Overlay (Bottom of media, above gradients)
            if (story.caption != null && story.caption!.isNotEmpty)
               Positioned(
                 bottom: 100, // Above reply area
                 left: 20, right: 20,
                 child: Text(
                   story.caption!,
                   textAlign: TextAlign.center,
                   style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, backgroundColor: Colors.black45),
                 ),
               ),

            // 4. Header & Progress Bar (Top SafeArea)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    _buildProgressBar(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          SafeNetworkImage(
                            imageUrl: widget.userProfile['avatar_url'],
                            width: 36, height: 36,
                            borderRadius: BorderRadius.circular(18),
                            fallbackIcon: Icons.person,
                            fit: BoxFit.cover,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.userProfile['full_name'] ?? 'User',
                                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                                ),
                                Text(
                                  timeago.format(story.createdAt, locale: 'id'),
                                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                                )
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white, size: 28, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Footer Interaction (Bottom SafeArea)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: isMe ? _buildDeleteButton() : _buildReplyInput(story),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMedia(Story story) {
    if (story.mediaType == 'video') {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        );
      } else {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      }
    } else {
      return SafeNetworkImage(
        imageUrl: story.mediaUrl,
        fit: BoxFit.contain, // Key change for letterbox
        // No infinity, let parent center it
      );
    }
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: widget.stories.asMap().entries.map((entry) {
          final index = entry.key;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  double value = 0.0;
                  if (index < _currentIndex) {
                    value = 1.0;
                  } else if (index == _currentIndex) {
                    value = _progressController.value;
                  }
                  
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 2,
                  );
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: _deleteStory,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildReplyInput(Story story) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        border: Border.all(color: Colors.white54),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.outfit(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: "Kirim pesan...",
                hintStyle: GoogleFonts.outfit(color: Colors.white70),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _sendMessage,
          )
        ],
      ),
    );
  }
}
