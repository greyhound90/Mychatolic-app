import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mychatolic_app/core/app_colors.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/services/chat_service.dart';
import 'package:mychatolic_app/features/profile/pages/profile_page.dart';
import 'package:mychatolic_app/features/social/group_info_page.dart';

class SocialChatDetailPage extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> opponentProfile;
  final String? otherUserId;
  final bool isGroup;

  const SocialChatDetailPage({
    super.key,
    required this.chatId,
    required this.opponentProfile,
    this.otherUserId,
    this.isGroup = false,
  });

  @override
  State<SocialChatDetailPage> createState() => _SocialChatDetailPageState();
}

class _SocialChatDetailPageState extends State<SocialChatDetailPage> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _uiAudioPlayer = AudioPlayer();

  // Recorder states
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isRecorderInitialised = false; // Stability Flag
  DateTime? _recordStartTime; // Duration Check
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  double _dragOffset = 0.0;

  // Animation Controllers
  late AnimationController _micScaleController;
  late AnimationController _trashScaleController;

  // Channel untuk Realtime
  late RealtimeChannel _roomChannel;

  static const Color kPrimaryBlue = Color(0xFF0088CC);
  static const Color kSurface = Color(0xFFFFFFFF);

  Map<String, String> _groupMemberNames = {};
  Map<String, dynamic>? _replyMessage;    
  String? _editingMessageId;              

  // State Status
  bool _isOpponentOnline = false;
  bool _isOpponentTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
    _subscribeToPresence();
    _chatService.markMessagesAsRead(widget.chatId);
    if (widget.isGroup) {
      _fetchGroupMembers();
    }

    _micScaleController = AnimationController(
       vsync: this, 
       duration: const Duration(milliseconds: 500),
       lowerBound: 1.0,
       upperBound: 1.3,
    )..repeat(reverse: true);

    _trashScaleController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 200),
      lowerBound: 1.0,
      upperBound: 1.5,
    );
  }

  @override
  void dispose() {
    _supabase.removeChannel(_roomChannel);
    _uiAudioPlayer.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _micScaleController.dispose();
    _trashScaleController.dispose();
    super.dispose();
  }

  Future<void> _fetchGroupMembers() async {
    try {
      final res = await _supabase.from('chat_members').select('user_id, profiles(full_name)').eq('chat_id', widget.chatId);
      if (mounted) {
        final Map<String, String> names = {};
        for (var item in res as List<dynamic>) {
           final uid = item['user_id'] as String;
           final profile = item['profiles'];
           if (profile != null) names[uid] = profile['full_name'] ?? 'Anggota';
        }
        setState(() => _groupMemberNames = names);
      }
    } catch (e) { debugPrint("Error members: $e"); }
  }

  void _subscribeToMessages() {
    final myId = _supabase.auth.currentUser?.id;
    _supabase.channel('public:social_messages:chat_id=${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, schema: 'public', table: 'social_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'chat_id', value: widget.chatId),
          callback: (payload) {
            if (!mounted) return;
            if (payload.eventType == PostgresChangeEvent.insert) {
              final newMsg = payload.newRecord;
              if (newMsg['type'] == 'beeb' && newMsg['sender_id'] != myId) {
                 _playUiSound();
                 HapticFeedback.heavyImpact(); 
              }
              if (newMsg['sender_id'] != myId && newMsg['is_read'] == false) {
                 _supabase.from('social_messages').update({'is_read': true}).match({'id': newMsg['id']}).then((_) {});
              }
            }
            setState(() {}); 
          },
        ).subscribe();
  }

  void _subscribeToPresence() {
    final myId = _supabase.auth.currentUser?.id;
    _roomChannel = _supabase.channel('room_${widget.chatId}');
    _roomChannel.onPresenceSync((payload) {
        if (!mounted) return;
        final opponentId = widget.opponentProfile['id'];
        bool found = false;
        try {
          final state = _roomChannel.presenceState();
          for (final presence in state) {
            final pStr = presence.toString();
            if (pStr.contains(opponentId)) { found = true; break; }
          }
        } catch (e) { debugPrint("Presence Err: $e"); }
        setState(() => _isOpponentOnline = found);
      })
      .onBroadcast(event: 'typing', callback: (payload) {
        final senderId = payload['user_id'];
        if (senderId != myId) {
          setState(() => _isOpponentTyping = true);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () { if (mounted) setState(() => _isOpponentTyping = false); });
        }
      })
      .subscribe((status, error) async {
         if (status == RealtimeSubscribeStatus.subscribed) {
           await _roomChannel.track({'user_id': myId, 'online_at': DateTime.now().toIso8601String()});
         }
      });
  }

  void _onTypingChanged(String value) {
    final myId = _supabase.auth.currentUser?.id;
    _roomChannel.sendBroadcastMessage(event: 'typing', payload: {'user_id': myId});
  }

  Future<void> _playUiSound() async {
    try {
      if (_uiAudioPlayer.state == PlayerState.playing) await _uiAudioPlayer.stop();
      await _uiAudioPlayer.play(AssetSource('beeb.mp3'));
    } catch (e) {}
  }

  String _getSenderName(String senderId) {
    final myId = _supabase.auth.currentUser?.id;
    if (senderId == myId) return "Anda";
    if (widget.isGroup) return _groupMemberNames[senderId] ?? 'Anggota';
    return widget.opponentProfile['full_name'] ?? 'User';
  }

  void _showOptions(Map<String, dynamic> msg, bool isMe) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (isMe && msg['type'] == 'text') ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: Text("Edit Pesan", style: GoogleFonts.outfit(color: Colors.blue)), onTap: () { Navigator.pop(context); _startEdit(msg); }),
            if (isMe) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: Text("Hapus Pesan", style: GoogleFonts.outfit(color: Colors.red)), onTap: () { Navigator.pop(context); _confirmDelete(msg['id']); }),
            if (!isMe) const Padding(padding: EdgeInsets.all(16.0), child: Text("Tidak ada opsi.")),
    ])));
  }

  void _startEdit(Map<String, dynamic> msg) {
    setState(() { _editingMessageId = msg['id']; _textController.text = msg['content']; _replyMessage = null; });
    _focusNode.requestFocus(); 
  }

  void _cancelEdit() {
    setState(() { _editingMessageId = null; _textController.clear(); });
    _focusNode.unfocus();
  }

  void _confirmDelete(String msgId) {
    showDialog(context: context, builder: (context) => AlertDialog(
        title: const Text("Hapus Pesan?"), content: const Text("Permanen."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")), TextButton(onPressed: () { Navigator.pop(context); _deleteMessage(msgId); }, child: const Text("Hapus", style: TextStyle(color: Colors.red)))]
    ));
  }

  Future<void> _deleteMessage(String msgId) async {
    try {
      await _supabase.from('social_messages').delete().eq('id', msgId);
      final res = await _supabase.from('social_messages').select().eq('chat_id', widget.chatId).order('created_at', ascending: false).limit(1).maybeSingle();
      String newLastMsg = "Belum ada pesan"; 
      String newUpdatedAt = DateTime.now().toIso8601String();
      if (res != null) {
         newUpdatedAt = res['created_at'];
         final t = res['type'];
         if (t=='beeb') newLastMsg='👋 BEEB!'; else if(t=='image') newLastMsg='📷 Gambar'; else if(t=='location') newLastMsg='📍 Lokasi'; else if(t=='audio') newLastMsg='🎤 Pesan Suara'; else newLastMsg=res['content']??'';
      }
      await _supabase.from('social_chats').update({'last_message': newLastMsg, 'updated_at': newUpdatedAt}).eq('id', widget.chatId);
    } catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Err: $e"))); }
  }

  void _onSwipeToReply(Map<String, dynamic> msg) {
    HapticFeedback.lightImpact();
    setState(() { _replyMessage = msg; _editingMessageId = null; });
    _focusNode.requestFocus();
  }

  void _cancelReply() { setState(() => _replyMessage = null); }

  void _showAttachmentSheet() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(24),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _buildMenuIcon(Icons.camera_alt, "Kamera", Colors.pink, () { Navigator.pop(context); _handleAttachment(ImageSource.camera); }),
            _buildMenuIcon(Icons.photo, "Galeri", Colors.purple, () { Navigator.pop(context); _handleAttachment(ImageSource.gallery); }),
            _buildMenuIcon(Icons.location_on, "Lokasi", Colors.green, () { Navigator.pop(context); _handleLocation(); }),
    ])));
  }

  Widget _buildMenuIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.1)), child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 8), Text(label, style: GoogleFonts.outfit(color: Colors.black)),
    ]));
  }

  Future<void> _handleAttachment(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) return;
      final file = File(picked.path);
      final myId = _supabase.auth.currentUser?.id;
      final path = 'chat_${DateTime.now().millisecondsSinceEpoch}_$myId.${picked.path.split('.').last}';
      await _supabase.storage.from('chat-uploads').upload(path, file);
      final url = _supabase.storage.from('chat-uploads').getPublicUrl(path);
      _sendMessage(type: 'image', content: url);
    } catch (e) { debugPrint("Upload Err: $e"); }
  }

  Future<void> _handleLocation() async {
    try {
      if (await Permission.location.request().isGranted) {
        final pos = await Geolocator.getCurrentPosition();
        final url = 'http://googleusercontent.com/maps.google.com/maps?q=${pos.latitude},${pos.longitude}';
        _sendMessage(type: 'location', content: url);
      }
    } catch (e) {}
  }

  // --- RECORDING LOGIC ---

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        HapticFeedback.mediumImpact();
        
        // Optimistic UI update
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
          _dragOffset = 0.0;
        });

        _isRecorderInitialised = false; // Reset flag before start
        _recordStartTime = DateTime.now();

        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        // Start Native Recorder
        await _audioRecorder.start(const RecordConfig(), path: path);
        
        _isRecorderInitialised = true; // Mark as successfully started

        // Start Timer
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) setState(() => _recordingDuration++);
        });
      }
    } catch (e) {
      debugPrint("Rec Err: $e");
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    
    // Safety check: Don't try to stop if it hasn't finished starting
    if (!_isRecorderInitialised) {
       _cancelRecording(); 
       return;
    }

    // Safety check: Min Duration (Anti-Crash & Anti-Spam)
    final durationMs = DateTime.now().difference(_recordStartTime ?? DateTime.now()).inMilliseconds;
    if (durationMs < 600) {
      // If less than 600ms, consider it a tap or mistake.
      _cancelRecording();
      return;
    }

    try {
      final path = await _audioRecorder.stop();
      _cleanupRecorderState();
      
      if (path != null) {
        // Upload
        final file = File(path);
        final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        try {
           await _supabase.storage.from('voice-notes').upload(fileName, file);
           final url = _supabase.storage.from('voice-notes').getPublicUrl(fileName);
           _sendMessage(type: 'audio', content: url);
        } catch (storageErr) {
           debugPrint("Storage Err: $storageErr");
           String errorMsg = "Gagal upload Voice Note";
           if (storageErr.toString().contains("Bucket not found") || storageErr.toString().contains("404")) {
             errorMsg = "Error: Bucket 'voice-notes' belum dibuat di Supabase Dashboard";
           }
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      debugPrint("Stop Rec Err: $e");
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    
    _cleanupRecorderState(); // Reset UI first

    // Stop hardware if initialized
    if (_isRecorderInitialised) {
      try {
        final path = await _audioRecorder.stop();
        if (path != null) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      } catch (e) {
        debugPrint("Cancel/Stop Err: $e");
      }
    }
    
    _isRecorderInitialised = false; 
    HapticFeedback.lightImpact();
  }

  void _cleanupRecorderState() {
     _recordingTimer?.cancel();
     setState(() {
       _isRecording = false;
       _recordingDuration = 0;
       _dragOffset = 0.0;
     });
     // Reset Trash Animation
     if (_trashScaleController.isCompleted) _trashScaleController.reverse();
  }

  void _handleDragUpdate(LongPressMoveUpdateDetails details) {
    if (!_isRecording) return;
    
    // Use offsetFromOrigin for consistent relative drag from touch point
    final offset = details.offsetFromOrigin.dx;

    setState(() {
      _dragOffset = offset;
    });

    // Tuning Thresholds
    // Cancel: -50 (Easier to cancel)
    // Warning: -25 (Early warning)
    if (offset < -50) {
      _cancelRecording();
    } else if (offset < -25) {
       // "Will Cancel" Zone
      if (!_trashScaleController.isAnimating && _trashScaleController.status != AnimationStatus.completed) {
         HapticFeedback.mediumImpact(); 
         _trashScaleController.forward();
      }
    } else {
       // Safe Zone
       if (_trashScaleController.status == AnimationStatus.completed) {
         _trashScaleController.reverse();
       }
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  // ---------------------------

  Future<void> _sendBeeb() async {
    HapticFeedback.mediumImpact(); _playUiSound(); _sendMessage(type: 'beeb', content: 'BEEB');
  }

  Future<void> _sendMessage({String type = 'text', String? content}) async {
    final text = content ?? _textController.text.trim();
    if (text.isEmpty) return;
    
    if (type == 'text') _textController.clear();

    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      if (_editingMessageId != null) {
        await _supabase.from('social_messages').update({
          'content': text,
          'is_edited': true, 
        }).eq('id', _editingMessageId!);
        _cancelEdit(); 
        return; 
      }

      Map<String, dynamic>? replyData;
      if (_replyMessage != null) {
        final senderName = _getSenderName(_replyMessage!['sender_id']);
        replyData = {
          'id': _replyMessage!['id'],
          'sender_name': senderName,
          'content': _replyMessage!['content'],
          'type': _replyMessage!['type']
        };
      }

      await _supabase.from('social_messages').insert({
        'chat_id': widget.chatId,
        'sender_id': myId,
        'content': text,
        'type': type,
        'reply_context': replyData,
        'is_edited': false,
      });

      if (_replyMessage != null) _cancelReply();

      String summaryMsg = text;
      if (type == 'beeb') summaryMsg = '👋 BEEB!';
      else if (type == 'image') summaryMsg = '📷 Mengirim gambar';
      else if (type == 'location') summaryMsg = '📍 Lokasi';
      else if (type == 'audio') summaryMsg = '🎤 Pesan Suara';
      
      final Map<String, dynamic> updateData = {
        'updated_at': DateTime.now().toIso8601String(),
        'last_message': summaryMsg
      };
      
      if (!widget.isGroup) {
        updateData['participants'] = [myId, widget.opponentProfile['id']];
      }
      
      await _supabase.from('social_chats').update(updateData).eq('id', widget.chatId);
      // _scrollToBottom(); // Not needed with reverse list
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal kirim: $e")));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }); 
  }

  void _showDialogImage(String imageUrl) {
    showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: SafeNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Color(0xFFF3E5F5)], // Soft Blue to Purple Pastel
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(child: _buildMessageList()),
              _buildFloatingInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar() {
    final name = widget.isGroup ? widget.opponentProfile['group_name'] : widget.opponentProfile['full_name'] ?? "User";
    String? avatar;
    if (widget.isGroup) {
      avatar = widget.opponentProfile['group_avatar_url'] ?? widget.opponentProfile['avatar_url'];
    } else {
      avatar = widget.opponentProfile['avatar_url'];
    }

    return AppBar(
      backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.black, leading: const BackButton(),
      flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.white.withOpacity(0.7)))),
      title: GestureDetector(
        onTap: () {
          if (widget.isGroup) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoPage(chatId: widget.chatId)));
          } else {
            final uid = widget.otherUserId ?? widget.opponentProfile['id'];
            if (uid != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: uid, isBackButtonEnabled: true)));
          }
        },
        child: Row(
          children: [
            SafeNetworkImage(
              key: ValueKey(avatar), 
              imageUrl: avatar, 
              width: 38, height: 38, 
              borderRadius: BorderRadius.circular(50), 
              fit: BoxFit.cover, 
              fallbackIcon: widget.isGroup ? Icons.groups : Icons.person
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(name, style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                  if (_isOpponentTyping)
                    Text("sedang mengetik...", style: GoogleFonts.outfit(color: kPrimaryBlue, fontSize: 12, fontStyle: FontStyle.italic))
                  else if (_isOpponentOnline && !widget.isGroup)
                    Text("Online", style: GoogleFonts.outfit(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    final myId = _supabase.auth.currentUser?.id;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('social_messages').stream(primaryKey: ['id']).eq('chat_id', widget.chatId).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final msgs = snapshot.data!;
        if (msgs.isEmpty) return Center(child: Text("Mulai percakapan...", style: GoogleFonts.outfit(color: Colors.grey)));
        
        return ListView.builder(
          reverse: true, // Newest at bottom visually
          controller: _scrollController, 
          padding: const EdgeInsets.fromLTRB(16, 120, 16, 20),
          itemCount: msgs.length,
          itemBuilder: (context, index) {
            final msg = msgs[index];
            final isMe = msg['sender_id'] == myId;
            bool showDate = false;
            if (index == msgs.length - 1) {
               showDate = true;
            } else {
               final curr = DateTime.parse(msg['created_at']).toLocal();
               final prev = DateTime.parse(msgs[index + 1]['created_at']).toLocal(); 
               if (curr.day != prev.day) showDate = true;
            }

            return Column(children: [
              if (showDate) _buildDateHeader(msg['created_at']),
              GestureDetector(
                onLongPress: () => _showOptions(msg, isMe), 
                child: Dismissible(
                  key: Key(msg['id']),
                  direction: DismissDirection.startToEnd,
                  dismissThresholds: const {DismissDirection.startToEnd: 0.15},
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    color: Colors.transparent,
                    child: Icon(Icons.reply, color: Colors.grey[600], size: 30),
                  ),
                  confirmDismiss: (dir) async { _onSwipeToReply(msg); return false; },
                  child: _buildAnimatedBubble(msg, isMe),
                ),
              )
            ]);
          },
        );
      },
    );
  }

  Widget _buildDateHeader(String dateStr) {
    final date = DateTime.parse(dateStr).toLocal();
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: ShapeDecoration(
          color: Colors.white.withOpacity(0.5), // Glassmorphism Date
          shape: const StadiumBorder(),
          shadows: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
        ),
        child: ClipRRect(
           borderRadius: BorderRadius.circular(20),
           child: BackdropFilter(
             filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
             child: Padding(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               child: Text(
                 DateFormat('dd MMM yyyy').format(date), 
                 style: GoogleFonts.outfit(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)
               ),
             ),
           ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBubble(Map<String, dynamic> msg, bool isMe) {
    final type = msg['type'] ?? 'text';
    final content = msg['content'] ?? '';
    final time = msg['created_at'];
    final reply = msg['reply_context'];
    final isEdited = msg['is_edited'] == true; 
    final isRead = msg['is_read'] == true;

    Widget bubbleContent;
    if (type == 'beeb') {
      bubbleContent = Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          BeebBubble(isMe: isMe),
          const SizedBox(height: 4),
          _buildTimestampWithTick(time, isMe, isRead),
        ],
      );
    }
    else if (type == 'image') {
      bubbleContent = Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _buildImageBubble(isMe, content, time),
           const SizedBox(height: 4),
          _buildTimestampWithTick(time, isMe, isRead),
        ],
      );
    }
    else if (type == 'location') {
       bubbleContent = Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _buildLocationBubble(isMe, content),
          const SizedBox(height: 4),
          _buildTimestampWithTick(time, isMe, isRead),
        ],
      );
    }
    else if (type == 'audio') {
      bubbleContent = Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _AudioPlayerBubble(url: content, isMe: isMe),
          const SizedBox(height: 4),
          _buildTimestampWithTick(time, isMe, isRead),
        ],
      );
    }
    else {
      bubbleContent = _buildTextBubble(isMe, content, time, isEdited, isRead); 
    } 

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12), // Spacing between bubbles
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (widget.isGroup && !isMe)
               Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 2),
                  child: Text(
                    _groupMemberNames[msg['sender_id']] ?? 'Anggota',
                    style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[600]),
                  ),
               ),

            if (reply != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: kPrimaryBlue, width: 4))
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reply['sender_name'] ?? 'User', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: kPrimaryBlue)),
                    Text(reply['content'] ?? '...', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
            bubbleContent,
          ],
        ),
      ),
    );
  }

  Widget _buildTextBubble(bool isMe, String content, String? timeStr, bool isEdited, bool isRead) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Comfortable padding
      decoration: BoxDecoration(
        gradient: isMe 
           ? const LinearGradient(colors: [Color(0xFF0088CC), Color(0xFF2575FC)]) // Sender Gradient
           : null, 
        color: isMe ? null : Colors.white, // Receiver White
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(isMe ? 0.2 : 0.05), blurRadius: 4, offset: const Offset(0, 2))
        ],
        borderRadius: BorderRadius.circular(20).copyWith(
          bottomRight: isMe ? Radius.zero : const Radius.circular(20),
          bottomLeft: !isMe ? Radius.zero : const Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            content, 
            style: GoogleFonts.outfit(
              color: isMe ? Colors.white : Colors.black87, // High contrast
              fontSize: 15,
              height: 1.4,
            )
          ), 
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEdited)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text("(edit)", style: GoogleFonts.outfit(color: isMe ? Colors.white70 : Colors.grey, fontSize: 10, fontStyle: FontStyle.italic)),
                ),
              _buildTimestampWithTick(timeStr, isMe, isRead, isTextBubble: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampWithTick(String? timeStr, bool isMe, bool isRead, {bool isTextBubble = false}) {
    final time = timeStr != null ? DateFormat('HH:mm').format(DateTime.parse(timeStr).toLocal()) : '';
    final color = (isMe && isTextBubble) ? Colors.white70 : Colors.grey;
    final iconColor = isRead ? Colors.lightBlueAccent : ((isMe && isTextBubble) ? Colors.white70 : Colors.grey);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(time, style: GoogleFonts.outfit(color: color, fontSize: 10)),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.done_all, 
            size: 14, 
            color: iconColor
          ),
        ]
      ],
    );
  }

  Widget _buildImageBubble(bool isMe, String url, String? time) {
    return GestureDetector(
      onTap: () => _showDialogImage(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SafeNetworkImage(imageUrl: url, width: 220, height: 280, fit: BoxFit.cover),
      ),
    );
  }
  
  Widget _buildLocationBubble(bool isMe, String url) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.location_on, color: Colors.red),
          const SizedBox(width: 8),
          Text("Lihat Lokasi", style: GoogleFonts.outfit(color: Colors.blue, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildFloatingInputArea() {
    // -------------------------------------------------------------
    // RECORDING UI
    // -------------------------------------------------------------
    if (_isRecording) {
      final isDangerZone = _dragOffset < -25; // Visual Warning at -25
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10)]
        ),
        child: Row(
          children: [
            // Trash Icon
            ScaleTransition(
              scale: _trashScaleController,
              child: Icon(Icons.delete_outline, color: isDangerZone ? Colors.red : Colors.grey, size: 28),
            ),
            
            // Duration & Slide Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      _formatDuration(_recordingDuration), 
                      style: GoogleFonts.outfit(color: isDangerZone ? Colors.red : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isDangerZone ? "Lepas untuk batal" : "< Geser untuk membatalkan", 
                        style: GoogleFonts.outfit(color: isDangerZone ? Colors.red : Colors.grey, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Blinking Mic Icon
            ScaleTransition(
               scale: _micScaleController,
               child: _gestureMicIcon(),
            )
          ],
        ),
      );
    }
    
    // -------------------------------------------------------------
    // NORMAL INPUT UI
    // -------------------------------------------------------------
    return Container(
      margin: const EdgeInsets.all(16), // Floating Margin
      decoration: BoxDecoration(
         color: kSurface, 
         borderRadius: BorderRadius.circular(30), // Capsule Shape
         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          if (_replyMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
              child: Row(
                children: [
                  Container(width: 4, height: 40, color: kPrimaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Membalas ke ${_getSenderName(_replyMessage!['sender_id'])}", style: GoogleFonts.outfit(color: kPrimaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(_replyMessage!['content'] ?? 'Media', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: Colors.grey[700], fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: _cancelReply),
                ],
              ),
            ),
          
          if (_editingMessageId != null)
             Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.blue, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text("Sedang mengedit pesan...", style: GoogleFonts.outfit(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.blue), onPressed: _cancelEdit),
                ],
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                 IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.grey), onPressed: _showAttachmentSheet),
                 Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    onChanged: _onTypingChanged,
                    decoration: const InputDecoration(hintText: "Tulis pesan...", border: InputBorder.none),
                  ),
                ),
                
                // MIC BUTTON (GESTURE)
                _gestureMicIcon(),

                if (!_isRecording) 
                  GestureDetector(
                    onTap: _sendBeeb, 
                    onLongPress: _sendBeeb, 
                    child: Padding(
                      padding: const EdgeInsets.all(8.0), 
                      child: Image.asset('assets/beep.png', width: 28, height: 28)
                    )
                  ),
                
                if (!_isRecording && _textController.text.isNotEmpty)
                   IconButton(
                     icon: Icon(_editingMessageId != null ? Icons.check : Icons.send, color: kPrimaryBlue), 
                     onPressed: () => _sendMessage(type: 'text')
                   ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gestureMicIcon() {
    return GestureDetector(
      onLongPress: _startRecording,
      onLongPressMoveUpdate: _handleDragUpdate, // TRIGGER SLIDE TO CANCEL
      onLongPressUp: _stopRecordingAndSend,
      onLongPressEnd: (details) {
         if (_isRecording) _stopRecordingAndSend();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: _isRecording ? const BoxDecoration(shape: BoxShape.circle, color: Colors.red) : null,
        child: Icon(Icons.mic, color: _isRecording ? Colors.white : Colors.grey, size: 28),
      ),
    );
  }
}

