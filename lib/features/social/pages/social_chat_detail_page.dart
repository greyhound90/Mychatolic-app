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
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mychatolic_app/core/ui/app_state.dart';
import 'package:mychatolic_app/core/ui/app_state_view.dart';
import 'package:mychatolic_app/core/ui/app_snackbar.dart';
import 'package:mychatolic_app/core/log/app_logger.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/core/ui/permission_prompt.dart';
import 'package:mychatolic_app/core/analytics/analytics_service.dart';
import 'package:mychatolic_app/core/analytics/analytics_events.dart';
import 'package:mychatolic_app/services/chat_service.dart';
import 'package:mychatolic_app/features/profile/pages/profile_page.dart';
import 'package:mychatolic_app/features/social/group_info_page.dart';

class SocialChatDetailPage extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> opponentProfile;
  final String? otherUserId;
  final bool isGroup;
  final String source;

  const SocialChatDetailPage({
    super.key,
    required this.chatId,
    required this.opponentProfile,
    this.otherUserId,
    this.isGroup = false,
    this.source = 'chat_list',
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
  
  Map<String, String> _groupMemberNames = {};
  Map<String, dynamic>? _replyMessage;    
  String? _editingMessageId;              

  // State Status
  bool _isOpponentOnline = false;
  bool _isOpponentTyping = false;
  Timer? _typingTimer;

  bool _initialScrollDone = false;
  static const int _pageSize = 40;
  final List<Map<String, dynamic>> _messages = [];
  final Set<String> _messageIds = {};
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _isNearBottom = true;
  bool _hasNewMessageWhileAway = false;
  bool _isSending = false;
  String? _messageError;
  DateTime? _oldestCreatedAt;

  RealtimeChannel? _messageChannel;
  final Set<String> _animatedMessageIds = {};

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.track(
      AnalyticsEvents.chatOpen,
      props: {'source': widget.source},
    );
    _scrollController.addListener(_handleScroll);
    _loadInitialMessages();
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
    if (_messageChannel != null) {
      _supabase.removeChannel(_messageChannel!);
    }
    // Be careful with listener removal if storing subscription object
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
        safeSetState(() => _groupMemberNames = names);
      }
    } catch (e, st) {
      AppLogger.logError("Error members", error: e, stackTrace: st);
    }
  }

  void _subscribeToMessages() {
    final myId = _supabase.auth.currentUser?.id;
    _messageChannel =
        _supabase.channel('public:social_messages:chat_id=${widget.chatId}');
    _messageChannel!
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
            if (!mounted) return;
            final newMsg = Map<String, dynamic>.from(payload.newRecord);
            final msgId = newMsg['id']?.toString();
            if (msgId == null || _messageIds.contains(msgId)) return;

            safeSetState(() {
              _messageIds.add(msgId);
              _messages.add(newMsg);
              if (_messages.length == 1) {
                _oldestCreatedAt =
                    DateTime.tryParse(newMsg['created_at'].toString());
              }
            });

            // Side Effects
            if (newMsg['type'] == 'beeb' && newMsg['sender_id'] != myId) {
              _playUiSound();
              HapticFeedback.heavyImpact();
            }
            if (newMsg['sender_id'] != myId) {
              _supabase
                  .from('social_messages')
                  .update({'is_read': true})
                  .match({'id': newMsg['id']}).then((_) {});
            }

            if (_isNearBottom || !_initialScrollDone) {
              _scrollToBottom();
            } else if (!_hasNewMessageWhileAway) {
              safeSetState(() => _hasNewMessageWhileAway = true);
            }
          },
        )
        .subscribe();
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
        } catch (e, st) {
          AppLogger.logError("Presence Err", error: e, stackTrace: st);
        }
        safeSetState(() => _isOpponentOnline = found);
      })
      .onBroadcast(event: 'typing', callback: (payload) {
        final senderId = payload['user_id'];
        if (senderId != myId) {
          safeSetState(() => _isOpponentTyping = true);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () { if (mounted) safeSetState(() => _isOpponentTyping = false); });
        }
      })
      .subscribe((status, error) async {
         if (status == RealtimeSubscribeStatus.subscribed) {
           await _roomChannel.track({'user_id': myId, 'online_at': DateTime.now().toIso8601String()});
         }
      });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final nearBottom = position.extentAfter < 250;
    if (nearBottom != _isNearBottom) {
      safeSetState(() {
        _isNearBottom = nearBottom;
        if (nearBottom) _hasNewMessageWhileAway = false;
      });
    }
    if (position.pixels <= 200) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    safeSetState(() {
      _isInitialLoading = true;
      _messageError = null;
      _messages.clear();
      _messageIds.clear();
      _animatedMessageIds.clear();
      _hasMoreMessages = true;
      _oldestCreatedAt = null;
      _initialScrollDone = false;
    });

    try {
      final response = await _supabase
          .from('social_messages')
          .select()
          .eq('chat_id', widget.chatId)
          .order('created_at', ascending: false)
          .limit(_pageSize);

      final List<Map<String, dynamic>> fetched =
          List<Map<String, dynamic>>.from(response as List<dynamic>);
      final ordered = fetched.reversed.toList();

      safeSetState(() {
        _messages.addAll(ordered);
        for (final msg in ordered) {
          final id = msg['id']?.toString();
          if (id != null) {
            _messageIds.add(id);
            _animatedMessageIds.add(id);
          }
        }
        if (_messages.isNotEmpty) {
          _oldestCreatedAt =
              DateTime.tryParse(_messages.first['created_at'].toString());
        }
        _hasMoreMessages = fetched.length == _pageSize;
        _isInitialLoading = false;
      });

      if (_messages.isNotEmpty && !_initialScrollDone) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            _initialScrollDone = true;
            if (mounted) {
              safeSetState(() {
                _isNearBottom = true;
                _hasNewMessageWhileAway = false;
              });
            }
          }
        });
      }
    } catch (e, st) {
      AppLogger.logError("Error loading messages", error: e, stackTrace: st);
      safeSetState(() {
        _isInitialLoading = false;
        _messageError = "Gagal memuat pesan";
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _oldestCreatedAt == null) return;
    if (!_scrollController.hasClients) return;
    safeSetState(() => _isLoadingMore = true);

    final prevOffset = _scrollController.position.pixels;
    final prevMaxExtent = _scrollController.position.maxScrollExtent;

    try {
      final response = await _supabase
          .from('social_messages')
          .select()
          .eq('chat_id', widget.chatId)
          .lt('created_at', _oldestCreatedAt!.toIso8601String())
          .order('created_at', ascending: false)
          .limit(_pageSize);

      final List<Map<String, dynamic>> fetched =
          List<Map<String, dynamic>>.from(response as List<dynamic>);
      final ordered = fetched.reversed.toList();

      final List<Map<String, dynamic>> newItems = [];
      for (final msg in ordered) {
        final id = msg['id']?.toString();
        if (id != null && _messageIds.add(id)) {
          newItems.add(msg);
        }
      }

      safeSetState(() {
        if (newItems.isNotEmpty) {
          _messages.insertAll(0, newItems);
          for (final msg in newItems) {
            final id = msg['id']?.toString();
            if (id != null) _animatedMessageIds.add(id);
          }
          _oldestCreatedAt =
              DateTime.tryParse(_messages.first['created_at'].toString());
        }
        if (fetched.length < _pageSize) {
          _hasMoreMessages = false;
        }
        _isLoadingMore = false;
      });

      if (newItems.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final newMaxExtent = _scrollController.position.maxScrollExtent;
            final delta = newMaxExtent - prevMaxExtent;
            _scrollController.jumpTo(prevOffset + delta);
          }
        });
      }
    } catch (e, st) {
      AppLogger.logError("Error loading older messages", error: e, stackTrace: st);
      safeSetState(() => _isLoadingMore = false);
    }
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
    safeSetState(() { _editingMessageId = msg['id']; _textController.text = msg['content']; _replyMessage = null; });
    _focusNode.requestFocus(); 
  }

  void _cancelEdit() {
    safeSetState(() { _editingMessageId = null; _textController.clear(); });
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
    } catch (e, st) {
      AppLogger.logError("Delete message error", error: e, stackTrace: st);
      if (mounted) AppSnackBar.showError(context, "Gagal menghapus pesan.");
    }
  }

  void _onSwipeToReply(Map<String, dynamic> msg) {
    HapticFeedback.lightImpact();
    safeSetState(() { _replyMessage = msg; _editingMessageId = null; });
    _focusNode.requestFocus();
  }

  void _cancelReply() { safeSetState(() => _replyMessage = null); }

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
    return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
            onTap: onTap,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: color.withOpacity(0.1)),
                  child: Icon(icon, color: color, size: 28)),
              const SizedBox(height: 8),
              Text(label, style: GoogleFonts.outfit(color: Colors.black)),
            ])));
  }

  Future<void> _handleAttachment(ImageSource source) async {
    try {
      final allowed = source == ImageSource.camera
          ? await PermissionPrompt.requestCamera(context)
          : await PermissionPrompt.requestGallery(context);
      if (!allowed) return;
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null) return;
      final file = File(picked.path);
      final myId = _supabase.auth.currentUser?.id;
      final path = 'chat_${DateTime.now().millisecondsSinceEpoch}_$myId.${picked.path.split('.').last}';
      await _supabase.storage.from('chat-uploads').upload(path, file);
      final url = _supabase.storage.from('chat-uploads').getPublicUrl(path);
      _sendMessage(type: 'image', content: url);
    } catch (e, st) {
      AppLogger.logError("Upload Err", error: e, stackTrace: st);
    }
  }

  Future<void> _handleLocation() async {
    try {
      final allowed = await PermissionPrompt.requestLocation(context);
      if (allowed) {
        final pos = await Geolocator.getCurrentPosition();
        final url = 'http://googleusercontent.com/maps.google.com/maps?q=${pos.latitude},${pos.longitude}';
        _sendMessage(type: 'location', content: url);
      }
    } catch (e) {}
  }

  // --- RECORDING LOGIC ---

  Future<void> _startRecording() async {
    try {
      final allowed = await PermissionPrompt.requestMicrophone(context);
      if (!allowed) return;
      if (await _audioRecorder.hasPermission()) {
        HapticFeedback.mediumImpact();
        
        safeSetState(() {
          _isRecording = true;
          _recordingDuration = 0;
          _dragOffset = 0.0;
        });

        _isRecorderInitialised = false; 
        _recordStartTime = DateTime.now();

        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        
        _isRecorderInitialised = true; 

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) safeSetState(() => _recordingDuration++);
        });
      }
    } catch (e) {
      AppLogger.logError("Rec Err", error: e);
      safeSetState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    
    if (!_isRecorderInitialised) {
       _cancelRecording(); 
       return;
    }

    final durationMs = DateTime.now().difference(_recordStartTime ?? DateTime.now()).inMilliseconds;
    if (durationMs < 600) {
      _cancelRecording();
      return;
    }

    try {
      final path = await _audioRecorder.stop();
      _cleanupRecorderState();
      
      if (path != null) {
        final file = File(path);
        final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        try {
           await _supabase.storage.from('voice-notes').upload(fileName, file);
           final url = _supabase.storage.from('voice-notes').getPublicUrl(fileName);
           _sendMessage(type: 'audio', content: url);
        } catch (storageErr) {
           AppLogger.logError("Storage Err", error: storageErr);
           String errorMsg = "Gagal upload Voice Note";
           if (storageErr.toString().contains("Bucket not found") || storageErr.toString().contains("404")) {
             errorMsg = "Error: Bucket 'voice-notes' belum dibuat di Supabase Dashboard";
           }
           if (mounted) AppSnackBar.showError(context, errorMsg);
        }
      }
    } catch (e) {
      AppLogger.logError("Stop Rec Err", error: e);
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    
    _cleanupRecorderState(); 

    if (_isRecorderInitialised) {
      try {
        final path = await _audioRecorder.stop();
        if (path != null) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      } catch (e) {
        AppLogger.logError("Cancel/Stop Err", error: e);
      }
    }
    
    _isRecorderInitialised = false; 
    HapticFeedback.lightImpact();
  }

  void _cleanupRecorderState() {
     _recordingTimer?.cancel();
     safeSetState(() {
       _isRecording = false;
       _recordingDuration = 0;
       _dragOffset = 0.0;
     });
     if (_trashScaleController.isCompleted) _trashScaleController.reverse();
  }

  void _handleDragUpdate(LongPressMoveUpdateDetails details) {
    if (!_isRecording) return;
    
    final offset = details.offsetFromOrigin.dx;

    safeSetState(() {
      _dragOffset = offset;
    });

    if (offset < -50) {
      _cancelRecording();
    } else if (offset < -25) {
      if (!_trashScaleController.isAnimating && _trashScaleController.status != AnimationStatus.completed) {
         HapticFeedback.mediumImpact(); 
         _trashScaleController.forward();
      }
    } else {
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
    
    if (type == 'text') {
      _textController.clear();
      if (mounted) setState(() {});
    }

    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    if (_isSending) return;

    safeSetState(() => _isSending = true);

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

      final length = type == 'text' ? text.length : 0;
      final hasMedia = type != 'text' && type != 'beeb';
      AnalyticsService.instance.track(
        AnalyticsEvents.chatMessageSent,
        props: {
          'has_media': hasMedia,
          'length_bucket': _lengthBucket(length),
        },
      );

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
      
      // Scroll to bottom after sending
      _scrollToBottom();
    } catch (e, st) {
      AppLogger.logError("Send message error", error: e, stackTrace: st);
      if (mounted) AppSnackBar.showError(context, "Gagal mengirim pesan.");
    } finally {
      if (mounted) safeSetState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (mounted) {
      safeSetState(() {
        _hasNewMessageWhileAway = false;
        _isNearBottom = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeOut
        );
      }
    }); 
  }

  void _showDialogImage(String imageUrl) {
    showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: SafeNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain)));
  }

  String _lengthBucket(int length) {
    if (length <= 20) return '0-20';
    if (length <= 80) return '21-80';
    return '80+';
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
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(child: _buildMessageList()),
                  _buildFloatingInputArea(),
                ],
              ),
              if (_hasNewMessageWhileAway)
                Positioned(
                  right: 16,
                  bottom: 96 + MediaQuery.of(context).viewInsets.bottom,
                  child: FloatingActionButton(
                    heroTag: 'scrollToBottomFab',
                    mini: true,
                    backgroundColor: kPrimaryBlue,
                    onPressed: _scrollToBottom,
                    child: const Icon(Icons.arrow_downward, color: Colors.white),
                  ),
                ),
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
    if (_isInitialLoading) {
      return const AppStateView(state: AppViewState.loading);
    }

    if (_messageError != null) {
      return AppStateView(
        state: AppViewState.error,
        error: AppError(
          title: "Gagal memuat pesan",
          message: _messageError ?? "Koneksi bermasalah. Coba lagi.",
        ),
        onRetry: _loadInitialMessages,
      );
    }

    if (_messages.isEmpty) {
      return const AppStateView(
        state: AppViewState.empty,
        emptyTitle: "Belum ada pesan",
        emptyMessage: "Mulai percakapan sekarang.",
      );
    }

    final bool showTopLoader = _isLoadingMore;
    return ListView.builder(
      reverse: false,
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 120, 16, 20),
      itemCount: _messages.length + (showTopLoader ? 1 : 0),
      itemBuilder: (context, index) {
        if (showTopLoader && index == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final msgIndex = index - (showTopLoader ? 1 : 0);
        final msg = _messages[msgIndex];
        final isMe = msg['sender_id'] == myId;
        bool showDate = false;

        if (msgIndex == 0) {
          showDate = true;
        } else {
          final curr = DateTime.parse(msg['created_at']).toLocal();
          final prev =
              DateTime.parse(_messages[msgIndex - 1]['created_at']).toLocal();
          if (curr.day != prev.day) showDate = true;
        }

        return RepaintBoundary(
          child: Column(
            children: [
              if (showDate) _buildDateHeader(msg['created_at']),
              GestureDetector(
                onLongPress: () => _showOptions(msg, isMe),
                child: Dismissible(
                  key: Key(msg['id']),
                  direction: DismissDirection.startToEnd,
                  dismissThresholds: const {
                    DismissDirection.startToEnd: 0.15
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    color: Colors.transparent,
                    child: Icon(Icons.reply, color: Colors.grey[600], size: 30),
                  ),
                  confirmDismiss: (dir) async {
                    _onSwipeToReply(msg);
                    return false;
                  },
                  child: _buildAnimatedBubble(msg, isMe),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateHeader(String dateStr) {
    final date = DateTime.parse(dateStr).toLocal();
    final label = _formatDateHeader(date);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: ShapeDecoration(
          color: Colors.white.withOpacity(0.5), 
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
                 label, 
                 style: GoogleFonts.outfit(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)
               ),
             ),
           ),
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return DateFormat('dd MMM yyyy').format(date);
  }

  Widget _buildAnimatedBubble(Map<String, dynamic> msg, bool isMe) {
    final type = msg['type'] ?? 'text';
    final content = msg['content'] ?? '';
    final time = msg['created_at'];
    final reply = msg['reply_context'];
    final isEdited = msg['is_edited'] == true; 
    final isRead = msg['is_read'] == true;
    final msgId = msg['id']?.toString();

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

    final bubble = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12), 
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

    final shouldAnimate = msgId != null && !_animatedMessageIds.contains(msgId);
    if (!shouldAnimate) return bubble;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      onEnd: () {
        if (!mounted || msgId == null) return;
        if (!_animatedMessageIds.contains(msgId)) {
          safeSetState(() => _animatedMessageIds.add(msgId));
        }
      },
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: Transform.scale(
              scale: 0.98 + (0.02 * value),
              child: child,
            ),
          ),
        );
      },
      child: bubble,
    );
  }

  Widget _buildTextBubble(bool isMe, String content, String? timeStr, bool isEdited, bool isRead) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
      decoration: BoxDecoration(
        gradient: isMe 
           ? const LinearGradient(colors: [Color(0xFF0088CC), Color(0xFF2575FC)]) 
           : null, 
        color: isMe ? null : Colors.white, 
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
              color: isMe ? Colors.white : Colors.black87, 
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          _buildTimestampWithTick(timeStr, isMe, isRead, isEdited: isEdited),
        ],
      ),
    );
  }

  Widget _buildImageBubble(bool isMe, String content, String? timeStr) {
    return GestureDetector(
      onTap: () => _showDialogImage(content),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          image: DecorationImage(image: NetworkImage(content), fit: BoxFit.cover)
        ),
        child: AspectRatio(aspectRatio: 1),
      ),
    );
  }

  Widget _buildLocationBubble(bool isMe, String content) {
    return GestureDetector(
      onTap: () async {
         final uri = Uri.parse(content);
         if (await canLaunchUrl(uri)) launchUrl(uri);
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text("Lihat Lokasi", style: GoogleFonts.outfit(color: Colors.blue, decoration: TextDecoration.underline)))
          ],
        ),
      ),
    );
  }

  Widget _buildTimestampWithTick(String? timeStr, bool isMe, bool isRead, {bool isEdited = false}) {
    if (timeStr == null) return const SizedBox.shrink();
    final date = DateTime.parse(timeStr).toLocal();
    final time = DateFormat('HH:mm').format(date);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isEdited) Text("edited ", style: GoogleFonts.outfit(fontSize: 9, color: isMe ? Colors.white70 : Colors.black38)),
        Text(time, style: GoogleFonts.outfit(fontSize: 10, color: isMe ? Colors.white70 : Colors.black38)),
        if (isMe) ...[
           const SizedBox(width: 4),
           Icon(Icons.done_all, size: 14, color: isRead ? Colors.greenAccent : Colors.white70),
        ]
      ],
    );
  }

  Widget _buildFloatingInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: Column(
        children: [
          if (_replyMessage != null)
             Container(
               margin: const EdgeInsets.only(bottom: 12),
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: kPrimaryBlue, width: 4))),
               child: Row(children: [
                   Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                       Text("Membalas ${_getSenderName(_replyMessage!['sender_id'])}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: kPrimaryBlue)),
                       Text(_replyMessage!['content'] ?? '...', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(fontSize: 12))
                   ])),
                   Semantics(
                     button: true,
                     label: "Batal balasan",
                     child: IconButton(
                       icon: const Icon(Icons.close, size: 20),
                       onPressed: _cancelReply,
                     ),
                   )
               ]),
             ),
          
          if (_isRecording) 
            _buildRecordingUI()
          else
            Row(
              children: [
                Semantics(
                  button: true,
                  label: "Tambah lampiran",
                  child: IconButton(
                    icon: const Icon(Icons.add, color: kPrimaryBlue),
                    onPressed: _isSending ? null : _showAttachmentSheet,
                  ),
                ),
                 Expanded(
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(24)),
                     child: TextField(
                       controller: _textController,
                       focusNode: _focusNode,
                       onChanged: (value) {
                         _onTypingChanged(value);
                         if (mounted) setState(() {});
                       },
                       minLines: 1, maxLines: 4,
                       decoration: const InputDecoration(hintText: "Tulis pesan...", border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12)),
                     ),
                   ),
                 ),
                 const SizedBox(width: 8),
                 if (_textController.text.trim().isNotEmpty) // Send text
                    Semantics(
                      button: true,
                      label: "Kirim pesan",
                      child: GestureDetector(
                        onTap: _isSending ? null : () => _sendMessage(type: 'text'),
                        child: CircleAvatar(
                          backgroundColor: kPrimaryBlue,
                          child: _isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    )
                 else // Mic or Beeb
                    Semantics(
                      button: true,
                      label: "Kirim BEEB, tekan dan tahan untuk rekam suara",
                      child: GestureDetector(
                        onTap: _isSending ? null : _sendBeeb,
                        onLongPress: _isSending ? null : _startRecording,
                        onLongPressMoveUpdate: _isSending ? null : _handleDragUpdate,
                        onLongPressEnd: _isSending ? null : (details) => _stopRecordingAndSend(),
                        child: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: _isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Image.asset('assets/beep.png', width: 24),
                        ),
                      ),
                    )
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Row(
      children: [
         ScaleTransition(
           scale: _trashScaleController,
           child: const Icon(Icons.delete, color: Colors.red),
         ),
         const SizedBox(width: 12),
         Expanded(child: Text(_dragOffset < -50 ? "Lepas untuk batalkan" : "Merekam: ${_formatDuration(_recordingDuration)}...", style: GoogleFonts.outfit(color: _dragOffset < -50 ? Colors.red : Colors.black))),
         ScaleTransition(scale: _micScaleController, child: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.mic, color: Colors.white)))
      ],
    );
  }
} // End State

