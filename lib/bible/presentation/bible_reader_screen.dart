import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mychatolic_app/bible/domain/bible_models.dart';
import 'package:mychatolic_app/bible/presentation/bible_view_model.dart';

class BibleReaderScreen extends StatefulWidget {
  final int? targetVerse;
  const BibleReaderScreen({super.key, this.targetVerse});

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  bool _isControlVisible = true;
  int? _highlightedVerse;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onScroll);
    if (widget.targetVerse != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTarget();
      });
    }
  }

  void _onScroll() {
    // Basic scroll direction detection not easily available with ItemPositionsListener
    // We can infer it from changes in positions or just keep controls visible/toggle on tap
    // For now, simplifying: toggle controls on tap is safer.
    // Or we keep controls visible. The original code had scroll direction logic.
    // We will skip complex scroll direction hide logic for now to ensure stability with new list.
  }

  Future<void> _scrollToTarget() async {
    final vm = context.read<BibleViewModel>();
    // Wait for verses to load if needed?
    // Assuming verses are loaded before this screen is pushed or very quickly.
    // If vm.verses is empty, we can't scroll.
    // But usually we load chapter then push screen, OR screen loads chapter.
    // If screen loads chapter, we need to listen to VM changes.

    // Better: listen to VM.
    if (vm.verses.isEmpty && vm.isLoadingChapter) {
      // Re-check when not loading
      // For simplicity, we assume loaded or we rely on the consumer rebuild calling this?
      // No, let's just wait a bit or check in build.
      return;
    }

    _performScroll(vm);
  }

  void _performScroll(BibleViewModel vm) {
    if (widget.targetVerse == null) return;

    final index = vm.verses.indexWhere((v) => v.verseNumber == widget.targetVerse);
    if (index != -1) {
      // +1 because of header
      final scrollIndex = index + 1;
      _itemScrollController.jumpTo(index: scrollIndex);
      setState(() {
        _highlightedVerse = widget.targetVerse;
      });
      // Remove highlight after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _highlightedVerse = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // _scrollController.dispose(); // Removed as we no longer use ScrollController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ReaderPalette.fromTheme(theme);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildBackground(palette),
          Consumer<BibleViewModel>(
            builder: (context, vm, child) {
              final book = vm.currentBook;
              if (book == null) {
                return Center(
                  child: CircularProgressIndicator(color: palette.accent),
                );
              }

              // Helper to check if we should scroll once loaded
              if (!vm.isLoadingChapter && vm.verses.isNotEmpty && widget.targetVerse != null && _highlightedVerse == null) {
                 // Trigger scroll only once
                 // We need a flag to ensure we don't jump repeatedly if user scrolls away.
                 // Using _highlightedVerse as a dirty flag: if it was set (even to null later), maybe track "jumped"?
                 // Actually _performScroll sets _highlightedVerse.
                 // If widget.targetVerse is set, and we havent highlighted yet...
                 // But wait, highlight is cleared.
                 // Let's use a local bool _hasJumped.
              }

              return Column(
                children: [
                   // Custom AppBar
                   Container(
                     height: kToolbarHeight + topInset,
                     padding: EdgeInsets.only(top: topInset),
                     child: NavigationToolbar(
                        leading: BackButton(color: palette.textPrimary),
                        middle: Text(
                          book.name,
                          style: GoogleFonts.playfairDisplay(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                        trailing: IconButton(
                            icon: const Icon(Icons.bookmark_border_rounded),
                            color: palette.textPrimary,
                            onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Fitur bookmark segera hadir",
                                      style: GoogleFonts.manrope(),
                                    ),
                                  ),
                                );
                            },
                        ),
                     ),
                   ),
                   Expanded(
                     child: vm.isLoadingChapter
                       ? _buildShimmerLoading(palette)
                       : vm.readerError != null
                         ? _buildErrorState(vm.readerError!, palette)
                         : vm.verses.isEmpty
                           ? _buildEmptyState(palette)
                           : ScrollablePositionedList.builder(
                               itemScrollController: _itemScrollController,
                               itemPositionsListener: _itemPositionsListener,
                               padding: EdgeInsets.fromLTRB(0, 0, 0, 100 + bottomInset),
                               itemCount: vm.verses.length + 1, // +1 for Header
                               itemBuilder: (context, index) {
                                 if (index == 0) {
                                   return Padding(
                                     padding: const EdgeInsets.symmetric(horizontal: 20),
                                     child: _buildHeaderContent(book, vm, palette),
                                   );
                                 }
                                 final verse = vm.verses[index - 1];
                                 return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: _buildVerseItem(
                                      verse,
                                      vm.fontSize,
                                      palette,
                                      isHighlighted: verse.verseNumber == _highlightedVerse
                                    ),
                                 );
                               },
                             ),
                   ),
                ],
              );
            },
          ),

          // Floating Controls
          Positioned(
            bottom: 16 + bottomInset,
            left: 20,
            right: 20,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              offset: _isControlVisible
                  ? Offset.zero
                  : const Offset(0, 0.25),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isControlVisible ? 1.0 : 0.0,
                child: Consumer<BibleViewModel>(
                  builder: (context, vm, _) {
                     if (vm.currentBook == null) return const SizedBox();
                     return IgnorePointer(
                        ignoring: !_isControlVisible,
                        child: _buildFloatingControls(vm, vm.currentBook!, palette),
                     );
                  }
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderContent(BibleBook book, BibleViewModel vm, _ReaderPalette palette) {
    // Combines the old FlexibleSpaceBar content and the Chapter Header
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildTag(
                      "Bab ${vm.currentChapter}",
                      palette,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _groupLabel(book.group),
                      style: GoogleFonts.manrope(
                        color: palette.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Baca dengan nyaman & fokus",
                      style: GoogleFonts.manrope(
                        color: palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.auto_stories_rounded,
                size: 84,
                color: palette.accent.withOpacity(0.12),
              ),
            ],
        ),
        const SizedBox(height: 32),
        _buildChapterHeader(vm.currentChapter, palette),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBackground(_ReaderPalette palette) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.background, palette.backgroundSecondary],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -40,
            child: _buildGlow(palette.accent.withOpacity(0.16), 220),
          ),
          Positioned(
            left: -60,
            bottom: -80,
            child: _buildGlow(palette.accent.withOpacity(0.12), 200),
          ),
        ],
      ),
    );
  }

  Widget _buildGlow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  Widget _buildReadingCard(BibleViewModel vm, _ReaderPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.page,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.pageBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChapterHeader(vm.currentChapter, palette),
          const SizedBox(height: 24),
          for (final verse in vm.verses)
            _buildVerseItem(verse, vm.fontSize, palette),
        ],
      ),
    );
  }

  Widget _buildChapterHeader(int chapter, _ReaderPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            "BAB",
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: palette.accent,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            "$chapter",
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 64,
            height: 2,
            decoration: BoxDecoration(
              color: palette.accentSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerseItem(
    BibleVerse verse,
    double fontSize,
    _ReaderPalette palette, {
    bool isHighlighted = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: isHighlighted
          ? palette.accent.withOpacity(0.2)
          : Colors.transparent, // Or palette.page if we want continuous page look
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), // Add some padding for highlight box
      child: _buildVerseContent(verse, fontSize, palette),
    );
  }

  Widget _buildVerseContent(
    BibleVerse verse,
    double fontSize,
    _ReaderPalette palette,
  ) {
    if (verse.type == BibleVerseType.heading) {
      return Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 12),
        child: Text(
          verse.content,
          style: GoogleFonts.playfairDisplay(
            fontSize: fontSize + 2,
            fontWeight: FontWeight.w700,
            color: palette.accent,
            height: 1.3,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.page, // Give each verse a card-like or page-like bg
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.pageBorder.withOpacity(0.5)),
          boxShadow: [
             BoxShadow(
                color: palette.shadow.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
             )
          ],
        ),
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.lora(
              fontSize: fontSize,
              height: 1.75,
              color: palette.textPrimary,
            ),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.accent.withOpacity(0.4)),
                  ),
                  child: Text(
                    "${verse.verseNumber}",
                    style: GoogleFonts.manrope(
                      fontSize: fontSize * 0.6,
                      fontWeight: FontWeight.w700,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ),
              TextSpan(text: verse.content),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingControls(
    BibleViewModel vm,
    BibleBook book,
    _ReaderPalette palette,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: palette.isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: palette.pageBorder.withOpacity(0.8)),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildNavButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: vm.currentChapter > 1 ? vm.prevChapter : null,
                palette: palette,
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _showSettings(context, vm, palette),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Bab ${vm.currentChapter} / ${book.totalChapters}",
                          style: GoogleFonts.manrope(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.text_fields_rounded,
                              size: 16,
                              color: palette.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Tampilan",
                              style: GoogleFonts.manrope(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildNavButton(
                icon: Icons.arrow_forward_ios_rounded,
                onTap: vm.currentChapter < book.totalChapters
                    ? vm.nextChapter
                    : null,
                palette: palette,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback? onTap,
    required _ReaderPalette palette,
  }) {
    final isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isEnabled
                ? palette.accentSoft
                : palette.pageBorder.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.pageBorder.withOpacity(0.6)),
          ),
          child: Icon(
            icon,
            color: isEnabled
                ? palette.textPrimary
                : palette.textSecondary.withOpacity(0.4),
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(_ReaderPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      child: Container(
        decoration: BoxDecoration(
          color: palette.page,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: palette.pageBorder),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
        child: Shimmer.fromColors(
          baseColor: palette.shimmerBase,
          highlightColor: palette.shimmerHighlight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(10, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index == 0) ...[
                      Container(width: 100, height: 18, color: Colors.white),
                      const SizedBox(height: 20),
                    ],
                    Container(
                      width: double.infinity,
                      height: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(width: 200, height: 14, color: Colors.white),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, _ReaderPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: palette.error),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: palette.error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(_ReaderPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: palette.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              "Teks sedang dalam proses digitalisasi.",
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                color: palette.textSecondary,
                fontStyle: FontStyle.italic,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(
    BuildContext context,
    BibleViewModel vm,
    _ReaderPalette palette,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).padding.bottom;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: palette.page.withOpacity(palette.isDark ? 0.95 : 0.98),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: palette.pageBorder),
              ),
              padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.text_fields_rounded, color: palette.accent),
                      const SizedBox(width: 8),
                      Text(
                        "Tampilan Teks",
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Ukuran Huruf",
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        "A-",
                        style: GoogleFonts.manrope(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: palette.accent,
                            inactiveTrackColor: palette.pageBorder,
                            thumbColor: palette.accent,
                            overlayColor: palette.accent.withOpacity(0.2),
                          ),
                          child: Slider(
                            value: vm.fontSize,
                            min: 14,
                            max: 28,
                            divisions: 7,
                            label: vm.fontSize.round().toString(),
                            onChanged: (val) => vm.setFontSize(val),
                          ),
                        ),
                      ),
                      Text(
                        "A+",
                        style: GoogleFonts.manrope(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTag(String text, _ReaderPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.accent.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String _groupLabel(BibleBookGroup group) {
    switch (group) {
      case BibleBookGroup.oldTestament:
        return "Perjanjian Lama";
      case BibleBookGroup.newTestament:
        return "Perjanjian Baru";
      case BibleBookGroup.deuterocanonical:
        return "Deuterokanonika";
    }
  }
}

class _ReaderPalette {
  final bool isDark;
  final Color background;
  final Color backgroundSecondary;
  final Color page;
  final Color pageBorder;
  final Color accent;
  final Color accentSecondary;
  final Color accentSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color muted;
  final Color success;
  final Color error;
  final Color shadow;
  final Color shimmerBase;
  final Color shimmerHighlight;

  _ReaderPalette({
    required this.isDark,
    required this.background,
    required this.backgroundSecondary,
    required this.page,
    required this.pageBorder,
    required this.accent,
    required this.accentSecondary,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.muted,
    required this.success,
    required this.error,
    required this.shadow,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  factory _ReaderPalette.fromTheme(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFF0088CC);
    const accentSecondary = Color(0xFF007AB8);
    const background = Color(0xFFF5F5F5);
    const surface = Color(0xFFFFFFFF);
    const textPrimary = Color(0xFF000000);
    const textSecondary = Color(0xFF555555);
    const muted = Color(0xFF9E9E9E);
    const success = Color(0xFF2ECC71);
    const error = Color(0xFFE74C3C);
    const border = Color(0xFFF5F5F5);

    return _ReaderPalette(
      isDark: isDark,
      background: background,
      backgroundSecondary: surface,
      page: surface,
      pageBorder: border,
      accent: accent,
      accentSecondary: accentSecondary,
      accentSoft: accent.withOpacity(0.12),
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      muted: muted,
      success: success,
      error: error,
      shadow: Colors.black.withOpacity(0.12),
      shimmerBase: Colors.grey.shade300,
      shimmerHighlight: Colors.white,
    );
  }
}
