import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:mychatolic_app/l10n/gen/app_localizations.dart';

import 'package:mychatolic_app/features/social/pages/social_chat_detail_page.dart';
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
import 'package:mychatolic_app/features/social/services/chat_inbox_service.dart';
import 'package:mychatolic_app/features/social/services/group_invite_service.dart';
import 'package:mychatolic_app/features/social/widgets/chat_inbox_tile.dart';
import 'package:mychatolic_app/features/social/widgets/chat_inbox_skeleton.dart';
import 'package:mychatolic_app/features/social/widgets/chat_actions_sheet.dart';

class ChatPage extends StatefulWidget {
  final String? partnerId;
  const ChatPage({super.key, this.partnerId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  final ChatInboxService _inboxService = ChatInboxService();
  final GroupInviteService _groupInviteService = GroupInviteService();
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
  final Map<String, Map<String, dynamic>> _lastMessageCache = {};
  Timer? _previewRefreshTimer;
  bool _previewRefreshInFlight = false;
  String _lastPreviewSignature = '';
  List<String> _pendingPreviewChatIds = [];
  DateTime _lastPreviewRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  List<dynamic> _safeParticipants(dynamic raw) {
    return raw is List ? raw : const <dynamic>[];
  }

  @override
  void dispose() {
    _unreadRefreshTimer?.cancel();
    _previewRefreshTimer?.cancel();
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
    final recentlyRefreshed =
        DateTime.now().difference(_lastUnreadRefresh) < const Duration(milliseconds: 800);
    if (signature == _lastUnreadSignature && recentlyRefreshed) return;
    _lastUnreadSignature = signature;
    _pendingUnreadChatIds = uniqueIds;
    _unreadRefreshTimer?.cancel();
    _unreadRefreshTimer = Timer(const Duration(milliseconds: 700), () {
      _refreshUnreadCounts(_pendingUnreadChatIds);
    });
  }

  Future<void> _refreshUnreadCounts(List<String> chatIds) async {
    if (_unreadRefreshInFlight) return;
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null || chatIds.isEmpty) return;

    _unreadRefreshInFlight = true;
    try {
      final counts = await _inboxService.fetchUnreadCounts(
        myId: myId,
        chatIds: chatIds,
      );
      if (!mounted) return;
      safeSetState(() {
        _unreadCounts
          ..clear()
          ..addAll(counts);
        _lastUnreadRefresh = DateTime.now();
      });
    } finally {
      _unreadRefreshInFlight = false;
    }
  }

  void _schedulePreviewRefresh(List<String> chatIds) {
    if (chatIds.isEmpty) return;
    final uniqueIds = chatIds.toSet().toList();
    final signature = _chatIdsSignature(uniqueIds);
    final recentlyRefreshed =
        DateTime.now().difference(_lastPreviewRefresh) < const Duration(milliseconds: 800);
    if (signature == _lastPreviewSignature && recentlyRefreshed) return;
    _lastPreviewSignature = signature;
    _pendingPreviewChatIds = uniqueIds;
    _previewRefreshTimer?.cancel();
    _previewRefreshTimer = Timer(const Duration(milliseconds: 700), () {
      _refreshPreviewCache(_pendingPreviewChatIds);
    });
  }

  Future<void> _refreshPreviewCache(List<String> chatIds) async {
    if (_previewRefreshInFlight) return;
    if (chatIds.isEmpty) return;
    _previewRefreshInFlight = true;
    try {
      final latest = await _inboxService.fetchLatestMessagesForChats(
        chatIds: chatIds,
      );
      if (!mounted) return;
      safeSetState(() {
        _lastMessageCache.addAll(latest);
        _lastPreviewRefresh = DateTime.now();
      });
    } finally {
      _previewRefreshInFlight = false;
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
      final response = await _fetchProfilesByIds(idsToFetch);

      safeSetState(() {
        for (var profile in response) {
          final id = profile['id']?.toString();
          if (id != null && id.isNotEmpty) {
            _profileCache[id] = Map<String, dynamic>.from(profile);
          }
        }
        _fetchingIds.removeAll(idsToFetch);
      });
    } catch (e, st) {
      AppLogger.logError("Error batch fetching profiles", error: e, stackTrace: st);
      _fetchingIds.removeAll(idsToFetch);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchProfilesByIds(List<String> ids) async {
    final uniqueIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return [];

    final List<dynamic> response = await _supabase
        .from('profiles')
        .select('id, full_name, avatar_url')
        .inFilter('id', uniqueIds);

    return response
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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
        _schedulePreviewRefresh(ids);
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
        title: Text(
          t.chatTitle,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: AppColors.text,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Semantics(
            button: true,
            label: t.a11yChatSearch,
            child: IconButton(
              icon: const Icon(Icons.search, color: AppColors.text),
              onPressed: _openSearchUser,
            ),
          ),
          Semantics(
            button: true,
            label: t.a11yChatCreate,
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.text),
              onPressed: _openActionsSheet,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (_loadingChatIds) const ChatStorySkeleton() else const StoryRail(),
          Expanded(child: _buildChatList(myId, t)),
        ],
      ),
    );
  }

  Widget _buildChatList(String myId, AppLocalizations t) {
    if (_loadingChatIds) {
      return const ChatInboxSkeleton();
    }
    if (_chatIdsError != null) {
      return _buildErrorState(t, onRetry: _refreshInbox);
    }
    if (_myChatIds.isEmpty || _chatStream == null) {
      return _buildEmptyState(t);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const ChatInboxSkeleton();
        }

        if (snapshot.hasError) {
          return _buildErrorState(t, onRetry: _refreshInbox);
        }

        final rawChats = snapshot.data ?? <Map<String, dynamic>>[];
        final chats = rawChats.where((chat) {
          final id = chat['id']?.toString();
          if (id != null && _myChatIds.contains(id)) {
            return true;
          }
          final participants = _safeParticipants(chat['participants']);
          return participants.map((p) => p?.toString()).contains(myId);
        }).toList();

        if (chats.isEmpty) {
          return _buildEmptyState(t);
        }

        final chatIds = chats
            .map((chat) => chat['id']?.toString())
            .whereType<String>()
            .toList();

        if (chatIds.isNotEmpty) {
          Future.microtask(() {
            _scheduleUnreadRefresh(chatIds);
          });
        }

        final missingPreviewIds = <String>[];
        final missingProfileIds = <String>[];

        for (final chat in chats) {
          final chatId = chat['id']?.toString();
          if (chatId == null) continue;
          final lastMessage = (chat['last_message'] ?? '').toString().trim();
          if (lastMessage.isEmpty && !_lastMessageCache.containsKey(chatId)) {
            missingPreviewIds.add(chatId);
          }
          if (chat['is_group'] != true) {
            final participants = _safeParticipants(chat['participants']);
            final partnerId = participants.firstWhere(
              (id) => id != myId,
              orElse: () => null,
            );
            if (partnerId != null && !_profileCache.containsKey(partnerId)) {
              missingProfileIds.add(partnerId);
            }
          }
        }

        if (missingPreviewIds.isNotEmpty) {
          Future.microtask(() => _schedulePreviewRefresh(missingPreviewIds));
        }
        if (missingProfileIds.isNotEmpty) {
          Future.microtask(() => _fetchMissingProfiles(missingProfileIds));
        }

        return RefreshIndicator(
          onRefresh: _refreshInbox,
          child: AnimationLimiter(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 8),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final chatId = chat['id']?.toString();
                if (chatId == null || chatId.isEmpty) {
                  return const SizedBox.shrink();
                }
                final unreadCount =
                    _unreadCounts[chatId] ?? 0;
                Map<String, dynamic>? partnerProfile;
                Map<String, dynamic> profileForNav = {};
                String? avatarUrl;
                final isGroup = chat['is_group'] == true;

                if (isGroup) {
                  final name = chat['group_name'] ?? 'Grup';
                  avatarUrl = chat['group_avatar_url'];
                  profileForNav = {
                    'id': chatId,
                    'full_name': name,
                    'avatar_url': avatarUrl,
                    'group_name': name,
                    'group_avatar_url': avatarUrl,
                  };
                } else {
                  final participants = _safeParticipants(chat['participants']);
                  final partnerId = participants.firstWhere(
                    (id) => id != myId,
                    orElse: () => null,
                  );
                  if (partnerId != null) {
                    partnerProfile = _profileCache[partnerId];
                    profileForNav = partnerProfile ?? {};
                    avatarUrl = partnerProfile?['avatar_url'];
                  }
                }

                ImagePrefetch.prefetch(context, avatarUrl);

                final preview = _inboxService.buildPreview(
                  chatRow: chat,
                  lastMessage: _lastMessageCache[chatId],
                );

                final isOnline = chat['is_online'] == true ||
                    (partnerProfile?['is_online'] == true);

                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 300),
                  child: SlideAnimation(
                    verticalOffset: 24,
                    child: FadeInAnimation(
                      child: ChatInboxTile(
                        chatData: chat,
                        partnerProfile: partnerProfile,
                        previewText: preview,
                        unreadCount: unreadCount,
                        isOnline: isOnline,
                        onTap: () {
                          if (!isGroup && partnerProfile == null) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SocialChatDetailPage(
                                chatId: chatId,
                                isGroup: isGroup,
                                opponentProfile: profileForNav,
                                source: 'chat_list',
                              ),
                            ),
                          ).then((_) {
                            if (chatId != null && chatId.isNotEmpty) {
                              _scheduleUnreadRefresh([chatId]);
                            }
                          });
                        },
                        onDelete: () {
                          if (chatId == null) return;
                          _deleteChat(chatId);
                        },
                        onLeaveGroup: isGroup ? _leaveGroupUnavailable : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshInbox() async {
    await _loadMyChatIds();
    final ids = List<String>.from(_myChatIds);
    if (ids.isEmpty) return;
    await _refreshUnreadCounts(ids);
    await _refreshPreviewCache(ids);
  }

  void _openActionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatActionsSheet(
        onNewChat: _openSearchUser,
        onCreateGroup: _openCreateGroup,
        onJoinLink: _showJoinLinkDialog,
      ),
    );
  }

  Future<void> _openSearchUser() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchUserPage()),
    );
    _loadMyChatIds();
  }

  Future<void> _openCreateGroup() async {
    final t = AppLocalizations.of(context)!;
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final mutualIds = await _inboxService.fetchMutualFollowIds(myId);
      if (mutualIds.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.chatMutualRequiredTitle, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: Text(t.chatMutualRequiredMessage, style: GoogleFonts.outfit()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.commonOk, style: GoogleFonts.outfit()),
              ),
            ],
          ),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateGroupPage(allowedUserIds: mutualIds),
        ),
      );
      _loadMyChatIds();
    } catch (e) {
      AppSnackBar.showError(context, t.chatLoadErrorMessage);
    }
  }

  Future<void> _showJoinLinkDialog() async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    bool isJoining = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(t.chatJoinLinkTitle, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: t.chatJoinLinkHint,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isJoining ? null : () => Navigator.pop(context),
                child: Text(t.commonCancel, style: GoogleFonts.outfit()),
              ),
              TextButton(
                onPressed: isJoining
                    ? null
                    : () async {
                        final input = controller.text.trim();
                        if (input.isEmpty) {
                          AppSnackBar.showError(context, t.chatJoinLinkInvalid);
                          return;
                        }
                        setState(() => isJoining = true);
                        final result = await _groupInviteService.joinByLink(input);
                        if (!mounted) return;
                        Navigator.pop(context);
                        _handleJoinResult(result);
                      },
                child: isJoining
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t.chatJoinLinkAction, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleJoinResult(GroupJoinResult result) async {
    final t = AppLocalizations.of(context)!;
    switch (result.status) {
      case GroupJoinStatus.joined:
        AppSnackBar.showSuccess(context, t.chatJoinLinkSuccess);
        if (result.chatId != null) {
          await _openGroupChat(result.chatId!);
        }
        break;
      case GroupJoinStatus.alreadyMember:
        AppSnackBar.showInfo(context, t.chatJoinLinkAlreadyMember);
        if (result.chatId != null) {
          await _openGroupChat(result.chatId!);
        }
        break;
      case GroupJoinStatus.pending:
        AppSnackBar.showInfo(context, t.chatJoinLinkPending);
        break;
      case GroupJoinStatus.invalid:
        AppSnackBar.showError(context, t.chatJoinLinkInvalid);
        break;
      case GroupJoinStatus.failed:
        AppSnackBar.showError(context, t.chatJoinLinkFailed);
        break;
    }
  }

  Future<void> _openGroupChat(String chatId) async {
    final group = await _supabase
        .from('social_chats')
        .select('id, group_name, group_avatar_url')
        .eq('id', chatId)
        .maybeSingle();
    if (group == null) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SocialChatDetailPage(
          chatId: chatId,
          isGroup: true,
          opponentProfile: {
            'id': chatId,
            'full_name': group['group_name'] ?? 'Grup',
            'avatar_url': group['group_avatar_url'],
            'group_name': group['group_name'],
            'group_avatar_url': group['group_avatar_url'],
          },
          source: 'chat_list',
        ),
      ),
    );
    _loadMyChatIds();
  }

  void _leaveGroupUnavailable() {
    final t = AppLocalizations.of(context)!;
    AppSnackBar.showInfo(context, t.chatLeaveUnavailable);
  }

  Future<void> _deleteChat(String chatId) async {
    final t = AppLocalizations.of(context)!;
    try {
      await _supabase.from('social_chats').delete().eq('id', chatId);
      if (mounted) AppSnackBar.showSuccess(context, t.chatDeleteSuccess);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, t.chatDeleteFailed);
    }
  }

  Widget _buildEmptyState(AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.level1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                t.chatEmptyTitle,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                t.chatEmptyMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: AppColors.textBody),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openSearchUser,
                icon: const Icon(Icons.search),
                label: Text(t.chatEmptyCta),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations t, {required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.level1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 44, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(
                t.chatLoadErrorTitle,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                t.chatLoadErrorMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: AppColors.textBody),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(t.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
