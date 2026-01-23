import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import 'package:mychatolic_app/core/app_colors.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class RadarChatPage extends StatefulWidget {
  final String chatRoomId;
  final String title;

  const RadarChatPage({super.key, required this.chatRoomId, required this.title});

  @override
  State<RadarChatPage> createState() => _RadarChatPageState();
}

class _RadarChatPageState extends State<RadarChatPage>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _sending = false;
  bool _chatReady = false;

  final Map<String, Map<String, dynamic>> _profileCache = {};

  late final AnimationController _beebAnimController;
  static const Color _beebPrimary = Color(0xFFFF5722);
  static const Color _beebBackground = Color(0xFFFFCCBC);

  String _roomTitle = '';
  int _memberCount = 0;
  String? _lastPlayedBeebId;

  @override
  void initState() {
    super.initState();
    _roomTitle = widget.title;
    _beebAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.2,
    );
    Future.microtask(_initChat);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _beebAnimController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    await _ensureChatMembership();
    if (!mounted) return;
    setState(() => _chatReady = true);
    await _loadRoomInfo();
    await _loadMemberCount();
  }

  Future<void> _loadRoomInfo() async {
    // Best-effort: load name from chat_rooms (trigger-created group).
    try {
      final row = await _supabase
          .from('chat_rooms')
          .select('name')
          .eq('id', widget.chatRoomId)
          .maybeSingle();

      final name = row?['name']?.toString();
      if (!mounted) return;
      if (name != null && name.trim().isNotEmpty) {
        setState(() => _roomTitle = name.trim());
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR CHAT] Load room info failed: $e\n$st");
      }
    }
  }

  Future<void> _loadMemberCount() async {
    try {
      final rows = await _supabase
          .from('chat_members')
          .select('user_id')
          .eq('chat_id', widget.chatRoomId);
      final list = List<Map<String, dynamic>>.from(rows);
      if (!mounted) return;
      setState(() => _memberCount = list.length);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR CHAT] Load member count failed: $e\n$st");
      }
    }
  }

  Future<void> _ensureChatMembership() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await _supabase.from('chat_members').upsert(
        {'chat_id': widget.chatRoomId, 'user_id': myId},
        onConflict: 'chat_id, user_id',
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR CHAT] Ensure member failed: $e\n$st");
      }
      try {
        await _supabase.rpc('ensure_chat_member', params: {
          'p_chat_id': widget.chatRoomId,
          'p_user_id': myId,
        });
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint("[RADAR CHAT] Ensure member RPC failed: $e\n$st");
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMembers() async {
    final rows = await _supabase
        .from('chat_members')
        .select(
          'user_id, role, joined_at, profiles:user_id(id, full_name, avatar_url)',
        )
        .eq('chat_id', widget.chatRoomId)
        .order('joined_at', ascending: true);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _showMembersSheet() async {
    try {
      final members = await _fetchMembers();
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Anggota ($_memberCount)",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: members.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final m = members[index];
                        final profile = m['profiles'] is Map
                            ? Map<String, dynamic>.from(m['profiles'] as Map)
                            : const <String, dynamic>{};
                        final userId = (m['user_id'] ?? '').toString();
                        final myId = _supabase.auth.currentUser?.id;
                        final isMe = myId != null && userId == myId;
                        final name =
                            (profile['full_name'] ?? 'Umat').toString();
                        final avatarUrl =
                            (profile['avatar_url'] ?? '').toString();
                        final role = (m['role'] ?? '').toString();

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            child: ClipOval(
                              child: SafeNetworkImage(
                                imageUrl: avatarUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text(
                            name + (isMe ? " (Anda)" : ""),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: role.isEmpty
                              ? null
                              : Text(
                                  role,
                                  style: GoogleFonts.outfit(
                                    color: Colors.grey[700],
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR CHAT] Load members failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal memuat anggota")));
    }
  }

  Future<void> _cacheProfiles(Iterable<String> ids) async {
    final toFetch = ids.where((id) => !_profileCache.containsKey(id)).toSet();
    if (toFetch.isEmpty) return;

    try {
      final data = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .filter('id', 'in', toFetch.toList());

      if (!mounted) return;
      setState(() {
        for (final item in List<Map<String, dynamic>>.from(data)) {
          _profileCache[item['id']?.toString() ?? ''] = item;
        }
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR CHAT] Cache profiles failed: $e\n$st");
      }
    }
  }

  Stream<List<Map<String, dynamic>>> _messagesStream() {
    if (!_chatReady) {
      return const Stream.empty();
    }
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.chatRoomId)
        .order('created_at', ascending: true);
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await _sendMessage(type: 'text', content: text);
  }

  Future<void> _sendMessage({
    String type = 'text',
    required String content,
    String? fallbackType,
    String? fallbackContent,
  }) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    if (content.trim().isEmpty) return;

    if (!_sending) {
      setState(() => _sending = true);
    }

    try {
      final payload = <String, dynamic>{
        'room_id': widget.chatRoomId,
        'sender_id': myId,
        'content': content,
        'type': type,
      };
      await _supabase.from('chat_messages').insert(payload);
    } catch (e, st) {
      if (e is PostgrestException) {
        final message = e.message.toLowerCase();
        if (fallbackType != null && fallbackContent != null) {
          final invalidType = message.contains('check constraint') ||
              message.contains('invalid input value') ||
              message.contains('enum');
          if (invalidType) {
            try {
              final payload = <String, dynamic>{
                'room_id': widget.chatRoomId,
                'sender_id': myId,
                'content': fallbackContent,
                'type': fallbackType,
              };
              await _supabase.from('chat_messages').insert(payload);
              return;
            } catch (_) {}
          }
        }
      }
      if (kDebugMode) {
        debugPrint("[RADAR CHAT] Send failed: $e\n$st");
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Gagal mengirim pesan")));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _playBeebSound() async {
    try {
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      }
      await _audioPlayer.play(AssetSource('beeb.mp3'));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR CHAT] Beeb sound failed: $e\n$st");
      }
    }
  }

  Future<void> _sendBeeb() async {
    _beebAnimController.forward().then((_) => _beebAnimController.reverse());
    HapticFeedback.mediumImpact();
    await _playBeebSound();
    await _sendMessage(
      type: 'beeb',
      content: 'BEEB',
      fallbackType: 'text',
      fallbackContent: '[BEEB]',
    );
  }

  void _showChatActionsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              runSpacing: 10,
              children: [
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: Text(
                    "Anggota",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _memberCount > 0 ? "$_memberCount anggota" : "Lihat anggota grup",
                    style: GoogleFonts.outfit(color: Colors.grey[700]),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMembersSheet();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(
                    "Kirim Foto (Galeri)",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(
                    "Kirim Foto (Kamera)",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(
                    "Kirim Lokasi",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendCurrentLocation();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final ext = picked.path.split('.').last;
      final fileName =
          'radar_${widget.chatRoomId}_${DateTime.now().millisecondsSinceEpoch}_$myId.$ext';

      await _supabase.storage.from('chat-uploads').upload(fileName, file);
      final imageUrl =
          _supabase.storage.from('chat-uploads').getPublicUrl(fileName);

      await _sendMessage(
        type: 'image',
        content: imageUrl,
        fallbackType: 'text',
        fallbackContent: imageUrl,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR CHAT] Pick/send image failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal mengirim foto")));
    }
  }

  Future<void> _sendCurrentLocation() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Izin lokasi ditolak")));
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final url =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      await _sendMessage(
        type: 'location',
        content: url,
        fallbackType: 'text',
        fallbackContent: url,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR CHAT] Send location failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal mengirim lokasi")));
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR CHAT] Open url failed: $e\n$st");
      }
    }
  }

  Widget _buildTextBubble(bool isMe, String content, DateTime? time) {
    final timeText =
        time != null ? timeago.format(time, locale: 'id') : "";
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
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
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
            Text(
              timeText,
              style: GoogleFonts.outfit(
                color: isMe ? Colors.white70 : Colors.black38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeebBubble(bool isMe, DateTime? time) {
    final timeText =
        time != null ? timeago.format(time, locale: 'id') : "";
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _beebPrimary.withValues(alpha: 0.1),
          border: Border.all(color: _beebPrimary.withValues(alpha: 0.5), width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/beep.png', width: 24, height: 24),
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
              timeText,
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

  Widget _buildImageBubble(bool isMe, String imageUrl, DateTime? time) {
    final timeText =
        time != null ? timeago.format(time, locale: 'id') : "";
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
              )
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
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  timeText,
                  style: GoogleFonts.outfit(color: Colors.black38, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBubble(bool isMe, String url, DateTime? time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _openUrl(url),
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
              )
            ],
            border: isMe ? null : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map_rounded, color: Colors.green, size: 28),
              ),
              const SizedBox(width: 10),
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
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundMain,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.church, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _roomTitle,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.surface, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream(),
              builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        if (kDebugMode) {
                          debugPrint(
                            "[RADAR CHAT] Stream error: ${snapshot.error}",
                          );
                        }
                        return Center(
                          child: Text(
                            "Gagal memuat chat.",
                            style: GoogleFonts.outfit(color: Colors.grey[700]),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final myId = _supabase.auth.currentUser?.id;
                      final messages = snapshot.data!;

                      if (messages.isNotEmpty) {
                        final last = messages.last;
                        final lastType = (last['type'] ?? 'text').toString();
                        final lastId = (last['id'] ?? '').toString();
                        final lastSenderId = (last['sender_id'] ?? '').toString();
                        final shouldPlay =
                            lastType == 'beeb' &&
                            lastId.isNotEmpty &&
                            lastId != _lastPlayedBeebId &&
                            myId != null &&
                            lastSenderId != myId;

                        if (shouldPlay) {
                          _lastPlayedBeebId = lastId;
                          Future.microtask(_playBeebSound);
                        }
                      }

                      final senderIds =
                          messages
                              .map((m) => (m['sender_id'] ?? '').toString())
                              .where((id) => id.isNotEmpty)
                              .toSet();
                      if (senderIds.isNotEmpty) {
                        Future.microtask(() => _cacheProfiles(senderIds));
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        }
                      });

                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            "Mulai percakapan...",
                            style: GoogleFonts.outfit(color: Colors.grey[700]),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final senderId = (msg['sender_id'] ?? '').toString();
                          final isMe = myId != null && senderId == myId;
                          final type = (msg['type'] ?? 'text').toString();
                          final content = (msg['content'] ?? '').toString();
                          final createdAtRaw = msg['created_at'];
                          final createdAt =
                              createdAtRaw == null
                                  ? null
                                  : DateTime.tryParse(
                                    createdAtRaw.toString(),
                                  )?.toLocal();

                          final isBeebText = type == 'text' &&
                              (content == '[BEEB]' || content == 'BEEB');
                          if (type == 'beeb' || isBeebText) {
                            return _buildBeebBubble(isMe, createdAt);
                          }
                          if (type == 'image') {
                            return _buildImageBubble(isMe, content, createdAt);
                          }
                          if (type == 'location') {
                            return _buildLocationBubble(isMe, content, createdAt);
                          }
                          return _buildTextBubble(isMe, content, createdAt);
                        },
                      );
              },
            ),
          ),
          _buildInputArea(),
        ],
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
          )
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
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
                      color: _beebBackground,
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
          IconButton(
            icon: Transform.rotate(
              angle: -3.14 / 4,
              child: const Icon(Icons.attach_file, color: AppColors.textSecondary),
            ),
            onPressed: _showChatActionsSheet,
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
            onTap: _sendText,
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
                  )
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
