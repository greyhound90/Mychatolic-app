import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mychatolic_app/services/report_service.dart';

class ReportDialog extends StatefulWidget {
  final String targetId;
  final String targetEntity;

  const ReportDialog({
    super.key,
    required this.targetId,
    this.targetEntity = 'RADAR',
  });

  static Future<bool?> show(
    BuildContext context, {
    required String targetId,
    String targetEntity = 'RADAR',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ReportDialog(targetId: targetId, targetEntity: targetEntity),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  static const List<String> _reasons = [
    "Spam / Penipuan",
    "Konten Tidak Pantas",
    "Informasi Palsu / Hoax",
    "Lainnya",
  ];

  final ReportService _reportService = ReportService();
  final TextEditingController _descController = TextEditingController();

  String? _selectedReason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _selectedReason?.trim() ?? '';
    if (reason.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pilih alasan laporan")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _reportService.submitReport(
        targetEntity: widget.targetEntity,
        targetId: widget.targetId,
        reason: reason,
        description: _descController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[REPORT UI] Submit failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal mengirim laporan")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 40),
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Laporkan Radar",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Bantu kami menjaga komunitas tetap aman dan nyaman.",
                style: GoogleFonts.outfit(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                decoration: InputDecoration(
                  labelText: "Alasan",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                items: _reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (v) => setState(() => _selectedReason = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                minLines: 3,
                maxLines: 6,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  labelText: "Jelaskan detailnya (Opsional)",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.flag_outlined),
                  label: Text(
                    _isSubmitting ? "Mengirim..." : "Kirim Laporan",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
