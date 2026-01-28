import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/features/profile/pages/profile_page.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class SearchUserPage extends StatefulWidget {
  const SearchUserPage({super.key});

  @override
  State<SearchUserPage> createState() => _SearchUserPageState();
}

class _SearchUserPageState extends State<SearchUserPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- STATES ---
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _dioceses = [];
  List<Map<String, dynamic>> _churches = [];

  Map<String, dynamic>? _selectedCountry;
  Map<String, dynamic>? _selectedDiocese;
  Map<String, dynamic>? _selectedChurch;

  final TextEditingController _nameController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;

  // Colors & Styles
  final Color kPrimary = const Color(0xFF0088CC);
  final Color kTextPrimary = const Color(0xFF0F172A);
  final Color kTextSecondary = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _fetchCountries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- API LOGIC (MAINTAINED) ---
  Future<void> _fetchCountries() async {
    try {
      final data = await _supabase.from('countries').select('id, name').order('name');
      if (mounted) setState(() => _countries = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint("Error countries: $e"); }
  }

  Future<void> _fetchDioceses(String countryId) async {
    try {
      final data = await _supabase.from('dioceses').select('id, name').eq('country_id', countryId).order('name');
      if (mounted) setState(() => _dioceses = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint("Error dioceses: $e"); }
  }

  Future<void> _fetchChurches(String dioceseId) async {
    try {
      final data = await _supabase.from('churches').select('id, name').eq('diocese_id', dioceseId).order('name');
      if (mounted) setState(() => _churches = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint("Error churches: $e"); }
  }

  Future<void> _searchUsers() async {
    if (_selectedChurch == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon pilih Gereja terlebih dahulu")));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      var query = _supabase
          .from('profiles')
          .select('id, full_name, avatar_url, church_id')
          .eq('church_id', _selectedChurch!['id']);

      final nameQuery = _nameController.text.trim();
      if (nameQuery.isNotEmpty) {
        query = query.ilike('full_name', '%$nameQuery%');
      }

      final data = await query.limit(50);
      
      if (mounted) setState(() { _users = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      debugPrint("Error search: $e");
      if (mounted) setState(() { _isLoading = false; _users = []; });
    }
  }

  Future<void> _startChat(Map<String, dynamic> userProfile) async {
    final myId = _supabase.auth.currentUser?.id;
    final partnerId = userProfile['id'];
    if (myId == null || partnerId == null) return;
    try {
      String chatId;
      final existing = await _supabase.from('social_chats').select().contains('participants', [myId, partnerId]).maybeSingle();
      if (existing != null) chatId = existing['id'];
      else {
        final newChat = await _supabase.from('social_chats').insert({'participants': [myId, partnerId], 'updated_at': DateTime.now().toIso8601String(), 'last_message': "Memulai percakapan"}).select().single();
        chatId = newChat['id'];
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => SocialChatDetailPage(chatId: chatId, opponentProfile: userProfile)));
    } catch (e) { 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal membuka chat"))); 
    }
  }

  void _openSearchSheet(String title, List<Map<String, dynamic>> items, Function(Map<String, dynamic>) onSelect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final filtered = items.where((item) {
               final name = (item['name'] ?? '').toString().toLowerCase();
               return name.contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: TextField(
                        autofocus: false,
                        onChanged: (val) => setStateSheet(() => searchQuery = val),
                        style: GoogleFonts.outfit(fontSize: 16, color: kTextPrimary),
                        decoration: InputDecoration(
                          hintText: "Cari $title...",
                          prefixIcon: Icon(Icons.search, color: kPrimary),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: filtered.length,
                        separatorBuilder: (_,__) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
                        itemBuilder: (ctx, idx) {
                           final item = filtered[idx];
                           return ListTile(
                             contentPadding: const EdgeInsets.symmetric(vertical: 4),
                             title: Text(item['name'] ?? '-', style: GoogleFonts.outfit(fontSize: 16, color: kTextPrimary)),
                             trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                             onTap: () {
                               Navigator.pop(context);
                               onSelect(item);
                             },
                           );
                        },
                      ),
                    ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       extendBodyBehindAppBar: true,
       appBar: AppBar(
        title: Text("Cari Sahabat", style: GoogleFonts.outfit(color: kTextPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withOpacity(0.8), 
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
      ),
      body: Container(
        color: Colors.white, 
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
               Expanded(
                 child: SingleChildScrollView(
                   padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                   physics: const BouncingScrollPhysics(),
                   child: Column(
                     children: [
                        // --- FILTER CARD ---
                        Container(
                           padding: const EdgeInsets.all(24),
                           decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(24),
                             boxShadow: [
                                BoxShadow(color: const Color(0xFF0088CC).withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))
                             ],
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.stretch,
                             children: [
                               Text("Filter Wilayah", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: kTextPrimary)),
                               const SizedBox(height: 20),
                               
                               // 1. Country Selection (Blue pastel)
                               _buildColorfulSelectField(
                                 label: "Negara",
                                 value: _selectedCountry?['name'],
                                 icon: Icons.public,
                                 themeColor: Colors.blue,
                                 onTap: () => _openSearchSheet("Negara", _countries, (val) {
                                    setState(() {
                                       _selectedCountry = val;
                                       _selectedDiocese = null; _selectedChurch = null;
                                       _dioceses = []; _churches = [];
                                    });
                                    _fetchDioceses(val['id']);
                                 }),
                               ),
                               const SizedBox(height: 16),

                               // 2. Diocese Selection (Purple pastel)
                               _buildColorfulSelectField(
                                 label: "Keuskupan",
                                 value: _selectedDiocese?['name'],
                                 icon: Icons.account_balance,
                                 themeColor: Colors.purple,
                                 enabled: _selectedCountry != null,
                                 onTap: () => _openSearchSheet("Keuskupan", _dioceses, (val) {
                                    setState(() {
                                       _selectedDiocese = val; _selectedChurch = null;
                                       _churches = [];
                                    });
                                    _fetchChurches(val['id']);
                                 }),
                               ),
                               const SizedBox(height: 16),

                               // 3. Church Selection (Orange pastel)
                               _buildColorfulSelectField(
                                 label: "Gereja / Paroki",
                                 value: _selectedChurch?['name'],
                                 icon: Icons.church,
                                 themeColor: Colors.orange,
                                 enabled: _selectedDiocese != null,
                                 onTap: () => _openSearchSheet("Gereja", _churches, (val) {
                                    setState(() => _selectedChurch = val);
                                 }),
                               ),
                               const SizedBox(height: 16),

                               // 4. Name Input
                               TextField(
                                  controller: _nameController,
                                  style: GoogleFonts.outfit(color: kTextPrimary),
                                  enabled: _selectedChurch != null,
                                  decoration: InputDecoration(
                                    hintText: "Cari Nama Umat (Opsional)",
                                    prefixIcon: Icon(Icons.person_search_rounded, color: _selectedChurch != null ? kTextSecondary : Colors.grey[300]),
                                    filled: true,
                                    fillColor: Colors.grey[50], 
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                  onSubmitted: (_) => _searchUsers(),
                               ),
                               const SizedBox(height: 24),

                               // BUTTON: GRADIENT GLOWING
                               GestureDetector(
                                 onTap: _selectedChurch == null ? null : _searchUsers,
                                 child: Container(
                                   height: 56,
                                   decoration: BoxDecoration(
                                     gradient: LinearGradient(
                                       colors: _selectedChurch != null 
                                          ? [const Color(0xFF00C6FF), const Color(0xFF0072FF)] // Updated Gradient
                                          : [Colors.grey.shade300, Colors.grey.shade400],
                                     ),
                                     borderRadius: BorderRadius.circular(30),
                                     boxShadow: _selectedChurch != null 
                                        ? [BoxShadow(color: const Color(0xFF0072FF).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]
                                        : [],
                                   ),
                                   child: Center(
                                     child: _isLoading 
                                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                        : Text(
                                            "LIHAT UMAT", 
                                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)
                                          ),
                                   ),
                                 ),
                               ),
                             ],
                           ),
                        ),

                        // --- RESULT SECTION ---
                        
                        if (_users.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
                            child: Row(
                              children: [
                                Text("Hasil Pencarian", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                                  child: Text("${_users.length} Ditemukan", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: kTextSecondary)),
                                ),
                              ],
                            ),
                          ),

                        if (_users.isNotEmpty)
                          AnimationLimiter(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _users.length,
                              separatorBuilder: (_,__) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                return AnimationConfiguration.staggeredList(
                                   position: index,
                                   duration: const Duration(milliseconds: 600),
                                   child: SlideAnimation(
                                     verticalOffset: 40.0,
                                     child: FadeInAnimation(
                                       child: _buildUserCard(user),
                                     ),
                                   ),
                                );
                              },
                            ),
                          )
                        else if (!_isLoading && _selectedChurch != null && _users.isEmpty)
                           Padding(
                             padding: const EdgeInsets.only(top: 60),
                             child: Column(
                                children: [
                                   Icon(Icons.person_off_rounded, size: 64, color: Colors.grey[300]),
                                   const SizedBox(height: 12),
                                   Text("Belum ada hasil", style: GoogleFonts.outfit(fontSize: 16, color: kTextSecondary, fontWeight: FontWeight.w500)),
                                ],
                             ),
                           )
                     ],
                   ),
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorfulSelectField({
    required String label, 
    required String? value, 
    required IconData icon,
    required MaterialColor themeColor,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    // Pastel background logic
    final bgColor = enabled ? themeColor.shade50 : Colors.grey[50];
    final iconColor = enabled ? themeColor.shade700 : Colors.grey[400];
    final textColor = enabled ? kTextPrimary : Colors.grey[400];

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor, // Colorful block background
          borderRadius: BorderRadius.circular(16), // Rounded block
          // No border for block style
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white, // White circle for icon to pop
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (value != null)
                     Text(label, style: GoogleFonts.outfit(fontSize: 10, color: themeColor.shade300, fontWeight: FontWeight.w600)),
                  Text(
                    value ?? label, 
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: value != null ? FontWeight.w600 : FontWeight.normal
                    ),
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: (iconColor ?? Colors.grey).withOpacity(0.5)),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      key: ValueKey(user['id']),
      decoration: BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.circular(20),
         border: Border.all(color: Colors.grey.shade100), // Subtle border
         boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
         ]
      ),
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
               builder: (_) => ProfilePage(userId: user['id'], isBackButtonEnabled: true), 
            ),
          );
        },
        child: Container(
          color: Colors.transparent, 
          child: Row(
             children: [
               // Avatar with Gradient Story-like Border
               Container(
                 padding: const EdgeInsets.all(2.5),
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   gradient: LinearGradient(
                     colors: [const Color(0xFF00C6FF), const Color(0xFF0072FF)],
                     begin: Alignment.topLeft, 
                     end: Alignment.bottomRight
                   ),
                 ),
                 child: Container(
                   decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                   padding: const EdgeInsets.all(2),
                   child: ClipOval(
                      child: SafeNetworkImage(
                        imageUrl: user['avatar_url'], 
                        width: 46, 
                        height: 46, 
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.person,
                      ),
                   ),
                 ),
               ),
               const SizedBox(width: 16),
               
               // Info
               Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] ?? 'Umat',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                         _selectedChurch?['name'] ?? 'Gereja',
                         style: GoogleFonts.outfit(fontSize: 12, color: kTextSecondary),
                         maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                 ),
               ),
               
               // Chat Action
               Material(
                 color: Colors.transparent,
                 child: InkWell(
                   onTap: () => _startChat(user),
                   borderRadius: BorderRadius.circular(12),
                   child: Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(
                       color: const Color(0xFF00C6FF).withOpacity(0.1),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: const Icon(Icons.send_rounded, color: Color(0xFF0072FF), size: 20),
                   ),
                 ),
               ),
             ],
          ),
        ),
      ),
    );
  }
}
