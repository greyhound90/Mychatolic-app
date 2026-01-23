import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class MatchFinderPage extends StatefulWidget {
  const MatchFinderPage({super.key});

  @override
  State<MatchFinderPage> createState() => _MatchFinderPageState();
}

class _MatchFinderPageState extends State<MatchFinderPage> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _candidates = [];
  bool _isLoading = true;


  // Theme Colors
  static const Color bgDarkPurple = Color(0xFF1E1235);
  static const Color cardPurple = Color(0xFF352453);
  static const Color accentOrange = Color(0xFFFF9F1C);
  static const Color neonGreen = Color(0xFF39FF14);



  @override
  void initState() {
    super.initState();
    _fetchCandidates();
  }

  Future<void> _fetchCandidates() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Fetch profiles that are NOT me
      // Idealnya: Filter by 'verified' status only
      final res = await _supabase
          .from('profiles')
          .select('id, full_name, role, avatar_url, bio, verification_status')
          .neq('id', user.id)
          .limit(20); 

      if (mounted) {
        setState(() {
          // Client-side filtering for demo if needed, or trust query
          // Here we create a modifiable list
          _candidates = List<Map<String, dynamic>>.from(res);
          // Mock verification for some if empty (for demo purpose)
          if (_candidates.isEmpty) {
             _candidates = _getMockCandidates();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching candidates: $e");
      if (mounted) {
        setState(() {
          _candidates = _getMockCandidates(); // Fallback to mock
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getMockCandidates() {
    return [
      {
        'id': '1', 'full_name': 'Maria Fransiska', 'role': 'umat', 
        'avatar_url': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=600',
        'verification_status': 'verified', 'bio': 'Suka pelayanan di gereja dan paduan suara. 🎵'
      },
      {
        'id': '2', 'full_name': 'Theresia Yuli', 'role': 'umat', 
        'avatar_url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=600', 
        'verification_status': 'verified', 'bio': 'Mencari teman diskusi iman. 🙏'
      },
      {
        'id': '3', 'full_name': 'Agnes Monika', 'role': 'umat', 
        'avatar_url': 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&q=80&w=600', 
        'verification_status': 'pending', 'bio': 'OMK Paroki Katedral.'
      },
    ];
  }

  void _removeTopCard() {
    setState(() {
      _candidates.removeAt(0);
    });
  }

  void _onSwipeLeft() {
    // PASS / NOPE
    _removeTopCard();
    // Logic: Record 'pass' to DB
  }

  void _onSwipeRight() {
    // LIKE
    final liked = _candidates[0];
    _removeTopCard();
    // Logic: Record 'like' to DB
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Kamu menyukai ${liked['full_name']}!"),
        backgroundColor: neonGreen,
        duration: const Duration(milliseconds: 1000),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDarkPurple,
      appBar: AppBar(
        title: const Text("Teman Seiman", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Filter: 100% Katolik Only")));
            },
            icon: const Icon(Icons.filter_list_rounded, color: accentOrange),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. CARD STACK AREA
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: accentOrange))
                : _candidates.isEmpty 
                    ? _buildEmptyState()
                    : _buildCardStack(),
          ),

          // 2. ACTION BUTTONS
          if (!_isLoading && _candidates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.close_rounded, Colors.redAccent, _onSwipeLeft),
                  _buildActionButton(Icons.star_rounded, Colors.blueAccent, () {}), // Super Like (Dummy)
                  _buildActionButton(Icons.favorite_rounded, neonGreen, _onSwipeRight),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.style_rounded, size: 60, color: Colors.white24),
          const SizedBox(height: 16),
          const Text("Tidak ada profil lagi.", style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _fetchCandidates,
            child: const Text("Refresh", style: TextStyle(color: accentOrange)),
          )
        ],
      ),
    );
  }

  Widget _buildCardStack() {
    // We only show the top 2 cards for performance & visual stack effect
    // Bottom card (index 1) is visible behind Top card (index 0)
    return Stack(
      children: [
        // Background Card (if exists)
        if (_candidates.length > 1)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(20), // Slightly smaller/indented
              child: Transform.scale(
                scale: 0.95,
                child: _buildProfileCard(_candidates[1], isFront: false),
              ),
            ),
          ),
        
        // Front Card (Dismissible)
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Dismissible(
              key: Key(_candidates[0]['id'].toString()),
              direction: DismissDirection.horizontal,
              onDismissed: (direction) {
                if (direction == DismissDirection.endToStart) {
                   _onSwipeLeft();
                } else {
                   _onSwipeRight();
                }
              },
              background: _buildSwipeIndicator(Icons.close, Colors.redAccent, Alignment.centerRight),
              secondaryBackground: _buildSwipeIndicator(Icons.favorite, neonGreen, Alignment.centerLeft),
              child: _buildProfileCard(_candidates[0], isFront: true),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeIndicator(IconData icon, Color color, Alignment align) {
    // Not actually visible because Card covers it until swiped? 
    // Dismissible shows background when swiping. 
    // Ideally we want it BEHIND, which Dismissible does.
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent, // Or color.withValues(alpha: 0.2)
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: 4)
      ),
      alignment: align,
      padding: const EdgeInsets.all(40),
      child: Icon(icon, color: color, size: 60),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> data, {required bool isFront}) {
    final String? avatarUrl = data['avatar_url'];
    final bool isVerified = data['verification_status'] == 'verified';
    final String name = data['full_name'] ?? 'Umat';
    final String bio = data['bio'] ?? 'Tidak ada bio.';

    return Container(
      decoration: BoxDecoration(
        color: cardPurple,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10))
        ]
      ),
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? SafeNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(24),
                    fallbackColor: cardPurple,
                    fallbackIcon: Icons.person,
                    iconColor: Colors.white24,
                  )
                : const Center(child: Icon(Icons.person, size: 80, color: Colors.white24)),
          ),
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                stops: const [0.6, 1.0]
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: neonGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Icon(Icons.verified, size: 14, color: Colors.black),
                         SizedBox(width: 4),
                         Text("100% KATOLIK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                      ],
                    ),
                  ),
                
                // Name & Age
                Text(
                  "$name, 25", 
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                // Diocese / Bio
                Text(
                  bio,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
           shape: BoxShape.circle,
           color: cardPurple,
           border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
           boxShadow: [
             BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2)
           ]
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }
}
