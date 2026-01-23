import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mychatolic_app/services/radar_service.dart';

class InviteUserPage extends StatefulWidget {
  final String radarId;
  final String? radarTitle;

  const InviteUserPage({super.key, required this.radarId, this.radarTitle});

  @override
  State<InviteUserPage> createState() => _InviteUserPageState();
}

class _InviteUserPageState extends State<InviteUserPage> {
  final _supabase = Supabase.instance.client;
  final RadarService _radarService = RadarService();

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id ?? '';

      final data = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url, username')
          .neq('id', currentUserId)
          .or('full_name.ilike.%$q%,username.ilike.%$q%')
          .limit(20);

      if (!mounted) return;
      setState(() {
        _results = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR INVITE UI] Search failed: $e\n$st");
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _invite(Map<String, dynamic> user) async {
    final inviteeId = (user['id'] ?? '').toString();
    if (inviteeId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _radarService.sendInvite(
        radarId: widget.radarId,
        inviteeId: inviteeId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : "Gagal mengirim undangan";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          "Undang Teman",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.radarTitle != null &&
                    widget.radarTitle!.trim().isNotEmpty)
                  Text(
                    "Acara: ${widget.radarTitle}",
                    style: GoogleFonts.outfit(color: Colors.grey[700]),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: "Cari nama atau username...",
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? Center(
                    child: Text(
                      "Cari teman untuk diajak.",
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      final name = (user['full_name'] ?? 'User').toString();
                      final username = (user['username'] ?? 'user').toString();
                      final avatarUrl = (user['avatar_url'] ?? '').toString();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? const Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          "@$username",
                          style: GoogleFonts.outfit(color: Colors.grey),
                        ),
                        trailing: TextButton(
                          onPressed: () => _invite(user),
                          child: const Text("Undang"),
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
