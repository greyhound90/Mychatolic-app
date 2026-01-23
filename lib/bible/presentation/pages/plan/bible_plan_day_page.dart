import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';
import 'package:mychatolic_app/bible/bible_module.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/presentation/pages/reader/bible_reader_page.dart';
import 'package:mychatolic_app/bible/presentation/widgets/error_state_view.dart';

class BiblePlanDayPage extends StatefulWidget {
  final ReadingPlan plan;
  final int day;

  const BiblePlanDayPage({super.key, required this.plan, required this.day});

  @override
  State<BiblePlanDayPage> createState() => _BiblePlanDayPageState();
}

class _BiblePlanDayPageState extends State<BiblePlanDayPage> {
  final TextEditingController _reflectionController = TextEditingController();
  bool _loading = true;
  ReadingPlanDay? _day;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  Future<void> _loadDay() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final day = await BibleModule.readingPlanRepository.getPlanDay(widget.plan.id, widget.day);
      setState(() => _day = day);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markComplete() async {
    try {
      await BibleModule.readingPlanRepository.markPlanDayComplete(
        widget.plan.id,
        widget.day,
        reflection: _reflectionController.text.trim().isEmpty ? null : _reflectionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hari ditandai selesai')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menandai: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hari ke-${widget.day}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorStateView(message: _error!, onRetry: _loadDay)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text('Bacaan Hari Ini', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: _day!.readings
                          .map((reading) => ActionChip(
                                label: Text(reading.reference),
                                onPressed: () {
                                  if (reading.bookId != null && reading.chapter != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BibleReaderPage(
                                          bookId: reading.bookId,
                                          chapter: reading.chapter,
                                          verse: reading.startVerse,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(onPressed: () {}, child: const Text('Baca')),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(onPressed: _markComplete, child: const Text('Tandai Selesai')),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Refleksi', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _reflectionController,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'Apa yang Tuhan ajarkan hari ini?'),
                    ),
                  ],
                ),
    );
  }
}
