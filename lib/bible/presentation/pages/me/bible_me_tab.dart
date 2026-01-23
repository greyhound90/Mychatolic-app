import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:mychatolic_app/bible/bible_module.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';
import 'package:mychatolic_app/bible/presentation/pages/reader/bible_reader_page.dart';
import 'package:mychatolic_app/bible/presentation/pages/plan/bible_plan_day_page.dart';
import 'package:mychatolic_app/bible/presentation/viewmodels/bible_me_viewmodel.dart';
import 'package:mychatolic_app/bible/presentation/widgets/empty_state_view.dart';
import 'package:mychatolic_app/bible/presentation/widgets/error_state_view.dart';
import 'package:mychatolic_app/bible/presentation/widgets/verse_of_day_card.dart';

class BibleMeTab extends StatelessWidget {
  const BibleMeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BibleMeViewModel(
        bibleRepository: BibleModule.bibleRepository,
        planRepository: BibleModule.readingPlanRepository,
      )..load(),
      child: Consumer<BibleMeViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.errorMessage != null) {
            return ErrorStateView(message: vm.errorMessage!, onRetry: vm.load);
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (vm.verseOfTheDay != null)
                VerseOfDayCard(
                  verse: vm.verseOfTheDay!,
                  onRead: () => _openVerseOfDay(context, vm),
                  onShare: () => SharePlus.instance.share(
                    ShareParams(text: '${vm.verseOfTheDay!.text}\n\n${vm.verseOfTheDay!.reference}'),
                  ),
                  darkMode: false,
                )
              else
                const EmptyStateView(message: 'Ayat hari ini belum tersedia.'),
              const SizedBox(height: AppSpacing.lg),
              _SummaryCard(
                title: 'Terakhir dibaca',
                subtitle: vm.lastRead == null
                    ? 'Belum ada riwayat membaca'
                    : '${vm.lastRead!.bookName ?? 'Kitab'} ${vm.lastRead!.chapter}',
                actionLabel: 'Lanjutkan',
                onTap: vm.lastRead == null ? null : () => _openLastRead(context, vm),
              ),
              const SizedBox(height: AppSpacing.md),
              if (vm.activePlan != null)
                _SummaryCard(
                  title: 'Rencana Aktif',
                  subtitle: vm.activePlan!.title,
                  actionLabel: 'Baca hari ini',
                  onTap: () => _openPlanDay(context, vm),
                ),
            ],
          );
        },
      ),
    );
  }

  void _openVerseOfDay(BuildContext context, BibleMeViewModel vm) {
    final verse = vm.verseOfTheDay;
    if (verse == null || verse.bookId == null || verse.chapter == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderPage(
          bookId: verse.bookId,
          chapter: verse.chapter,
          verse: verse.verse,
        ),
      ),
    );
  }

  void _openLastRead(BuildContext context, BibleMeViewModel vm) {
    final lastRead = vm.lastRead;
    if (lastRead == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderPage(
          bookId: lastRead.bookId,
          chapter: lastRead.chapter,
          verse: lastRead.verse,
        ),
      ),
    );
  }

  void _openPlanDay(BuildContext context, BibleMeViewModel vm) {
    final active = vm.activePlan;
    if (active == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BiblePlanDayPage(plan: active, day: active.currentDay ?? 1),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                Text(subtitle, style: GoogleFonts.manrope(color: Colors.grey[700])),
              ],
            ),
          ),
          ElevatedButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
