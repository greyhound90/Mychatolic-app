import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // For BackdropFilter

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String name;

  const ChatDetailPage({super.key, required this.chatId, required this.name});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode(); // For Emoji button logic

  // --- DESIGN SYSTEM CONSTANTS (White UI) ---
  static const Color kBackground = Colors.white;
  static const Color kPrimary = Color(0xFF0088CC);
  static const Color kSecondary = Color(0xFF0088CC); // Primary Blue
  static const Color kCardColor = Colors.white;



  
  static const Color kBubbleIncoming = Color(0xFFF1F5F9); // Slate 100
  static const Color kBorder = Color(0xFFE2E8F0); // Slate 200
  
  static const Color kTextTitle = Color(0xFF0F172A);
  static const Color kTextBody = Color(0xFF334155);
  static const Color kTextMeta = Color(0xFF64748B);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [kSecondary, kPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bubbleGradient = LinearGradient(
    colors: [kSecondary, kPrimary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // DUMMY MESSAGES (Preserved Logic)
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Suster, apakah jadwal misa jam 5 masih ada slot?', 'isMe': true, 'time': '09:00'},
    {'text': 'Sebentar saya cek dulu ya.', 'isMe': false, 'time': '09:02'},
    {'text': 'Masih ada, silakan bawa buku puji syukur ya.', 'isMe': false, 'time': '09:05'},
    {'text': 'Siap Suster, terima kasih infonya! 🙏', 'isMe': true, 'time': '09:10'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }
  
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent, 
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeOut
      );
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    
    setState(() {
      _messages.add({
        'text': _messageController.text.trim(),
        'isMe': true,
        'time': "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}"
      });
      _messageController.clear();
    });
    
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      resizeToAvoidBottomInset: true, // Allow input to float up
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Bottom padding for Input Bar
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
              ),
            ],
          ),
          
          // --- FLOATING GLASS INPUT BAR ---
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildInputBar(),
          )
        ],
      ),
      // NO FAB (Removed per request)
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kTextTitle.withValues(alpha: 0.8),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: primaryGradient,
            ),
            child: CircleAvatar(
              radius: 18, 
              backgroundColor: kBackground, 
              child: Text(
                widget.name.isNotEmpty ? widget.name[0] : "?", 
                style: GoogleFonts.outfit(fontSize: 16, color: kTextBody, fontWeight: FontWeight.bold)
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name, style: GoogleFonts.outfit(color: kTextTitle, fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)), // Green Dot
                    const SizedBox(width: 6),
                    Text("Online", style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      actions: [
        // Glass Style Actions
        _buildGlassActionIcon(Icons.videocam_rounded),
        const SizedBox(width: 8),
        _buildGlassActionIcon(Icons.call_rounded),
        const SizedBox(width: 16),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kBorder, height: 1),
      ),
    );
  }

  Widget _buildGlassActionIcon(IconData icon) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: kCardColor, 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Icon(icon, color: kTextBody, size: 20),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isMe = msg['isMe'] as bool;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isMe ? bubbleGradient : null,
            color: isMe ? null : kBubbleIncoming, 
            border: isMe ? null : Border.all(color: kBorder),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(20),
            ),
            boxShadow: [
               if (isMe) 
                 BoxShadow(
                   color: kSecondary.withValues(alpha: 0.3), 
                   blurRadius: 12, 
                   offset: const Offset(0, 4)
                 )
            ]
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                msg['text'], 
                style: GoogleFonts.outfit(
                  color: isMe ? Colors.white : kTextTitle, 
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.4
                )
              ),
              const SizedBox(height: 4),
              Text(
                msg['time'], 
                style: GoogleFonts.outfit(
                  color: isMe ? Colors.white70 : kTextMeta,
                  fontSize: 10,
                  fontWeight: FontWeight.w500
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: kCardColor, 
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            children: [
              // Prefix: Emoji Icon (Functional)
              IconButton(
                onPressed: () => FocusScope.of(context).requestFocus(_focusNode),
                icon: const Icon(Icons.emoji_emotions_outlined, color: kTextMeta),
                tooltip: "Emoji",
              ),
              
              // Text Field
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  style: GoogleFonts.outfit(color: kTextTitle),
                  minLines: 1,
                  maxLines: 4,
                  cursorColor: kPrimary,
                  decoration: InputDecoration(
                    hintText: "Ketik pesan...",
                    hintStyle: GoogleFonts.outfit(color: kTextMeta),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // SEND BUTTON (Circle Gradient)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      gradient: primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
