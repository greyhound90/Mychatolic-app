import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart'; // Pastikan import ini ada

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  File? _imageFile;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final Set<String> _selectedUserIds = {};
  
  bool _isLoading = false;
  bool _isCreating = false;

  final Color kPrimary = const Color(0xFF0088CC);

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final myId = _supabase.auth.currentUser?.id;
    try {
      final data = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .neq('id', myId ?? '')
          .limit(50);

      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(data);
          _filteredUsers = _allUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterUsers(String query) {
    if (query.isEmpty) {
      setState(() => _filteredUsers = _allUsers);
    } else {
      setState(() {
        _filteredUsers = _allUsers.where((u) {
          final name = (u['full_name'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama grup wajib diisi")));
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih minimal 1 anggota")));
      return;
    }

    setState(() => _isCreating = true);
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // 1. Upload Image (Optional)
      String? uploadedAvatarUrl;
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = 'group_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        await _supabase.storage.from('chat-uploads').upload(fileName, _imageFile!);
        uploadedAvatarUrl = _supabase.storage.from('chat-uploads').getPublicUrl(fileName);
      }

      final participantList = [myId, ..._selectedUserIds];

      // 2. Insert Social Chat
      final chatData = await _supabase
          .from('social_chats')
          .insert({
            'is_group': true,
            'group_name': groupName,
            'group_avatar_url': uploadedAvatarUrl,
            'admin_id': myId,
            'updated_at': DateTime.now().toIso8601String(),
            'last_message': 'Grup "$groupName" dibuat',
            'participants': participantList, 
          })
          .select()
          .single();

      final chatId = chatData['id'];

      // 3. Insert Chat Members (Pivot)
      final List<Map<String, dynamic>> membersData = participantList.map((uid) {
        return { 'chat_id': chatId, 'user_id': uid };
      }).toList();

      await _supabase.from('chat_members').insert(membersData);

      if (!mounted) return;

      // 4. Navigate
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SocialChatDetailPage(
            chatId: chatId,
            isGroup: true,
            opponentProfile: {
              'id': chatId,
              'full_name': groupName,
              'avatar_url': uploadedAvatarUrl,
              'group_name': groupName,
              'group_avatar_url': uploadedAvatarUrl,
            },
          ),
        ),
      );

    } catch (e) {
      debugPrint("Create Group Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Buat Grup Baru", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreating ? null : _createGroup,
        backgroundColor: kPrimary,
        icon: _isCreating 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.check, color: Colors.white),
        label: Text("BUAT GRUP", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Column(
        children: [
          // Header Input
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey[50],
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                      image: _imageFile != null 
                        ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : null,
                    ),
                    child: _imageFile == null 
                        ? const Icon(Icons.camera_alt, color: Colors.grey, size: 30) 
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _groupNameController,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "Nama Grup...",
                      hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: "Cari anggota...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // User List
          Expanded(
             child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80), 
                    itemCount: _filteredUsers.length,
                    separatorBuilder: (_,__) => const Divider(height: 1, indent: 70),
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final isSelected = _selectedUserIds.contains(user['id']);
                      final avatarUrl = user['avatar_url'];

                      // LOGIC GAMBAR AMAN (Mencegah Crash UI)
                      Widget avatarWidget;
                      if (avatarUrl != null && avatarUrl.toString().isNotEmpty && !avatarUrl.toString().startsWith('file://')) {
                        avatarWidget = CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(avatarUrl),
                          backgroundColor: Colors.grey[200],
                        );
                      } else {
                        avatarWidget = CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[200],
                          child: const Icon(Icons.person, color: Colors.grey),
                        );
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: avatarWidget,
                        title: Text(user['full_name'] ?? 'User', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        trailing: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? kPrimary : Colors.transparent,
                            border: Border.all(color: isSelected ? kPrimary : Colors.grey, width: 2),
                            shape: BoxShape.circle,
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                        ),
                        onTap: () => _toggleSelection(user['id']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}