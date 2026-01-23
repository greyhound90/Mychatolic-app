import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/app_colors.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/pages/profile_page.dart';
import 'package:mychatolic_app/services/master_data_service.dart';
import 'package:mychatolic_app/services/chat_service.dart';
import 'package:mychatolic_app/models/country.dart';
import 'package:mychatolic_app/models/diocese.dart';
import 'package:mychatolic_app/models/church.dart';
import 'package:mychatolic_app/services/social_service.dart';
import 'package:mychatolic_app/models/profile.dart';

class SearchUserPage extends StatefulWidget {
  const SearchUserPage({super.key});

  @override
  State<SearchUserPage> createState() => _SearchUserPageState();
}

class _SearchUserPageState extends State<SearchUserPage> {
  final MasterDataService _masterService = MasterDataService();
  final ChatService _chatService = ChatService();
  final SocialService _socialService = SocialService(); // Added SocialService
  final TextEditingController _searchController = TextEditingController();
  
  // Data
  List<Profile> _searchResults = []; // Changed to Profile Model
  bool _isLoading = false;

  // Filters (Using Models)
  List<Country> _countries = [];
  List<Diocese> _dioceses = [];
  List<Church> _churches = [];

  String? _selectedCountryId;
  String? _selectedDioceseId;
  String? _selectedChurchId;

  @override
  void initState() {
    super.initState();
    _fetchCountries(); 
    _searchUsers(""); 
  }

  /// Helper to fetch master data
  Future<void> _fetchCountries() async {
    try {
       final data = await _masterService.fetchCountries();
       if (mounted) setState(() => _countries = data);
    } catch (e) {
      debugPrint("Error fetching countries: $e");
    }
  }

  Future<void> _fetchDioceses(String countryId) async {
    try {
       final data = await _masterService.fetchDioceses(countryId);
       if (mounted) setState(() => _dioceses = data);
    } catch (e) {
      debugPrint("Error fetching dioceses: $e");
    }
  }

  Future<void> _fetchChurches(String dioceseId) async {
    try {
       final data = await _masterService.fetchChurches(dioceseId);
       if (mounted) setState(() => _churches = data);
    } catch (e) {
      debugPrint("Error fetching churches: $e");
    }
  }

  void _onCountryChanged(String? countryId) {
    setState(() {
      _selectedCountryId = countryId;
      _selectedDioceseId = null; 
      _selectedChurchId = null;
      _dioceses = [];
      _churches = [];
    });
    _searchUsers(_searchController.text);
    if (countryId != null) _fetchDioceses(countryId);
  }

  void _onDioceseChanged(String? dioceseId) {
    setState(() {
      _selectedDioceseId = dioceseId;
      _selectedChurchId = null;
      _churches = [];
    });
    _searchUsers(_searchController.text);
    if (dioceseId != null) _fetchChurches(dioceseId);
  }

  void _onChurchChanged(String? churchId) {
    setState(() {
      _selectedChurchId = churchId;
    });
    _searchUsers(_searchController.text);
  }