// SUB-WIDGETS (Beeb & Audio) to keep file clean-ish
class BeebBubble extends StatelessWidget {
  final bool isMe;
  const BeebBubble({super.key, required this.isMe});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2), 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange)
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/beep.png', width: 20),
          const SizedBox(width: 8),
          Text("BEEB!", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16))
      ]),
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
    _player.onPlayerStateChanged.listen((s) {
       if (mounted) safeSetState(() => _isPlaying = s == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
       if (mounted) safeSetState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
       if (mounted) safeSetState(() => _position = p);
    });
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
       width: 200, padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
          color: widget.isMe ? Colors.white.withOpacity(0.2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16)
       ),
       child: Row(children: [
          GestureDetector(
            onTap: () async {
               if (_isPlaying) await _player.pause();
               else await _player.play(UrlSource(widget.url));
            },
            child: CircleAvatar(
              backgroundColor: widget.isMe ? Colors.white : Colors.blue,
              foregroundColor: widget.isMe ? Colors.blue : Colors.white,
              radius: 20,
              child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            ),
          ),
          const SizedBox(width: 12),
          Text("${_fmt(_position)} / ${_fmt(_duration)}", style: GoogleFonts.outfit(color: widget.isMe ? Colors.white : Colors.black))
       ]),
    );
  }
}
