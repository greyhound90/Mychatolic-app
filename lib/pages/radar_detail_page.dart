import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mychatolic_app/models/radar_event.dart';
import 'package:mychatolic_app/pages/create_radar_screen.dart';
import 'package:mychatolic_app/pages/radars/radar_chat_page.dart';
import 'package:mychatolic_app/pages/radars/invite_user_page.dart';
import 'package:mychatolic_app/pages/radars/manage_participants_page.dart';
import 'package:mychatolic_app/services/notification_service.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/widgets/report_dialog.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class RadarDetailPage extends StatefulWidget {
  final RadarEvent event;
  final Map<String, dynamic>? radarData;

  const RadarDetailPage({super.key, required this.event, this.radarData});

  @override
  State<RadarDetailPage> createState() => _RadarDetailPageState();
}

class _RadarDetailPageState extends State<RadarDetailPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RadarService _radarService = RadarService();
  final String? _myUserId = Supabase.instance.client.auth.currentUser?.id;

  late RadarEvent _event;
  Map<String, dynamic>? _radarData;

  bool _isJoining = false;
  bool _isLeaving = false;
  bool _isLoadingParticipants = true;
  bool _didMutate = false;
  bool _isOpeningChat = false;
  bool _isDeleting = false;

  List<Map<String, dynamic>> _participants = [];
  bool _isJoined = false;
  bool _isHost = false;
  bool _isSettingReminder = false;
  bool _reminderSet = false;
  String? _churchAddress;
  String? _myParticipantStatus;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _radarData = widget.radarData;
    _isHost = _myUserId != null && _myUserId == _event.creatorId;
    _loadReminderState();
    _loadParticipants();
    _loadChurchAddress();
  }

  String _reminderPrefsKey(String radarId) => 'radar_reminder_set_$radarId';

  Future<void> _loadReminderState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSet = prefs.getBool(_reminderPrefsKey(_event.id)) ?? false;
      if (!mounted) return;
      setState(() => _reminderSet = isSet);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR REMINDER] Failed to load reminder state: $e\n$st");
      }
    }
  }

  Future<void> _loadParticipants() async {
    setState(() => _isLoadingParticipants = true);

    final list = await _radarService.fetchParticipants(_event.id);
    final myStatus = await _radarService.fetchMyParticipantStatus(_event.id);
    if (!mounted) return;

    Map<String, dynamic>? mine;
    if (_myUserId != null) {
      for (final p in list) {
        if ((p['user_id'] ?? '').toString() == _myUserId) {
          mine = p;
          break;
        }
      }
    }

    final myRole = (mine?['role'] ?? '').toString().toUpperCase();
    final statusUpper = myStatus?.toUpperCase();
    final isJoined = statusUpper == 'JOINED';
    final isHost =
        (_myUserId != null && _myUserId == _event.creatorId) ||
        myRole == 'HOST';

    setState(() {
      _participants = list;
      _isJoined = isJoined || isHost;
      _isHost = isHost;
      _myParticipantStatus = statusUpper;
      _isLoadingParticipants = false;
    });
  }

  Future<void> _loadChurchAddress() async {
    final churchId = _event.churchId;
    if (churchId.trim().isEmpty) return;
    try {
      final row = await _supabase
          .from('churches')
          .select('address, name')
          .eq('id', churchId)
          .maybeSingle();
      final address = row?['address']?.toString();
      if (!mounted) return;
      if (address != null && address.trim().isNotEmpty) {
        setState(() => _churchAddress = address.trim());
      } else if (_churchAddress == null) {
        setState(() => _churchAddress = _event.churchName);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR DETAIL] Load church address failed: $e\n$st");
      }
    }
  }

  bool get _isPast => _event.eventTimeUtc.isBefore(DateTime.now().toUtc());

  bool get _canSetReminder {
    if (_isPast) return false;
    return _isJoined || _isHost;
  }

  bool get _canInvite {
    if (_isHost) return true;
    if (!_isJoined) return false;
    return _event.allowMemberInvite;
  }

  bool get _canOpenChat {
    // Allow opening chat for joined members/host (even if past event).
    return _isHost || (_myParticipantStatus == 'JOINED');
  }

  Future<void> _openChat() async {
    if (!_canOpenChat) return;
    if (_isOpeningChat) return;

    setState(() => _isOpeningChat = true);
    try {
      final chatRoomId =
          _event.chatRoomId ??
          _radarData?['chat_room_id']?.toString() ??
          await _radarService.prepareChatForRadar(_event.id);

      if (chatRoomId == null || chatRoomId.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Grup chat belum siap. Coba lagi nanti.")),
        );
        return;
      }

      // Ensure membership (best-effort) before opening chat.
      try {
        await _radarService.prepareChatForRadar(_event.id);
      } catch (_) {}

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RadarChatPage(
            chatRoomId: chatRoomId,
            title: _event.title,
          ),
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR DETAIL] Open chat failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal membuka grup chat")));
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  Future<void> _join() async {
    if (_myUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Silakan login dulu")));
      return;
    }

    setState(() => _isJoining = true);
    try {
      final outcome = await _radarService.joinRadar(_event.id);
      _didMutate = true;
      await _loadParticipants();
      if (!mounted) return;
      if (outcome.isPending) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permintaan join terkirim")),
        );
      } else {
        await _openChat();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR DETAIL] Join failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal bergabung")));
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _leave() async {
    if (_myUserId == null) return;
    setState(() => _isLeaving = true);
    try {
      await _radarService.leaveRadar(_event.id);
      _didMutate = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Berhasil keluar dari acara")),
      );
      Navigator.pop(context, true);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR DETAIL] Leave failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal keluar")));
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _kick(String userId) async {
    try {
      await _radarService.kickParticipant(_event.id, userId);
      _didMutate = true;
      await _loadParticipants();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Peserta dikeluarkan")));
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR DETAIL] Kick failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal mengeluarkan peserta")),
      );
    }
  }

  Future<void> _openInvite() async {
    if (!_canInvite) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            InviteUserPage(radarId: _event.id, radarTitle: _event.title),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _didMutate = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Undangan terkirim")));
    }
  }

  Future<void> _openManageParticipants() async {
    if (!_isHost) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManageParticipantsPage(
          radarId: _event.id,
          radarTitle: _event.title,
        ),
      ),
    );
    if (!mounted) return;
    _didMutate = true;
    await _loadParticipants();
  }

  Future<void> _setReminder() async {
    if (!_canSetReminder) return;
    if (_isSettingReminder) return;

    setState(() => _isSettingReminder = true);
    try {
      await NotificationService().scheduleRadarReminder(_event);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_reminderPrefsKey(_event.id), true);

      if (!mounted) return;
      setState(() => _reminderSet = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pengingat diatur 1 jam sebelum misa.")),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR REMINDER UI] Failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal mengatur pengingat")));
    } finally {
      if (mounted) setState(() => _isSettingReminder = false);
    }
  }

  Future<void> _openReport() async {
    if (_isHost) return;

    if (_myUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Silakan login dulu")));
      return;
    }

    final result = await ReportDialog.show(
      context,
      targetId: _event.id,
      targetEntity: 'RADAR',
    );

    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Terima kasih, laporan Anda sudah dikirim"),
        ),
      );
    }
  }

  Future<void> _openEdit() async {
    if (!_isHost) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRadarScreen(
          editRadarId: _event.id,
          initialData: _event.toJson(),
        ),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      _didMutate = true;
      await _refreshEvent();
    }
  }

  Future<void> _deleteRadar() async {
    if (!_isHost || _isDeleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Radar?"),
        content: const Text(
          "Radar yang dihapus tidak bisa dikembalikan. Lanjutkan?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _isDeleting = true);

    try {
      await _radarService.deleteRadar(_event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Radar berhasil dihapus")),
      );
      Navigator.pop(context, true);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR DETAIL] Delete failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal menghapus radar")));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _openChurchMaps() async {
    final query =
        (_churchAddress?.trim().isNotEmpty ?? false)
            ? _churchAddress!.trim()
            : _event.churchName.trim();
    if (query.isEmpty) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR DETAIL] Open maps failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal membuka Maps")));
    }
  }

  Future<void> _refreshEvent() async {
    try {
      final response = await _supabase
          .from('radar_events')
          .select('*, profiles:creator_id(*)')
          .eq('id', _event.id)
          .single();

      final row = Map<String, dynamic>.from(response as Map);
      final updatedEvent = RadarEvent.fromJson(row);
      if (!mounted) return;

      setState(() {
        _event = updatedEvent;
        _radarData = row;
      });

      if (_reminderSet) {
        // Best-effort: keep reminder aligned if host edits time/location.
        try {
          await NotificationService().scheduleRadarReminder(updatedEvent);
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint(
              "[RADAR REMINDER] Reschedule after edit failed: $e\n$st",
            );
          }
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR DETAIL] Refresh failed: $e\n$st");
      }
    }
  }

  List<Widget> _buildAppBarActions() {
    final actions = <Widget>[];

    if (_canOpenChat) {
      actions.add(
        IconButton(
          tooltip: "Buka Grup Chat",
          icon: _isOpeningChat
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.chat_bubble_outline,
                  color: Color(0xFF0088CC),
                ),
          onPressed: _isOpeningChat ? null : _openChat,
        ),
      );
    }

    if (_canSetReminder) {
      actions.add(
        IconButton(
          tooltip: _reminderSet ? "Pengingat aktif" : "Atur pengingat",
          icon: _isSettingReminder
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _reminderSet
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_outlined,
                  color: const Color(0xFF0088CC),
                ),
          onPressed: _isSettingReminder ? null : _setReminder,
        ),
      );
    }

    if (_isHost) {
      actions.add(
        IconButton(
          tooltip: "Kelola Peserta",
          icon: const Icon(Icons.manage_accounts, color: Color(0xFF0088CC)),
          onPressed: _openManageParticipants,
        ),
      );
      actions.add(
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF0088CC)),
          onSelected: (value) {
            if (value == 'edit') {
              _openEdit();
            } else if (value == 'delete') {
              _deleteRadar();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text("Edit Radar"),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text("Hapus Radar"),
              ),
            ),
          ],
        ),
      );
    } else {
      actions.add(
        IconButton(
          tooltip: "Laporkan",
          icon: const Icon(Icons.flag_outlined, color: Colors.red),
          onPressed: _openReport,
        ),
      );
    }

    if (_canInvite) {
      actions.add(
        IconButton(
          tooltip: "Undang Teman",
          icon: const Icon(
            Icons.person_add_alt_1_outlined,
            color: Color(0xFF0088CC),
          ),
          onPressed: _openInvite,
        ),
      );
    }

    return actions;
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildHeaderCard({
    required Map<String, dynamic> creator,
    required String eventTimeLocalStr,
  }) {
    return _sectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: SafeNetworkImage(
              imageUrl: (creator['avatar_url'] ?? '').toString(),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _event.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (creator['full_name'] ?? 'Umat').toString(),
                  style: GoogleFonts.outfit(color: Colors.grey[700]),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _event.churchName,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openChurchMaps,
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text("Maps"),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0088CC),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      eventTimeLocalStr,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard(String quotaText) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Aturan Acara",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.group_outlined),
            title: Text(
              "Kuota Peserta",
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              quotaText,
              style: GoogleFonts.outfit(color: Colors.grey[700]),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_add_alt_1_outlined),
            title: Text(
              "Invite Teman",
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _event.allowMemberInvite ? "Diizinkan" : "Tidak diizinkan",
              style: GoogleFonts.outfit(color: Colors.grey[700]),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined),
            title: Text(
              "Persetujuan Host",
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _event.requireHostApproval ? "Aktif (moderated)" : "Tidak",
              style: GoogleFonts.outfit(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Deskripsi",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            _event.description.trim().isEmpty ? "-" : _event.description,
            style: GoogleFonts.outfit(color: Colors.grey[800], height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(Map<String, dynamic> participant) {
    final profile = participant['profiles'] is Map
        ? Map<String, dynamic>.from(participant['profiles'] as Map)
        : const <String, dynamic>{};
    final name = (profile['full_name'] ?? 'Umat').toString();
    final avatarUrl = (profile['avatar_url'] ?? '').toString();
    final userId = (participant['user_id'] ?? '').toString();
    final role = (participant['role'] ?? '').toString().toUpperCase();

    final isMe = _myUserId != null && userId == _myUserId;
    final isHostRow = role == 'HOST' || userId == _event.creatorId;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.grey[200],
        child: ClipOval(
          child: SafeNetworkImage(
            imageUrl: avatarUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
      ),
      title: Text(
        name + (isMe ? " (Anda)" : ""),
        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        isHostRow ? "Host" : "Member",
        style: GoogleFonts.outfit(color: Colors.grey[700]),
      ),
      trailing: (_isHost && !isMe && !isHostRow)
          ? IconButton(
              tooltip: "Kick",
              icon: const Icon(
                Icons.person_remove_alt_1_outlined,
                color: Colors.red,
              ),
              onPressed: () => _kick(userId),
            )
          : null,
    );
  }

  Widget _buildParticipantsCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Peserta",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
              if (_isLoadingParticipants)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_isLoadingParticipants && _participants.isEmpty)
            Text(
              "Belum ada peserta.",
              style: GoogleFonts.outfit(color: Colors.grey[700]),
            )
          else
            ..._participants.map(_buildParticipantTile),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Row(
          children: [
            if (_myParticipantStatus == 'PENDING' && !_isPast) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    "Menunggu Persetujuan",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else if (_isJoined && !_isHost && !_isPast) ...[
              if (_canInvite) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openInvite,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(
                      "Undang Teman",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLeaving ? null : _leave,
                  icon: _isLeaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.exit_to_app),
                  label: Text(
                    "Keluar",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else if (_isJoined && _isHost && !_isPast) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _canInvite ? _openInvite : null,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(
                    "Undang Teman",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088CC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else if (!_isJoined && !_isPast) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isJoining ? null : _join,
                  icon: _isJoining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isJoining ? "Memproses..." : "Ikut Misa",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088CC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _isPast ? "Acara sudah lewat" : "Tidak tersedia",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final creator = _radarData?['profiles'] is Map
        ? Map<String, dynamic>.from(_radarData!['profiles'] as Map)
        : const <String, dynamic>{};

    final eventTimeLocalStr = DateFormat(
      'EEE, dd MMM yyyy • HH:mm',
    ).format(_event.eventTimeLocal);
    final quotaText = _event.maxParticipants > 0
        ? "Max ${_event.maxParticipants} orang"
        : "Kuota fleksibel";

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _didMutate);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _didMutate),
          ),
          title: Text(
            "Detail Radar",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          actions: _buildAppBarActions(),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeaderCard(
              creator: creator,
              eventTimeLocalStr: eventTimeLocalStr,
            ),
            const SizedBox(height: 14),
            _buildRulesCard(quotaText),
            const SizedBox(height: 14),
            _buildDescriptionCard(),
            const SizedBox(height: 14),
            _buildParticipantsCard(),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }
}
