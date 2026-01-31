import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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

class ChatPage extends StatefulWidget {
  final String? partnerId;
  const ChatPage({super.key, this.partnerId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isRedirecting = false;
  
  // Cache untuk menyimpan profil user yang sudah di-fetch
  // Key: User ID, Value: Map Profile Data
  final Map<String, Map<String, dynamic>> _profileCache = {};
  
  // Set untuk menyimpan ID yang sedang dalam proses fetch agar tidak double request
  final Set<String> _fetchingIds = {};

  // Pastel Color Palette
  final List<Color> _pastelColors = [
    const Color(0xFFE3F2FD), // Blue Light
    const Color(0xFFF3E5F5), // Purple Light
    const Color(0xFFE0F2F1), // Teal Light
    const Color(0xFFFFF3E0), // Orange Light
    const Color(0xFFFFEBEE), // Pink Light
  ];

  @override
  void initState() {
    super.initState();
    if (widget.partnerId != null) {
      _handleAutoRedirect(widget.partnerId!);
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
      final response = await _supabase.from('social_chats')
          .select().contains('participants', [myId, partnerId]).eq('is_group', false).maybeSingle();

      String chatId;
      if (response != null) {
        chatId = response['id'];
      } else {
        final newChat = await _supabase.from('social_chats').insert({
          'participants': [myId, partnerId],
          'is_group': false,
          'updated_at': DateTime.now().toIso8601String(),
          'last_message': 'Memulai percakapan',
        }).select().single();
        chatId = newChat['id'];
      }

      final profile = await _supabase.from('profiles').select().eq('id', partnerId).single();

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SocialChatDetailPage(
          chatId: chatId, opponentProfile: profile, isGroup: false
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
          .filter('id', 'in', idsToFetch);

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

  @override
  Widget build(BuildContext context) {
    if (_isRedirecting) {
      return const Scaffold(
        body: AppStateView(state: AppViewState.loading),
      );
    }
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) {
      return const Scaffold(
        body: AppStateView(
          state: AppViewState.error,
          error: AppError(
            title: "Sesi berakhir",
            message: "Silakan login ulang.",
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background, 
      appBar: AppBar(
        title: Text("Pesan", style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 22)),
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
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchUserPage())),
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
         child: FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupPage())),
          backgroundColor: Colors.transparent, 
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('social_chats')
                  .stream(primaryKey: ['id'])
                  .contains('participants', [myId])
                  .order('updated_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const AppStateView(state: AppViewState.loading);
                }

                if (snapshot.hasError) {
                  return AppStateView(
                    state: AppViewState.error,
                    error: const AppError(
                      title: "Gagal memuat chat",
                      message: "Koneksi bermasalah. Coba lagi.",
                    ),
                    onRetry: () => setState(() {}),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const AppStateView(
                    state: AppViewState.empty,
                    emptyTitle: "Belum ada pesan",
                    emptyMessage: "Mulai percakapan baru dari tombol +",
                  );
                }
                
                final allChats = snapshot.data!;
                final myChats = allChats.where((chat) {
                   final participants = List<dynamic>.from(chat['participants'] ?? []);
                   return participants.contains(myId);
                }).toList();

                if (myChats.isEmpty) {
                  return const AppStateView(
                    state: AppViewState.empty,
                    emptyTitle: "Belum ada pesan",
                    emptyMessage: "Mulai percakapan baru dari tombol +",
                  );
                }

                // --- BATCH FETCHING TRIGGER ---
                final missingIds = <String>[];
                for (var chat in myChats) {
                  if (chat['is_group'] != true) {
                    final participants = List<dynamic>.from(chat['participants'] ?? []);
                    final partnerId = participants.firstWhere((id) => id != myId, orElse: () => null);
                    if (partnerId != null && !_profileCache.containsKey(partnerId)) {
                      missingIds.add(partnerId);
                    }
                  }
                }
                
                if (missingIds.isNotEmpty) {
                  Future.microtask(() => _fetchMissingProfiles(missingIds));
                }
                // ------------------------------

                return AnimationLimiter(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 12),
                    itemCount: myChats.length,
                    itemBuilder: (context, index) {
                      final chat = myChats[index];
                      Map<String, dynamic>? partnerProfile;
                      String myIdVerified = myId;

                      if (chat['is_group'] != true) {
                         final participants = List<dynamic>.from(chat['participants'] ?? []);
                         final partnerId = participants.firstWhere((id) => id != myId, orElse: () => null);
                         if (partnerId != null) {
                           partnerProfile = _profileCache[partnerId];
                         }
                      }

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _ChatTile(
                              chatData: chat, 
                              myId: myIdVerified,
                              partnerProfile: partnerProfile,
                              backgroundColor: _pastelColors[index % _pastelColors.length], // Cyclic Color
                            ),
                          ),
                        ),
                      );
                    },
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
  final Color backgroundColor;

  const _ChatTile({
    required this.chatData, 
    required this.myId, 
    this.partnerProfile,
    required this.backgroundColor,
  });

  Future<void> _deleteChat(BuildContext context) async {
    final chatId = chatData['id'];
    final supabase = Supabase.instance.client;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Hapus Chat?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Obrolan ini akan dihapus permanen.", style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal", style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                // Delete logic
                await supabase.from('social_chats').delete().eq('id', chatId);
                if (context.mounted) {
                  AppSnackBar.showSuccess(context, "Chat berhasil dihapus");
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackBar.showError(context, "Gagal hapus chat.");
                }
              }
            },
            child: Text("Hapus", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
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
          color: backgroundColor, // Cyclic Pastel Color
          borderRadius: BorderRadius.circular(20), 
          // Flat Block style: No heavy shadow
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
                chatId: chatData['id'], isGroup: isGroup, opponentProfile: profileForNav
              )));
            },
            onLongPress: () => _deleteChat(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Slightly more vertical padding from original
              child: Row(
                 children: [
                   // Avatar with Thick White Border (Pop-up effect)
                   Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5), // Thick White Border
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
                             style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF1E293B)), // W700 Bold
                             maxLines: 1
                          ),
                          const SizedBox(height: 4),
                          Text(
                             chatData['last_message'] ?? '', 
                             maxLines: 1, 
                             overflow: TextOverflow.ellipsis, 
                             style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.normal)
                          ),
                        ],
                     ),
                   ),
                   
                   const SizedBox(width: 8),
                   
                   // Time
                   Text(
                      time, 
                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)
                   ),
                 ],
              ),
            ),
          ),
        ),
      );
  }
}
