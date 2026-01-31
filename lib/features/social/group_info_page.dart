import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/features/social/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/features/profile/pages/profile_page.dart';
import 'package:mychatolic_app/core/ui/permission_prompt.dart';

class GroupInfoPage extends StatefulWidget {
  final String chatId;

  const GroupInfoPage({super.key, required this.chatId});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  Map<String, dynamic>? _groupData;
  List<Map<String, dynamic>> _participants = [];
  String? _currentUserId;
  bool _amIAdmin = false;
  
  // Edit States
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  final Color kPrimary = const Color(0xFF0088CC);

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    _fetchGroupData();
  }

  Future<void> _fetchGroupData() async {
    try {
      // 1. Fetch Group Info
      final groupResponse = await _supabase
          .from('social_chats')
          .select()
          .eq('id', widget.chatId)
          .single();

      // 2. Fetch Participants (via chat_members pivot)
      final membersResponse = await _supabase
          .from('chat_members')
          .select('joined_at, user_id, role, profiles:user_id(full_name, avatar_url)')
          .eq('chat_id', widget.chatId);

      final adminId = groupResponse['admin_id'];

      // Process Data
      List<Map<String, dynamic>> participants = [];
      bool currentUserIsAdmin = false;

      for (var member in membersResponse) {
        final profile = member['profiles'] as Map<String, dynamic>?;
        final uid = member['user_id'];
        final role = member['role']; // 'admin' or 'member' (or null)

        // Determine if this user is admin (Check role column OR legacy admin_id)
        final bool isUserAdmin = (role == 'admin') || (uid == adminId);

        if (uid == _currentUserId && isUserAdmin) {
          currentUserIsAdmin = true;
        }

        participants.add({
          'user_id': uid,
          'full_name': profile?['full_name'] ?? 'Unknown',
          'avatar_url': profile?['avatar_url'],
          'joined_at': member['joined_at'],
          'role': isUserAdmin ? 'admin' : 'member',
        });
      }

      // Sort: Admins first, then Alphabetical
      participants.sort((a, b) {
        if (a['role'] == 'admin' && b['role'] != 'admin') return -1;
        if (a['role'] != 'admin' && b['role'] == 'admin') return 1;
        return (a['full_name'] as String).compareTo(b['full_name'] as String);
      });

      if (mounted) {
        setState(() {
            _groupData = groupResponse;
            _participants = participants;
            _amIAdmin = currentUserIsAdmin;
            _nameController.text = groupResponse['group_name'] ?? '';
            _descController.text = groupResponse['description'] ?? '';
            _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("Error loading group info: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACTIONS: GROUP ---

  Future<void> _updateGroupIcon() async {
    final allowed = await PermissionPrompt.requestGallery(context);
    if (!allowed) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final fileExt = picked.path.split('.').last;
    final fileName = 'group_avatar_${widget.chatId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    try {
       await _supabase.storage.from('chat-uploads').upload(fileName, file);
       final publicUrl = _supabase.storage.from('chat-uploads').getPublicUrl(fileName);

       await _supabase.from('social_chats').update({'group_avatar_url': publicUrl}).eq('id', widget.chatId);
       
       _fetchGroupData();
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto grup diperbarui")));
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal upload: $e")));
    }
  }

  Future<void> _editNameOrDesc(String field, String title, TextEditingController controller) async {
    final newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Ubah $title", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "Masukkan $title baru"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text("Simpan")),
        ],
      ),
    );

    if (newValue != null) {
      try {
        await _supabase.from('social_chats').update({field: newValue}).eq('id', widget.chatId);
        _fetchGroupData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal update: $e")));
      }
    }
  }

  Future<void> _exitGroup() async {
    final confirm = await _showConfirmDialog("Keluar Grup", "Apakah Anda yakin ingin keluar?", isDestructive: true);
    if (!confirm || _currentUserId == null) return;

    try {
      await _supabase.from('chat_members').delete().eq('chat_id', widget.chatId).eq('user_id', _currentUserId!);
      
      // Update participants array in parent table too for consistency
      final group = await _supabase.from('social_chats').select('participants').eq('id', widget.chatId).single();
      List<dynamic> parts = List.from(group['participants'] ?? []);
      parts.remove(_currentUserId);
      await _supabase.from('social_chats').update({'participants': parts}).eq('id', widget.chatId);

      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal keluar: $e")));
    }
  }

  Future<void> _deleteGroup() async {
     final confirm = await _showConfirmDialog("Hapus Grup", "Grup akan dihapus permanen. Lanjutkan?", isDestructive: true);
    if (!confirm) return;

    try {
       await _supabase.from('social_chats').delete().eq('id', widget.chatId);
        if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal hapus: $e")));
    }
  }

  // --- ACTIONS: ADD MEMBER ---
  void _showAddMemberSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MutualFriendsSheet(
        chatId: widget.chatId,
        existingMemberIds: _participants.map((e) => e['user_id'] as String).toSet(),
        onMemberAdded: () {
          Navigator.pop(context);
          _fetchGroupData();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Anggota berhasil ditambahkan")));
        },
      ),
    );
  }

  // --- ACTIONS: PARTICIPANTS ---

  void _showParticipantOptions(Map<String, dynamic> user) {
    if (_currentUserId == null) return;
    final isMe = user['user_id'] == _currentUserId;
    final isTargetAdmin = user['role'] == 'admin';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               const SizedBox(height: 10),
               Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
               const SizedBox(height: 10),
               Text(user['full_name'], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 4),
               const Divider(),
               
               // 1. Message & Profile
               if (!isMe) ...[
                 ListTile(
                    leading: const Icon(Icons.message_outlined, color: Colors.blue),
                    title: const Text("Kirim Pesan"),
                    onTap: () { Navigator.pop(context); _startPrivateChat(user); },
                 ),
                 ListTile(
                    leading: const Icon(Icons.person_outline, color: Colors.blue),
                    title: const Text("Lihat Profil"),
                    onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: user['user_id'], isBackButtonEnabled: true))); },
                 ),
                 const Divider(),
               ],

               // 2. Admin Actions
               if (_amIAdmin && !isMe) ...[
                  if (isTargetAdmin)
                    ListTile(
                      leading: const Icon(Icons.remove_moderator, color: Colors.orange),
                      title: const Text("Berhentikan jadi Admin"),
                      onTap: () { Navigator.pop(context); _updateRole(user['user_id'], 'member'); },
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.add_moderator, color: Colors.green),
                      title: const Text("Jadikan Admin"),
                      onTap: () { Navigator.pop(context); _updateRole(user['user_id'], 'admin'); },
                    ),

                  ListTile(
                    leading: const Icon(Icons.person_remove, color: Colors.red),
                    title: const Text("Keluarkan dari Group"),
                    onTap: () { Navigator.pop(context); _removeUser(user['user_id']); },
                  ),
               ],
               const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startPrivateChat(Map<String, dynamic> user) async {
    final targetId = user['user_id'];
    try {
      final response = await _supabase.from('social_chats')
          .select()
          .contains('participants', [_currentUserId, targetId])
          .eq('is_group', false)
          .maybeSingle();

      String chatId;
      if (response != null) {
        chatId = response['id'];
      } else {
        final newChat = await _supabase.from('social_chats').insert({
          'participants': [_currentUserId, targetId],
          'is_group': false,
          'updated_at': DateTime.now().toIso8601String(),
          'last_message': 'Memulai percakapan',
        }).select().single();
        chatId = newChat['id'];
      }

      final profile = {
        'id': targetId,
        'full_name': user['full_name'],
        'avatar_url': user['avatar_url'],
      };

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SocialChatDetailPage(chatId: chatId, opponentProfile: profile, isGroup: false),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal membuka chat")));
    }
  }

  Future<void> _updateRole(String userId, String newRole) async {
    try {
      await _supabase.from('chat_members').update({'role': newRole}).eq('chat_id', widget.chatId).eq('user_id', userId);
      _fetchGroupData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User sekarang $newRole")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal update role")));
    }
  }

  Future<void> _removeUser(String userId) async {
    final confirm = await _showConfirmDialog("Keluarkan Anggota", "Yakin ingin mengeluarkan user ini?");
    if (!confirm) return;
    try {
      await _supabase.from('chat_members').delete().eq('chat_id', widget.chatId).eq('user_id', userId);
      
      final group = await _supabase.from('social_chats').select('participants').eq('id', widget.chatId).single();
      List<dynamic> parts = List.from(group['participants'] ?? []);
      parts.remove(userId);
      await _supabase.from('social_chats').update({'participants': parts}).eq('id', widget.chatId);
      
      _fetchGroupData();
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menghapus user")));
    }
  }

  // --- HELPERS ---
  Future<bool> _showConfirmDialog(String title, String content, {bool isDestructive = false}) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(content, style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text("Ya", style: TextStyle(color: isDestructive ? Colors.red : kPrimary, fontWeight: FontWeight.bold))
          ),
        ],
      )
    ) ?? false;
  }

  // --- BUILD UI ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_groupData == null) return const Scaffold(body: Center(child: Text("Data grup tidak ditemukan")));
    
    final avatarUrl = _groupData!['group_avatar_url'];
    final desc = _groupData!['description'] ?? 'Tidak ada deskripsi';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text("Info Grup", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            
            // 1. Group Icon
            Center(
              child: Stack(
                children: [
                   Container(
                     width: 110, height: 110,
                     decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[200]),
                     child: ClipOval(
                       child: SafeNetworkImage(
                         imageUrl: avatarUrl, 
                         width: 110, height: 110, fit: BoxFit.cover,
                         fallbackIcon: Icons.groups,
                       ),
                     ),
                   ),
                   if (_amIAdmin)
                     Positioned(
                       bottom: 0, right: 0,
                       child: GestureDetector(
                         onTap: _updateGroupIcon,
                         child: Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(color: kPrimary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                           child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                         ),
                       ),
                     )
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Name & Description
            Padding(
               padding: const EdgeInsets.symmetric(horizontal: 24),
               child: Column(
                 children: [
                   // Name
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Flexible(
                         child: Text(
                            _groupData!['group_name'] ?? "Grup",
                            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                         ),
                       ),
                       if (_amIAdmin) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _editNameOrDesc('group_name', 'Nama Group', _nameController),
                            child: const Icon(Icons.edit, size: 16, color: Colors.grey),
                          )
                       ]
                     ],
                   ),
                   const SizedBox(height: 8),
                   // Description
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Flexible(
                         child: Text(
                            desc,
                            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                         ),
                       ),
                       if (_amIAdmin) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _editNameOrDesc('description', 'Deskripsi', _descController),
                            child: const Icon(Icons.edit, size: 14, color: Colors.grey),
                          )
                       ]
                     ],
                   ),
                 ],
               ),
            ),

            const SizedBox(height: 24),
            const Divider(thickness: 6, color: Color(0xFFF5F5F5)),

            // 3. Participants Header with Add Button Option
            Padding(
               padding: const EdgeInsets.all(16),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text("${_participants.length} Peserta", style: GoogleFonts.outfit(color: kPrimary, fontWeight: FontWeight.bold)),
                   const Icon(Icons.search, color: Colors.grey),
                 ],
               ),
            ),
            
            // Add Member List Tile
            GestureDetector(
               onTap: _showAddMemberSheet,
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                 color: Colors.transparent, 
                 child: Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), shape: BoxShape.circle),
                       child: Icon(Icons.person_add_alt_1_rounded, color: kPrimary, size: 20),
                     ),
                     const SizedBox(width: 16),
                     Text("Tambah Anggota", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: kPrimary, fontSize: 16)),
                   ],
                 ),
               ),
            ),
            const Divider(height: 1),

            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _participants.length,
              separatorBuilder: (_,__) => const Divider(indent: 70, height: 1),
              itemBuilder: (context, index) {
                 final user = _participants[index];
                 final isAdmin = user['role'] == 'admin';
                 final isMe = user['user_id'] == _currentUserId;

                 return ListTile(
                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                   leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                      child: user['avatar_url'] == null ? const Icon(Icons.person, size: 20, color: Colors.grey) : null,
                   ),
                   title: Row(
                     children: [
                       Flexible(child: Text(isMe ? "Anda" : user['full_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15))),
                       if (isAdmin) ...[
                          const SizedBox(width: 8),
                          Container(
                             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                             decoration: BoxDecoration(color: Colors.green[50], border: Border.all(color: Colors.green, width: 0.5), borderRadius: BorderRadius.circular(4)),
                             child: Text("Admin", style: GoogleFonts.outfit(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                          )
                       ]
                     ],
                   ),
                   subtitle: Text(user['role'] == 'admin' ? "Admin Grup" : "Anggota", style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                   onTap: () => _showParticipantOptions(user),
                 );
              },
            ),

            const SizedBox(height: 10),
            const Divider(thickness: 6, color: Color(0xFFF5F5F5)),

            // 4. Actions
            ListTile(
               leading: const Icon(Icons.exit_to_app, color: Colors.red),
               title: Text("Keluar dari Grup", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.w600)),
               onTap: _exitGroup,
            ),
            
            if (_amIAdmin)
               ListTile(
                 leading: const Icon(Icons.delete_forever, color: Colors.red),
                 title: Text("Hapus Grup", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.w600)),
                 onTap: _deleteGroup,
               ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// --- MUTUAL FRIEND SHEET ---

class _MutualFriendsSheet extends StatefulWidget {
  final String chatId;
  final Set<String> existingMemberIds;
  final VoidCallback onMemberAdded;

  const _MutualFriendsSheet({required this.chatId, required this.existingMemberIds, required this.onMemberAdded});

  @override
  State<_MutualFriendsSheet> createState() => _MutualFriendsSheetState();
}

class _MutualFriendsSheetState extends State<_MutualFriendsSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _candidates = [];

  @override
  void initState() {
    super.initState();
    _fetchMutualFriends();
  }

  Future<void> _fetchMutualFriends() async {
    try {
      final myId = _supabase.auth.currentUser!.id;
      
      // 1. Who I follow (follower_id = me) -> Get 'following_id'
      final followingResp = await _supabase.from('follows').select('following_id').eq('follower_id', myId);
      final Set<String> iFollow = (followingResp as List).map((e) => e['following_id'] as String).toSet();
      
      // 2. Who follows me (following_id = me) -> Get 'follower_id'
      final followersResp = await _supabase.from('follows').select('follower_id').eq('following_id', myId);
      final Set<String> followsMe = (followersResp as List).map((e) => e['follower_id'] as String).toSet();

      // 3. Mutual = Intersection
      final mutualIds = iFollow.intersection(followsMe);

      // 4. Filter out existing group members
      final candidateIds = mutualIds.difference(widget.existingMemberIds);

      if (candidateIds.isEmpty) {
        if (mounted) setState(() { _candidates = []; _isLoading = false; });
        return;
      }

      // 5. Fetch their profiles
      final profilesResp = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .filter('id', 'in', candidateIds.toList());
      
      if (mounted) {
        setState(() {
          _candidates = List<Map<String, dynamic>>.from(profilesResp);
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("Error fetching mutuals: $e");
      if (mounted) setState(() { _isLoading = false; }); 
    }
  }

  Future<void> _addMember(Map<String, dynamic> user) async {
     try {
       // 1. Insert to chat_members
       await _supabase.from('chat_members').insert({
         'chat_id': widget.chatId,
         'user_id': user['id'],
         'role': 'member',
         'joined_at': DateTime.now().toIso8601String(),
       });

       // 2. Update participants array in social_chats
       final group = await _supabase.from('social_chats').select('participants').eq('id', widget.chatId).single();
       List<dynamic> currentParticipants = List.from(group['participants'] ?? []);
       if (!currentParticipants.contains(user['id'])) {
          currentParticipants.add(user['id']);
          await _supabase.from('social_chats').update({'participants': currentParticipants}).eq('id', widget.chatId);
       }

       // 3. System Message
       final myName = _supabase.auth.currentUser?.userMetadata?['full_name'] ?? 'Member';
       await _supabase.from('social_messages').insert({
          'chat_id': widget.chatId,
          'sender_id': _supabase.auth.currentUser!.id,
          'content': 'Menambahkan ${user['full_name']} ke grup',
          'type': 'text', // Safe fallback
       });

       widget.onMemberAdded();

     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menambah: $e")));
     }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Center(child: Text("Tambah Peserta", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold))),
          Center(child: Text("Teman bisa di add jika sudah saling follow", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic))),
          const SizedBox(height: 16),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _candidates.isEmpty 
                  ? Center(child: Text("Tidak ada teman mutual baru.", style: GoogleFonts.outfit(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _candidates.length,
                      itemBuilder: (context, index) {
                        final user = _candidates[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                            child: user['avatar_url'] == null ? const Icon(Icons.person) : null,
                          ),
                          title: Text(user['full_name'] ?? "No Name", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          trailing: Container(
                            decoration: const BoxDecoration(color: Color(0xFF0088CC), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white, size: 20),
                              onPressed: () => _addMember(user),
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
