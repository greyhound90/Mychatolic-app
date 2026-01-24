import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mychatolic_app/core/app_colors.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/services/chat_service.dart';
import 'package:mychatolic_app/pages/profile_page.dart';

class SocialChatDetailPage extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> opponentProfile;
  final String?
  otherUserId; // Added for explicit userId access if needed, mainly for future proofing

  const SocialChatDetailPage({
    super.key,
    required this.chatId,
    required this.opponentProfile,
    this.otherUserId,
  });

  @override
  State<SocialChatDetailPage> createState() => _SocialChatDetailPageState();
}

class _SocialChatDetailPageState extends State<SocialChatDetailPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService(); // Added Service
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Audio Player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Color Constants for BEEB feature
  static const Color _beebPrimary = Color(0xFFFF5722);

  // Animation for Beeb Button
  late AnimationController _beebAnimController;

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
    _chatService.markMessagesAsRead(widget.chatId); // Mark Read on Enter

    // Simple animation controller for the Beeb button effect
    _beebAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.2,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _beebAnimController.dispose();
    super.dispose();
  }

  void _subscribeToMessages() {
    final myId = _supabase.auth.currentUser?.id;

    _supabase
        .channel('public:social_messages:chat_id=${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'social_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: widget.chatId,
          ),
          callback: (payload) {
            final newMsg = payload.newRecord;
            final senderId = newMsg['sender_id'];

            // Receiver Experience: ONLY play sound if sender is NOT me.
            if (newMsg['type'] == 'beeb' && senderId != myId) {
              _playSound();
            }
          },
        )
        .subscribe();
  }

  Future<void> _playSound() async {
    try {
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      }
      await _audioPlayer.play(AssetSource('beeb.mp3'));
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  // --- ACTIONS ---

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // For custom shape/color
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMenuIcon(
                    icon: Icons.camera_alt,
                    label: "Kamera",
                    color: Colors.pink,
                    onTap: () {
                      Navigator.pop(context);
                      _handleAttachment(ImageSource.camera);
                    },
                  ),
                  _buildMenuIcon(
                    icon: Icons.photo,
                    label: "Galeri",
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _handleAttachment(ImageSource.gallery);
                    },
                  ),
                  _buildMenuIcon(
                    icon: Icons.location_on,
                    label: "Lokasi",
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _handleLocation();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16), // Extra spacing
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAttachment(ImageSource source) async {
    try {
      // 1. Pick Image
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;

      // 2. Upload to Supabase Storage
      final fileExt = pickedFile.path.split('.').last;
      final fileName =
          'chat_${DateTime.now().millisecondsSinceEpoch}_$myId.$fileExt';
      final path = fileName;

      await _supabase.storage.from('chat-uploads').upload(path, file);

      // 3. Get Public URL
      final imageUrl = _supabase.storage
          .from('chat-uploads')
          .getPublicUrl(path);

      // 4. Send Message
      _sendMessage(type: 'image', content: imageUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal upload gambar: $e")));
      }
    }
  }

  Future<void> _handleLocation() async {
    try {
      // 1. Request Permission
      final status = await Permission.location.request();
      if (status.isGranted) {
        // 2. Get Location
        final position = await Geolocator.getCurrentPosition();

        // 3. Create Google Maps URL
        final googleMapsUrl =
            'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

        // 4. Send Message
        _sendMessage(type: 'location', content: googleMapsUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Izin lokasi ditolak")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal ambil lokasi: $e")));
      }
    }
  }

  Future<void> _sendBeeb() async {
    // 1. Animation & Feedback
    _beebAnimController.forward().then((_) => _beebAnimController.reverse());
    HapticFeedback.mediumImpact();

    // 2. Play Sound Locally
    _playSound();

    // 3. Send to Server
    _sendMessage(type: 'beeb', content: 'BEEB');
  }

  Future<void> _sendMessage({String type = 'text', String? content}) async {
    final text = content ?? _textController.text.trim();
    if (text.isEmpty) return;

    if (type == 'text') {
      _textController.clear();
    }

    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await _supabase.from('social_messages').insert({
        'chat_id': widget.chatId,
        'sender_id': myId,
        'content': text,
        'type': type,
      });

      // Update Summary logic
      String summaryMsg = text;
      if (type == 'beeb') {
        summaryMsg = 'BEEB!';
      } else if (type == 'story_like') {
        summaryMsg = '🔥 Menyukai story';
      } else if (type == 'image') {
        summaryMsg = '📷 Mengirim gambar';
      } else if (type == 'location') {
        summaryMsg = '📍 Mengirim lokasi';
      } else if (type == 'story_reply') {
        summaryMsg = '💬 Membalas story';
      }

      await _supabase
          .from('social_chats')
          .update({
            'updated_at': DateTime.now().toIso8601String(),
            'last_message': summaryMsg,
            'participants': [
              myId,
              widget.opponentProfile['id'],
            ], // Ensure participants are sync
          })
          .eq('id', widget.chatId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal kirim: $e")));
      }
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final opponentName = widget.opponentProfile['full_name'] ?? "User";
    final opponentAvatar = widget.opponentProfile['avatar_url'];
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: AppColors.textPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () {
          final userId = widget.otherUserId ?? widget.opponentProfile['id'];
          if (userId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ProfilePage(userId: userId, isBackButtonEnabled: true),
              ),
            );
          }
        },
        child: Row(
          children: [
            SafeNetworkImage(
              imageUrl: opponentAvatar,
              width: 36,
              height: 36,
              borderRadius: BorderRadius.circular(100),
              fit: BoxFit.cover,
              fallbackIcon: Icons.person,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                opponentName,
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.surface, height: 1),
      ),
    );
  }

  Widget _buildMessageList() {
    final myId = _supabase.auth.currentUser?.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('social_messages')
          .stream(primaryKey: ['id'])
          .eq('chat_id', widget.chatId)
          .order('created_at', ascending: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBrand),
          );
        }

        final messages = snapshot.data!;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        if (messages.isEmpty) {
          return Center(
            child: Text(
              "Mulai percakapan...",
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMe = msg['sender_id'] == myId;
            final type = msg['type'] ?? 'text';
            final content = msg['content'] ?? '';
            final time = msg['created_at'];
            final isRead = msg['is_read'] ?? false;

            if (type == 'beeb') {
              return _buildBeebBubble(isMe, time);
            }
            if (type == 'story_like') {
              return _buildStoryLikeBubble(isMe, content, time);
            }
            if (type == 'story_reply') {
              return _buildStoryReplyBubble(isMe, content, time);
            }
            if (type == 'image') {
              return _buildImageBubble(isMe, content, time);
            }
            if (type == 'location') {
              return _buildLocationBubble(isMe, content, time);
            }
            return _buildTextBubble(isMe, content, time, isRead);
          },
        );
      },
    );
  }

  // 1. Text Bubble
  Widget _buildTextBubble(
    bool isMe,
    String content,
    String? time,
    bool isRead,
  ) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryBrand : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content,
              style: GoogleFonts.outfit(
                color: isMe ? Colors.white : Colors.black,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time != null
                      ? timeago.format(DateTime.parse(time), locale: 'id')
                      : "",
                  style: GoogleFonts.outfit(
                    color: isMe ? Colors.white70 : Colors.black38,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead ? Colors.blue.shade100 : Colors.white60,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. Beeb Bubble
  Widget _buildBeebBubble(bool isMe, String? time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _beebPrimary.withValues(alpha: 0.1),
          border: Border.all(
            color: _beebPrimary.withValues(alpha: 0.5),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/beep.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 6),
            Text(
              "BEEB!",
              style: GoogleFonts.outfit(
                color: _beebPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time != null
                  ? timeago.format(DateTime.parse(time), locale: 'id')
                  : "",
              style: GoogleFonts.outfit(
                color: _beebPrimary.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Story Like Bubble (Fire + Image)
  Widget _buildStoryLikeBubble(bool isMe, String imageUrl, String? time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: SafeNetworkImage(
                imageUrl: imageUrl,
                width: 140,
                height: 180,
                fit: BoxFit.cover,
                fallbackIcon: Icons.image_rounded,
              ),
            ),

            // Caption
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.deepOrange,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Menyukai story Anda",
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Story Reply Bubble (Image + Comment)
  Widget _buildStoryReplyBubble(bool isMe, String content, String? time) {
    // Parse Content: url|||text
    final parts = content.split('|||');
    final imageUrl = parts.isNotEmpty ? parts[0] : '';
    final comment = parts.length > 1 ? parts[1] : content;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryBrand : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          border: isMe
              ? null
              : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Context
            Padding(
              padding: const EdgeInsets.only(
                left: 12,
                top: 8,
                right: 12,
                bottom: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 2,
                    height: 12,
                    color: isMe ? Colors.white70 : AppColors.primaryBrand,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Membalas story",
                    style: GoogleFonts.outfit(
                      color: isMe ? Colors.white70 : AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 12, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SafeNetworkImage(
                      imageUrl: imageUrl,
                      width: 40,
                      height: 56,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.image,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Comment Text
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        comment,
                        style: GoogleFonts.outfit(
                          color: isMe ? Colors.white : AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Time
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 6),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  time != null
                      ? timeago.format(DateTime.parse(time), locale: 'id')
                      : "",
                  style: GoogleFonts.outfit(
                    color: isMe ? Colors.white60 : Colors.black38,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. Image Bubble
  Widget _buildImageBubble(bool isMe, String imageUrl, String? time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _showDialogImage(imageUrl),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          width: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                child: SafeNetworkImage(
                  imageUrl: imageUrl,
                  width: 200,
                  height: 250,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.broken_image,
                ),
              ),
              // Time
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  time != null
                      ? timeago.format(DateTime.parse(time), locale: 'id')
                      : "",
                  style: GoogleFonts.outfit(
                    color: Colors.black38,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 6. Location Bubble (New)
  Widget _buildLocationBubble(bool isMe, String url, String? time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            debugPrint("Could not launch $url");
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primaryBrand : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: isMe
                ? null
                : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Map Icon Box
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),

              // Text
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Lokasi Terkini",
                      style: GoogleFonts.outfit(
                        color: isMe ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "Lihat di Google Maps",
                      style: GoogleFonts.outfit(
                        color: isMe ? Colors.white70 : AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showDialogImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SafeNetworkImage(
              imageUrl: imageUrl,
              width: double.infinity,
              fit: BoxFit.contain,
              fallbackIcon: Icons.broken_image,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // BEEB Button
          GestureDetector(
            onTap: _sendBeeb,
            child: AnimatedBuilder(
              animation: _beebAnimController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 - _beebAnimController.value,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFCCBC),
                    ),
                    child: Image.asset(
                      'assets/beep.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 8),

          // ATTACHMENT Button (WhatsApp Style)
          IconButton(
            icon: Transform.rotate(
              angle: -3.14 / 4, // 45 degrees
              child: const Icon(
                Icons.attach_file,
                color: AppColors.textSecondary,
              ),
            ),
            onPressed: _showAttachmentSheet,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: "Tulis pesan...",
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          GestureDetector(
            onTap: () => _sendMessage(type: 'text'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBrand, AppColors.primaryHover],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBrand.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