class BeebBubble extends StatefulWidget {
  final bool isMe;
  const BeebBubble({super.key, required this.isMe});

  @override
  State<BeebBubble> createState() => _BeebBubbleState();
}

class _BeebBubbleState extends State<BeebBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final AudioPlayer _player = AudioPlayer();
  static const Color kBeebColor = Color(0xFFFF2D55); 

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  void _triggerEffect() async {
    _controller.forward(from: 0.0).then((_) => _controller.reset());
    try {
      if (_player.state == PlayerState.playing) await _player.stop();
      await _player.play(AssetSource('beeb.mp3'));
      HapticFeedback.heavyImpact(); 
    } catch (e) { debugPrint("Sound Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerEffect,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double offset = sin(_controller.value * 10 * pi) * 6; 
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE4E9),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC2185B).withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Image.asset('assets/beep.png', width: 18, height: 18), 
              const SizedBox(width: 6),
              Text(
                "BEEB!", 
                style: GoogleFonts.outfit(
                  color: const Color(0xFFC2185B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13, 
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioPlayerBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  const _AudioPlayerBubble({required this.url, required this.isMe});

  @override
  State<_AudioPlayerBubble> createState() => _AudioPlayerBubbleState();
}

class _AudioPlayerBubbleState extends State<_AudioPlayerBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _formatDual(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${d.inMinutes}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe ? const Color(0xFF0088CC).withOpacity(0.1) : const Color(0xFFF5F5F5), // Softer background for audio
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isMe ? const Color(0xFF0088CC).withOpacity(0.3) : Colors.transparent)
      ),
      width: 240, // Fixed width for consistent look
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play Button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0088CC), // Primary
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Slider
                SizedBox(
                  height: 24,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                      activeTrackColor: const Color(0xFF0088CC),
                      inactiveTrackColor: Colors.grey[300],
                      thumbColor: const Color(0xFF0088CC)
                    ),
                    child: Slider(
                      value: (_position.inSeconds.toDouble()).clamp(0.0, (_duration.inSeconds.toDouble() + 0.1)),
                      max: _duration.inSeconds.toDouble() + 0.1, // Avoid div by zero visual
                      onChanged: (val) {
                         _player.seek(Duration(seconds: val.toInt()));
                      },
                    ),
                  ),
                ),
                // Time Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDual(_position), style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[600])),
                      Text(_formatDual(_duration), style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}