  Future<void> _searchUsers(String query) async {
    setState(() => _isLoading = true);
    
    try {
      final results = await _socialService.searchUsersAdvanced(
        query: query,
        countryId: _selectedCountryId,
        dioceseId: _selectedDioceseId,
        churchId: _selectedChurchId,
      );
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint("Search Error: $e");
      }
    }
  }

  Future<void> _startChat(Profile userProfile) async {
    try {
      final chatId = await _chatService.getOrCreatePrivateChat(userProfile.id);

      if (!mounted) return;

      // Navigate to chat detail
      Navigator.push( 
        context, 
        MaterialPageRoute(
          builder: (_) => SocialChatDetailPage(
            chatId: chatId, 
            opponentProfile: {
                'id': userProfile.id,
                'full_name': userProfile.fullName,
                'avatar_url': userProfile.avatarUrl,
            },
            otherUserId: userProfile.id,
          )
        )
      );

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error starting chat: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Slightly off-white background
      appBar: AppBar(
        title: Text("Cari Teman", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
      ),
      body: Column(
        children: [
          // 1. FILTER SECTION
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Name
                TextField(
                  controller: _searchController,
                  onChanged: (val) => _searchUsers(val),
                  decoration: InputDecoration(
                    labelText: "Cari Nama (Opsional)",
                    labelStyle: GoogleFonts.outfit(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryBrand),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryBrand),
                    ),
                  ),
                  style: GoogleFonts.outfit(),
                ),
                const SizedBox(height: 16),
                
                // Country Dropdown
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedCountryId),
                  initialValue: _selectedCountryId,
                  decoration: _inputDecoration("Pilih Negara", Icons.public),
                  items: _countries.map((c) {
                    return DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: _onCountryChanged,
                  isExpanded: true,
                  style: GoogleFonts.outfit(color: Colors.black),
                ),
                const SizedBox(height: 16),

                // Diocese Dropdown
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedDioceseId),
                  initialValue: _selectedDioceseId,
                  decoration: _inputDecoration("Pilih Keuskupan", Icons.account_balance),
                  items: _dioceses.map((d) {
                    return DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: _selectedCountryId == null ? null : _onDioceseChanged,
                  isExpanded: true,
                  style: GoogleFonts.outfit(color: Colors.black),
                  hint: Text("Pilih Keuskupan", style: GoogleFonts.outfit(color: Colors.grey)),
                  disabledHint: Text("Pilih Negara Terlebih Dahulu", style: GoogleFonts.outfit(color: Colors.grey)),
                ),
                const SizedBox(height: 16),

                // Church Dropdown
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedChurchId),
                  initialValue: _selectedChurchId,
                  decoration: _inputDecoration("Pilih Paroki", Icons.church),
                  items: _churches.map((c) {
                    return DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: _selectedDioceseId == null ? null : _onChurchChanged,
                  isExpanded: true,
                  style: GoogleFonts.outfit(color: Colors.black),
                  hint: Text("Pilih Paroki", style: GoogleFonts.outfit(color: Colors.grey)),
                  disabledHint: Text("Pilih Keuskupan Terlebih Dahulu", style: GoogleFonts.outfit(color: Colors.grey)),
                ),
                const SizedBox(height: 20),

                // Search Button (Explicit action if needed, though fields auto-search)
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _searchUsers(_searchController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: Text(
                      "Cari Teman",
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. RESULTS LIST
          Expanded(
            child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBrand))
            : _searchResults.isEmpty 
                ? Center(child: Text("Pengguna tidak ditemukan", style: GoogleFonts.outfit(color: Colors.grey)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile( // Keep existing item builder logic but simplify call
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: user.id, isBackButtonEnabled: true))),
                        leading: SafeNetworkImage(
                          imageUrl: user.avatarUrl,
                          width: 50, height: 50,
                          borderRadius: BorderRadius.circular(25),
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.person,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.fullName ?? "User",
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildRoleBadge(user),
                          ],
                        ),
                        subtitle: Text(
                           "${user.parish ?? '-'}, ${user.diocese ?? '-'}",
                           style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13),
                           maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryBrand),
                          onPressed: () => _startChat(user),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBrand),
      ),
    );
  }

  Widget _buildRoleBadge(Profile user) {
    // 1. Special Roles
    if (user.isClergy) { // Using getter from model
       Color badgeColor = const Color(0xFF0F0C29);
       Color textColor = Colors.white;
       IconData icon = Icons.verified_user;
       String label = (user.userRole.name.characters.first.toUpperCase()) + user.userRole.name.substring(1); 
       
       if (user.userRole == UserRole.pastor) {
         badgeColor = const Color(0xFF003366);
         icon = Icons.health_and_safety_rounded;
       } else if (user.userRole == UserRole.suster) {
         badgeColor = const Color(0xFF5D4037);
         icon = Icons.volunteer_activism;
       } 

       return Container(
         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
         decoration: BoxDecoration(
           color: badgeColor,
           borderRadius: BorderRadius.circular(4),
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             if (user.isVerified) ...[
                Icon(icon, color: Colors.amber, size: 10),
                const SizedBox(width: 4),
             ],
             Text(
               label.toUpperCase(), 
               style: GoogleFonts.outfit(fontSize: 9, color: textColor, fontWeight: FontWeight.bold)
             ),
           ],
         ),
       );
    }
    
    // 2. Umat (100% Katolik)
    if (user.isVerified) {
       return Container(
         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
         decoration: BoxDecoration(
           color: Colors.green.withValues(alpha: 0.1),
           borderRadius: BorderRadius.circular(4),
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Icon(Icons.verified, color: Colors.green, size: 10),
             const SizedBox(width: 2),
             Text("100% Katolik", style: GoogleFonts.outfit(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
           ],
         ),
       );
    }
    
    // 3. Unverified / Normal Umat
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
       decoration: BoxDecoration(
         color: Colors.grey.withValues(alpha: 0.1),
         borderRadius: BorderRadius.circular(4),
       ),
       child: Text("Umat", style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey)),
    );
  }

}
