import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mychatolic_app/bible/domain/bible_models.dart';
import 'package:mychatolic_app/bible/presentation/bible_view_model.dart';
import 'dart:ui'; // For BackdropFilter

class BibleReaderScreen extends StatefulWidget {
  const BibleReaderScreen({super.key});

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isControlVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isControlVisible) setState(() => _isControlVisible = false);
    } 
    if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isControlVisible) setState(() => _isControlVisible = true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    
    // Premium Paper/Dark Colors
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFFDFDFD);
    final textColor = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: bgColor,
      body: Consumer<BibleViewModel>(
        builder: (context, vm, child) {
          final book = vm.currentBook;
          if (book == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // 1. Premium Sliver AppBar
                  SliverAppBar(
                    backgroundColor: bgColor,
                    floating: true,
                    pinned: true,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    iconTheme: IconThemeData(color: textColor),
                    title: Text(
                      book.name,
                      style: GoogleFonts.lora( // Classical feel
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.bookmark_border),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Fitur bookmark segera hadir")),
                          );
                        },
                      ),
                    ],
                  ),

                  // 2. Content
                  if (vm.isLoadingChapter)
                    SliverToBoxAdapter(child: _buildShimmerLoading(isDark))
                  else if (vm.readerError != null)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Bab ${vm.currentChapter}",
                              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              vm.readerError!,
                              style: GoogleFonts.outfit(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (vm.verses.isEmpty)
                     SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book, size: 48, color: Colors.grey.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text(
                                "Teks sedang dalam proses digitalisasi.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lora(
                                  color: Colors.grey, 
                                  fontStyle: FontStyle.italic,
                                  fontSize: 16
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120), // Bottom padding for floating bar
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            // Intro/Header for Chapter 1
                            if (index == 0) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Text(
                                      "BAB ${vm.currentChapter}",
                                      style: GoogleFonts.outfit(
                                        fontSize: 12, 
                                        fontWeight: FontWeight.bold, 
                                        letterSpacing: 2,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  _buildVerseItem(vm.verses[index], vm.fontSize, textColor, primaryColor),
                                ],
                              );
                            }
                            return _buildVerseItem(vm.verses[index], vm.fontSize, textColor, primaryColor);
                          },
                          childCount: vm.verses.length,
                        ),
                      ),
                    ),
                ],
              ),

              // 3. Floating Bottom Controls (Glassmorphism)
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isControlVisible ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_isControlVisible,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.white.withOpacity(0.1) 
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Previous Chapter
                              IconButton(
                                onPressed: vm.currentChapter > 1 ? vm.prevChapter : null,
                                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                                color: textColor,
                                disabledColor: Colors.grey.withOpacity(0.3),
                              ),

                              // Settings / Font Size
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _showSettings(context, vm),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.text_fields_rounded, size: 18, color: textColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Tampilan",
                                          style: GoogleFonts.outfit(
                                            color: textColor, 
                                            fontWeight: FontWeight.w600
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Next Chapter
                              IconButton(
                                onPressed: vm.currentChapter < book.totalChapters ? vm.nextChapter : null,
                                icon: const Icon(Icons.arrow_forward_ios_rounded),
                                color: textColor,
                                disabledColor: Colors.grey.withOpacity(0.3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVerseItem(BibleVerse verse, double fontSize, Color textColor, Color primaryColor) {
    if (verse.type == BibleVerseType.heading) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(
          verse.content,
          style: GoogleFonts.lora(
            fontSize: fontSize + 2,
            fontWeight: FontWeight.w700, // Semi-bold for headings
            color: primaryColor, // Colored headings
            height: 1.3,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12), // Spacing between verses
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.lora(
            fontSize: fontSize,
            height: 1.8, // Comfortable line height
            color: textColor,
          ),
          children: [
            // Superscript Verse Number
            WidgetSpan(
              child: Transform.translate(
                offset: const Offset(0, -6),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    "${verse.verseNumber}",
                    style: GoogleFonts.outfit(
                      fontSize: fontSize * 0.6,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ),
            TextSpan(text: verse.content),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    // Generate dummy lines
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(10, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index == 0) ...[
                   Container(width: 100, height: 20, color: Colors.white),
                   const SizedBox(height: 20),
                ],
                Container(
                  width: double.infinity, 
                  height: 16, 
                  color: Colors.white
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity, 
                  height: 16, 
                  color: Colors.white
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200, 
                  height: 16, 
                  color: Colors.white
                ),
              ],
            ),
          )),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, BibleViewModel vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // For floating effect if desired
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Pengaturan Teks", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.format_size, size: 20),
                  Expanded(
                    child: Slider(
                      value: vm.fontSize,
                      min: 14,
                      max: 28,
                      divisions: 7,
                      activeColor: theme.primaryColor,
                      label: vm.fontSize.round().toString(),
                      onChanged: (val) => vm.setFontSize(val),
                    ),
                  ),
                  const Icon(Icons.format_size, size: 30),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
