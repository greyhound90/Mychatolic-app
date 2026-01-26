import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'package:mychatolic_app/core/theme.dart';

class ChatDetailPage extends StatefulWidget {
  final String chatId; // String UUID
  final String? partnerId; // Optional UUID for creating private chat
  final String name;

  const ChatDetailPage({
    super.key, 
    required this.chatId, 
    this.partnerId,
    required this.name
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _activeRoomId;
  String? _currentUserId;
  String _chatName = ""; // Dynamic name
  bool _isLoading = true;

  // --- DESIGN SYSTEM CONSTANTS ---
  static const Color kPrimary = Color(0xFF0088CC);
  static const Color kBubbleIncoming = Color(0xFFF1F5F9); // Slate 100
  static const Color kBorder = Color(0xFFE2E8F0); 
  static const Color kTextTitle = Color(0xFF0F172A);
  static const Color kTextBody = Color(0xFF334155);
  static const Color kTextMeta = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    _chatName = widget.name; // Default to passed name
    _initializeChatRoom();
  }

   Future<void> _initializeChatRoom() async {
    // Skenario A: Masuk via Partner ID (Dari Profil)
    // Panggil RPC database untuk mencari room lama kita berdua.
    if (widget.partnerId != null) {
      if (_currentUserId == null) return;
      
      try {
        // Ambil Nama Partner untuk Judul AppBar
        final profile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', widget.partnerId!)
            .maybeSingle();
            
        if (profile != null && mounted) {
           setState(() => _chatName = profile['full_name']);
        }

        // PANGGIL RPC DATABASE (Cari Room Lama)
        final roomId = await _supabase.rpc('get_or_create_private_chat', params: {
          'target_user_id': widget.partnerId,
        });

        if (mounted) {
          setState(() {
            _activeRoomId = roomId.toString();
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error loading chat: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    } 
    // Skenario B: Masuk via List Chat (Sudah bawa Room ID)
    else {
      setState(() {
        _activeRoomId = widget.chatId; // Gunakan ID yang dikirim dari list
        _isLoading = false;
      });
    }
  }

  // --- ACTIONS ---

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _activeRoomId == null || _currentUserId == null) return;

    _messageController.clear();
    
    try {
      await _supabase.from('chat_messages').insert({
        'room_id': _activeRoomId,
        'sender_id': _currentUserId,
        'content': text,
        // 'message_type': 'TEXT', // Default
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Send Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengirim pesan")));
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: kTextTitle,
      elevation: 0,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: kPrimary.withValues(alpha: 0.1),
            child: Text(
               _chatName.isNotEmpty ? _chatName[0] : 'U',
               style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold)
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _chatName,
                  style: GoogleFonts.outfit(
                      color: kTextTitle, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Online", // Or fetch status from presence if implemented
                  style: GoogleFonts.outfit(color: kTextMeta, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kBorder, height: 1),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeRoomId == null) {
      return const Center(child: Text("Gagal memuat ruang obrolan."));
    }

    return Column(
      children: [
        // MESSAGE LIST
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('chat_messages')
                .stream(primaryKey: ['id'])
                .eq('room_id', _activeRoomId!)
                .order('created_at', ascending: true),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!;
              if (messages.isEmpty) {
                return Center(child: Text("Belum ada pesan.", style: GoogleFonts.outfit(color: kTextMeta)));
              }

              // Auto scroll on new data
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg['sender_id'] == _currentUserId;
                  return _buildMessageBubble(msg, isMe);
                },
              );
            },
          ),
        ),

        // INPUT BAR
        _buildInputBar(),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final content = msg['content'] ?? '';
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
    final timeStr = "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? kPrimary : kBubbleIncoming,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: GoogleFonts.outfit(
                color: isMe ? Colors.white : kTextTitle,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: GoogleFonts.outfit(
                color: isMe ? Colors.white70 : kTextMeta,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Ketik pesan...",
                hintStyle: GoogleFonts.outfit(color: kTextMeta),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: kBubbleIncoming,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send_rounded, color: kPrimary),
            style: IconButton.styleFrom(
              backgroundColor: kPrimary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
