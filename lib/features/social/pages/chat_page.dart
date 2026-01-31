import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:mychatolic_app/features/social/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/widgets/story_rail.dart';
import 'package:mychatolic_app/features/social/search_user_page.dart';
import 'package:mychatolic_app/features/social/create_group_page.dart';
import 'package:mychatolic_app/core/design_tokens.dart';
import 'package:mychatolic_app/core/ui/app_state.dart';
import 'package:mychatolic_app/core/ui/app_state_view.dart';
import 'package:mychatolic_app/core/ui/app_snackbar.dart';
import 'package:mychatolic_app/core/log/app_logger.dart';
import 'package:mychatolic_app/core/ui/image_prefetch.dart';
import 'package:mychatolic_app/services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final String? partnerId;
  const ChatPage({super.key, this.partnerId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  bool _isRedirecting = false;

  List<String> _myChatIds = [];
  bool _loadingChatIds = true;
  Object? _chatIdsError;
  Stream<List<Map<String, dynamic>>>? _chatStream;
  
  // Cache untuk menyimpan profil user yang sudah di-fetch
  // Key: User ID, Value: Map Profile Data
  final Map<String, Map<String, dynamic>> _profileCache = {};
  
  // Set untuk menyimpan ID yang sedang dalam proses fetch agar tidak double request
  final Set<String> _fetchingIds = {};

  // Unread count cache per chat
  final Map<String, int> _unreadCounts = {};
  Timer? _unreadRefreshTimer;
  bool _unreadRefreshInFlight = false;
  String _lastUnreadSignature = '';
  List<String> _pendingUnreadChatIds = [];
  DateTime _lastUnreadRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  // Pastel Color Palette
  final List<Color> _pastelColors = [
    const Color(0xFFE3F2FD), // Blue Light
    const Color(0xFFF3E5F5), // Purple Light
    const Color(0xFFE0F2F1), // Teal Light
    const Color(0xFFFFF3E0), // Orange Light
    const Color(0xFFFFEBEE), // Pink Light
  ];

  List<dynamic> _safeParticipants(dynamic raw) {
    return raw is List ? raw : const <dynamic>[];
  }

  @override
  void dispose() {
    _unreadRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.partnerId != null) {
      _handleAutoRedirect(widget.partnerId!);
    }
    _loadMyChatIds();
  }

  String _chatIdsSignature(List<String> ids) {
    if (ids.isEmpty) return '';
    return ids.join('|');
  }

  void _scheduleUnreadRefresh(List<String> chatIds) {
    if (chatIds.isEmpty) return;
    final uniqueIds = chatIds.toSet().toList();
    final signature = _chatIdsSignature(uniqueIds);
    final recentlyRefreshed = DateTime.now().difference(_lastUnreadRefresh) < const Duration(seconds: 2);
    if (signature == _lastUnreadSignature && recentlyRefreshed) return;
    _lastUnreadSignature = signature;
    _pendingUnreadChatIds = uniqueIds;
    _unreadRefreshTimer?.cancel();
    _unreadRefreshTimer = Timer(const Duration(seconds: 2), () {
      _refreshUnreadCounts(_pendingUnreadChatIds);
    });
  }

  Future<void> _refreshUnreadCounts(List<String> chatIds) async {
    if (_unreadRefreshInFlight) return;
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null || chatIds.isEmpty) return;

    _unreadRefreshInFlight = true;
    try {
      final uniqueIds = chatIds.toSet().toList();
      final futures = uniqueIds.map((chatId) async {
        try {
          final count = await _supabase
              .from('social_messages')
              .count(CountOption.exact)
              .eq('chat_id', chatId)
              .eq('is_read', false)
              .neq('sender_id', myId);
          return MapEntry(chatId, count);
        } catch (_) {
          return MapEntry(chatId, _unreadCounts[chatId] ?? 0);
        }
      }).toList();

      final entries = await Future.wait(futures);
      if (!mounted) return;
      safeSetState(() {
        for (final entry in entries) {
          _unreadCounts[entry.key] = entry.value;
        }
        _lastUnreadRefresh = DateTime.now();
      });
    } finally {
      _unreadRefreshInFlight = false;
    }
  }

  Future<void> _handleAutoRedirect(String partnerId) async {
    safeSetState(() => _isRedirecting = true);
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) {
      safeSetState(() => _isRedirecting = false);
      return;
    }

    try {
      final chatId = await _chatService.getOrCreatePrivateChat(partnerId);

      final profile = await _supabase.from('profiles').select().eq('id', partnerId).single();

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SocialChatDetailPage(
          chatId: chatId, opponentProfile: profile, isGroup: false, source: 'profile'
        )));
      }
    } catch (e, st) {
      AppLogger.logError("Gagal membuka chat", error: e, stackTrace: st);
      if (mounted) {
        AppSnackBar.showError(context, "Gagal membuka chat");
      }
    } finally {
      safeSetState(() => _isRedirecting = false);
    }
  }

  // Logic Batch Fetching
  void _fetchMissingProfiles(List<String> ids) async {
    final idsToFetch = ids.where((id) => !_profileCache.containsKey(id) && !_fetchingIds.contains(id)).toList();
    
    if (idsToFetch.isEmpty) return;

    _fetchingIds.addAll(idsToFetch);

    try {
      final List<dynamic> response = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', idsToFetch);

      safeSetState(() {
        for (var profile in response) {
          _profileCache[profile['id']] = profile;
        }
        _fetchingIds.removeAll(idsToFetch);
      });
    } catch (e, st) {
      AppLogger.logError("Error batch fetching profiles", error: e, stackTrace: st);
      _fetchingIds.removeAll(idsToFetch);
    }
  }

  Future<void> _loadMyChatIds() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) {
      safeSetState(() {
        _loadingChatIds = false;
        _chatIdsError = Exception("User belum login");
        _myChatIds = [];
        _chatStream = null;
      });
      return;
    }

    safeSetState(() {
      _loadingChatIds = true;
      _chatIdsError = null;
    });

    try {
      final participantRes = await _supabase
          .from('social_chats')
          .select('id, participants')
          .contains('participants', [myId])
          .order('updated_at', ascending: false);

      final participantIds = (participantRes as List)
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .toList();

      final memberRes = await _supabase
          .from('chat_members')
          .select('chat_id, social_chats!inner(updated_at)')
          .eq('user_id', myId)
          .order(
            'updated_at',
            referencedTable: 'social_chats',
            ascending: false,
          );
      final memberIds = (memberRes as List)
          .map((e) => e['chat_id']?.toString())
          .whereType<String>()
          .toList();

      final seen = <String>{};
      final ids = <String>[];
      for (final id in participantIds) {
        if (seen.add(id)) ids.add(id);
      }
      for (final id in memberIds) {
        if (seen.add(id)) ids.add(id);
      }

      safeSetState(() {
        _myChatIds = ids;
        if (_myChatIds.isNotEmpty) {
          // TODO: SupabaseStreamFilterBuilder (supabase 2.10.2) doesn't support `.contains`.
          // When supported, prefer server-side contains filter on participants.
          _chatStream = _supabase
              .from('social_chats')
              .stream(primaryKey: ['id'])
              .inFilter('id', _myChatIds)
              .order('updated_at', ascending: false);
        } else {
          _chatStream = null;
        }
        _loadingChatIds = false;
      });
      if (ids.isNotEmpty) {
        _scheduleUnreadRefresh(ids);
      }
    } catch (e, st) {
      AppLogger.logError("Error loading chat ids", error: e, stackTrace: st);
      safeSetState(() {
        _chatIdsError = e;
        _myChatIds = [];
        _chatStream = null;
        _loadingChatIds = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (_isRedirecting) {
      return const Scaffold(
        body: AppStateView(state: AppViewState.loading),
      );
    }
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) {
      return Scaffold(
        body: AppStateView(
          state: AppViewState.error,
          error: AppError(
            title: t.chatSessionExpiredTitle,
            message: t.chatSessionExpiredMessage,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        title: Text(t.chatTitle, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 22)),
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0088CC), Color(0xFF0055AA)], // Premium Blue Gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0, 
        automaticallyImplyLeading: false,
        actions: [
          Semantics(
            button: true,
            label: t.a11yChatSearch,
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchUserPage()),
              ).then((_) => _loadMyChatIds()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: Container(
         decoration: const BoxDecoration(
           shape: BoxShape.circle,
           gradient: LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
           boxShadow: [BoxShadow(color: Color(0x660072FF), blurRadius: 10, offset: Offset(0, 4))]
         ),
         child: Semantics(
           button: true,
           label: t.a11yChatCreate,
           child: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateGroupPage()),
            ).then((_) => _loadMyChatIds()),
            backgroundColor: Colors.transparent, 
            elevation: 0,
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
         ),
      ),
      body: Column(
        children: [
          // 1. STORY SECTION
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.only(bottom: 8),
            child: const StoryRail(),
          ),
          
          // 2. CHAT LIST (EXPANDED) 
          Expanded(
            child: _loadingChatIds
                ? const AppStateView(state: AppViewState.loading)
                : _chatIdsError != null
                    ? AppStateView(
                        state: AppViewState.error,
                        error: AppError(
                          title: t.chatLoadErrorTitle,
                          message: t.chatLoadErrorMessage,
                        ),
                        onRetry: _loadMyChatIds,
                      )
                    : _myChatIds.isEmpty || _chatStream == null
                        ? AppStateView(
                            state: AppViewState.empty,
                            emptyTitle: t.chatEmptyTitle,
                            emptyMessage: t.chatEmptyMessage,
                          )
                        : StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _chatStream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !snapshot.hasData) {
                                return const AppStateView(
                                  state: AppViewState.loading,
                                );
                              }

                              if (snapshot.hasError) {
                                return AppStateView(
                                  state: AppViewState.error,
                                  error: AppError(
                                    title: t.chatLoadErrorTitle,
                                    message: t.chatLoadErrorMessage,
                                  ),
                                  onRetry: _loadMyChatIds,
                                );
                              }

                              final rawChats =
                                  snapshot.data ?? <Map<String, dynamic>>[];
                              final chats = rawChats.where((chat) {
                                final id = chat['id']?.toString();
                                if (id != null && _myChatIds.contains(id)) {
                                  return true;
                                }
                                final participants =
                                    _safeParticipants(chat['participants']);
                                return participants
                                    .map((p) => p?.toString())
                                    .contains(myId);
                              }).toList();

                              if (chats.isEmpty) {
                                return AppStateView(
                                  state: AppViewState.empty,
                                  emptyTitle: t.chatEmptyTitle,
                                  emptyMessage: t.chatEmptyMessage,
                                );
                              }

                              final chatIds = chats
                                  .map((chat) => chat['id']?.toString())
                                  .whereType<String>()
                                  .toList();
                              if (chatIds.isNotEmpty) {
                                Future.microtask(() => _scheduleUnreadRefresh(chatIds));
                              }

                              // --- BATCH FETCHING TRIGGER ---
                              final missingIds = <String>[];
                              for (var chat in chats) {
                                if (chat['is_group'] != true) {
                                  final participants = _safeParticipants(
                                      chat['participants']);
                                  final partnerId = participants.firstWhere(
                                    (id) => id != myId,
                                    orElse: () => null,
                                  );
                                  if (partnerId != null &&
                                      !_profileCache.containsKey(partnerId)) {
                                    missingIds.add(partnerId);
                                  }
                                }
                              }

                              if (missingIds.isNotEmpty) {
                                Future.microtask(
                                    () => _fetchMissingProfiles(missingIds));
                              }
                              // ------------------------------

                              return RefreshIndicator(
                                onRefresh: _loadMyChatIds,
                                child: AnimationLimiter(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(
                                      bottom: 80,
                                      top: 12,
                                    ),
                                    itemCount: chats.length,
                                    itemBuilder: (context, index) {
                                      final chat = chats[index];
                                      Map<String, dynamic>? partnerProfile;
                                      String myIdVerified = myId;
                                      final chatId = chat['id']?.toString();
                                      final unreadCount = chatId != null ? (_unreadCounts[chatId] ?? 0) : 0;

                                      if (chat['is_group'] != true) {
                                        final participants =
                                            _safeParticipants(
                                                chat['participants']);
                                        final partnerId = participants
                                            .firstWhere((id) => id != myId,
                                                orElse: () => null);
                                        if (partnerId != null) {
                                          partnerProfile =
                                              _profileCache[partnerId];
                                        }
                                      }

                                      return AnimationConfiguration
                                          .staggeredList(
                                        position: index,
                                        duration:
                                            const Duration(milliseconds: 375),
                                        child: SlideAnimation(
                                          verticalOffset: 50.0,
                                          child: FadeInAnimation(
                                            child: _ChatTile(
                                              chatData: chat,
                                              myId: myIdVerified,
                                              partnerProfile: partnerProfile,
                                              unreadCount: unreadCount,
                                              onChatOpened: chatId == null
                                                  ? null
                                                  : () => _scheduleUnreadRefresh([chatId]),
                                              backgroundColor: _pastelColors[
                                                  index %
                                                      _pastelColors.length],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// Optimized Stateless Widget
class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chatData;
  final String myId;
  final Map<String, dynamic>? partnerProfile;
  final int unreadCount;
  final VoidCallback? onChatOpened;
  final Color backgroundColor;

  const _ChatTile({
    required this.chatData, 
    required this.myId, 
    this.partnerProfile,
    required this.unreadCount,
    this.onChatOpened,
    required this.backgroundColor,
  });

  Future<void> _deleteChat(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final chatId = chatData['id'];
    final supabase = Supabase.instance.client;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.chatDeleteTitle, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(t.chatDeleteMessage, style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.chatDeleteCancel, style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                // Delete logic
                await supabase.from('social_chats').delete().eq('id', chatId);
                if (context.mounted) {
                  AppSnackBar.showSuccess(context, t.chatDeleteSuccess);
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackBar.showError(context, t.chatDeleteFailed);
                }
              }
            },
            child: Text(t.chatDeleteConfirm, style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
      final isGroup = chatData['is_group'] == true;
      final time = chatData['updated_at'] != null 
          ? timeago.format(DateTime.parse(chatData['updated_at']), locale: 'id') 
          : '';
      final isUnread = unreadCount > 0;
      final lastMessage = chatData['last_message'];
      final lastMessageType = chatData['last_message_type'];
      
      String name = '...';
      String? avatarUrl;
      Map<String, dynamic> profileForNav = {};

      if (isGroup) {
          name = chatData['group_name'] ?? 'Grup';
          avatarUrl = chatData['group_avatar_url'];
          profileForNav = {
             'id': chatData['id'],
             'full_name': name,
             'avatar_url': avatarUrl,
             'group_name': name,
             'group_avatar_url': avatarUrl
          };
      } else {
          // Personal Chat
          if (partnerProfile != null) {
             name = partnerProfile!['full_name'] ?? 'User';
             avatarUrl = partnerProfile!['avatar_url'];
             profileForNav = partnerProfile!;
          } else {
             name = 'Memuat...';
             // Default Avatar will handle null URL
          }
      }

      ImagePrefetch.prefetch(context, avatarUrl);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // More spacing
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isUnread ? AppColors.primary.withOpacity(0.25) : AppColors.border),
          boxShadow: AppShadows.level1,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              // Guard clause if data is not ready
              if (!isGroup && partnerProfile == null) return; 
          
              Navigator.push(context, MaterialPageRoute(builder: (_) => SocialChatDetailPage(
                chatId: chatData['id'],
                isGroup: isGroup,
                opponentProfile: profileForNav,
                source: 'chat_list',
              ))).then((_) => onChatOpened?.call());
            },
            onLongPress: () => _deleteChat(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                 children: [
                   Container(
                     width: 4,
                     height: 46,
                     decoration: BoxDecoration(
                       color: backgroundColor.withOpacity(0.9),
                       borderRadius: BorderRadius.circular(4),
                     ),
                   ),
                   const SizedBox(width: 12),
                   // Avatar with Thick White Border (Pop-up effect)
                   Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: backgroundColor.withOpacity(0.35),
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))
                        ]
                      ),
                      child: ClipOval(
                         child: SafeNetworkImage(
                             imageUrl: avatarUrl, 
                             width: 50, // Slightly larger
                             height: 50, 
                             fit: BoxFit.cover, 
                             fallbackIcon: isGroup ? Icons.groups : Icons.person
                         ),
                      ),
                   ),
                   const SizedBox(width: 14),
                   
                   // Info
                   Expanded(
                     child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                             name, 
                             style: GoogleFonts.outfit(
                               fontWeight: FontWeight.w700,
                               fontSize: 16,
                               color: const Color(0xFF1E293B),
                             ),
                             maxLines: 1
                          ),
                          const SizedBox(height: 4),
                          Text(
                             _buildPreviewText(lastMessage, lastMessageType),
                             maxLines: 1, 
                             overflow: TextOverflow.ellipsis, 
                             style: GoogleFonts.outfit(
                               fontSize: 13,
                               color: isUnread ? const Color(0xFF334155) : const Color(0xFF64748B),
                               fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                             )
                          ),
                        ],
                     ),
                   ),
                   
                   const SizedBox(width: 8),
                   
                   // Time + Unread
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       Text(
                         time,
                         style: GoogleFonts.outfit(
                           fontSize: 11,
                           color: const Color(0xFF94A3B8),
                           fontWeight: FontWeight.w600,
                         ),
                       ),
                       const SizedBox(height: 8),
                       if (isUnread) _UnreadBadge(count: unreadCount),
                     ],
                   ),
                 ],
              ),
            ),
          ),
        ),
      );
  }

  String _buildPreviewText(dynamic lastMessage, dynamic lastMessageType) {
    final type = lastMessageType?.toString() ?? '';
    if (type == 'image') return '📷 Foto';
    if (type == 'audio') return '🎤 Pesan Suara';
    if (type == 'location') return '📍 Lokasi';
    if (type == 'beeb') return '👋 BEEB!';

    final text = (lastMessage ?? '').toString();
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();
    if (lower.contains('beeb') || text.contains('👋')) return '👋 BEEB!';
    if (lower.contains('foto') || lower.contains('gambar') || text.contains('📷')) return '📷 Foto';
    if (lower.contains('lokasi') || text.contains('📍')) return '📍 Lokasi';
    if (lower.contains('pesan suara') || lower.contains('voice') || text.contains('🎤')) return '🎤 Pesan Suara';
    return text;
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        display,
        style: GoogleFonts.outfit(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
