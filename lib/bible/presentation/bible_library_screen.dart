import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mychatolic_app/bible/domain/bible_models.dart';
import 'package:mychatolic_app/bible/presentation/bible_view_model.dart';
import 'package:mychatolic_app/bible/presentation/bible_reader_screen.dart';

class BibleLibraryScreen extends StatefulWidget {
  const BibleLibraryScreen({super.key});

  @override
  State<BibleLibraryScreen> createState() => _BibleLibraryScreenState();
}

class _BibleLibraryScreenState extends State<BibleLibraryScreen> {
  // 0: PL, 1: PB, 2: Deutero
  int _selectedTabIndex = 0;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BibleViewModel>().fetchBooks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BibleBook> _filterBooks(List<BibleBook> books) {
    if (_searchQuery.isEmpty) return books;
    return books.where((b) {
      return b.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.abbreviation.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _LibraryPalette.fromTheme(theme);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildBackground(palette),
          Consumer<BibleViewModel>(
            builder: (context, vm, child) {
              if (vm.isLoadingBooks) {
                return Center(
                  child: CircularProgressIndicator(color: palette.accent),
                );
              }

              if (vm.books.isEmpty) {
                return _buildEmptyState(palette);
              }

              List<BibleBook> currentGroupBooks = [];
              if (_selectedTabIndex == 0) {
                currentGroupBooks = vm.books
                    .where((b) => b.group == BibleBookGroup.oldTestament)
                    .toList();
              } else if (_selectedTabIndex == 1) {
                currentGroupBooks = vm.books
                    .where((b) => b.group == BibleBookGroup.newTestament)
                    .toList();
              } else {
                currentGroupBooks = vm.books
                    .where((b) => b.group == BibleBookGroup.deuterocanonical)
                    .toList();
              }

              final displayBooks = _filterBooks(currentGroupBooks);

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    expandedHeight: 180,
                    automaticallyImplyLeading: false,
                    titleSpacing: 20,
                    title: Text(
                      "Alkitab",
                      style: GoogleFonts.playfairDisplay(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 100, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Kitab Suci Katolik",
                              style: GoogleFonts.playfairDisplay(
                                color: palette.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Pilih kitab dan bab untuk mulai membaca",
                              style: GoogleFonts.manrope(
                                color: palette.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: _buildSearchBar(palette),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Row(
                        children: [
                          _buildPillTab("Perjanjian Lama", 0, palette),
                          const SizedBox(width: 8),
                          _buildPillTab("Perjanjian Baru", 1, palette),
                          const SizedBox(width: 8),
                          _buildPillTab("Deutero", 2, palette),
                        ],
                      ),
                    ),
                  ),
                  if (displayBooks.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          "Tidak ada kitab ditemukan",
                          style: GoogleFonts.manrope(
                            color: palette.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final book = displayBooks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildBookTile(book, palette),
                          );
                        }, childCount: displayBooks.length),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(_LibraryPalette palette) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE1F5FE), // Light Blue 50
            const Color(0xFFFFFFFF), // White
          ],
          stops: const [0.0, 0.6],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -100,
            top: -50,
            child: _buildGlow(const Color(0xFF0088CC).withOpacity(0.15), 300),
          ),
          Positioned(
            left: -80,
            top: 100,
            child: _buildGlow(const Color(0xFF007AB8).withOpacity(0.10), 250),
          ),
          Positioned(
            right: 20,
            top: 60,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 140,
              color: const Color(0xFF0088CC).withOpacity(0.05),
            ),
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

  Widget _buildSearchBar(_LibraryPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        style: GoogleFonts.manrope(
          color: palette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: palette.accent,
        decoration: InputDecoration(
          hintText: "Cari kitab atau singkatan",
          hintStyle: GoogleFonts.manrope(color: palette.textSecondary),
          prefixIcon: Icon(Icons.search_rounded, color: palette.textSecondary),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = "";
                    });
                  },
                  icon: Icon(Icons.close_rounded, color: palette.textSecondary),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPillTab(String label, int index, _LibraryPalette palette) {
    final bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [palette.accent, palette.accentSecondary],
                  )
                : null,
            color: isSelected ? null : palette.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Colors.transparent : palette.border,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: palette.accent.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: isSelected ? Colors.white : palette.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildBookTile(BibleBook book, _LibraryPalette palette) {
    return InkWell(
      onTap: () {
        context.read<BibleViewModel>().openBook(book);
        _showChapterSheet(context, book, palette);
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              palette.accent.withOpacity(0.2),
              palette.accentSecondary.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(1.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            borderRadius: BorderRadius.circular(21),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      palette.accent.withOpacity(0.2),
                      palette.accent.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.accent.withOpacity(0.35)),
                ),
                alignment: Alignment.center,
                child: Text(
                  book.abbreviation,
                  style: GoogleFonts.manrope(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${book.totalChapters} Bab",
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.chip,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  "Buka",
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  void _showChapterSheet(
    BuildContext context,
    BibleBook book,
    _LibraryPalette palette,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        int? selectedChapter;
        bool isLoadingVerses = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomPadding = MediaQuery.of(context).padding.bottom;
            final vm = context.read<BibleViewModel>();

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: EdgeInsets.only(bottom: bottomPadding + 16),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surfaceElevated,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                      child: Row(
                        children: [
                          if (selectedChapter != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: IconButton(
                                icon: Icon(Icons.arrow_back_ios_new_rounded,
                                    size: 20, color: palette.textSecondary),
                                onPressed: () {
                                  setSheetState(() {
                                    selectedChapter = null;
                                  });
                                },
                              ),
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.name,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                selectedChapter == null
                                    ? "Pilih Bab"
                                    : "Bab $selectedChapter : Pilih Ayat",
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            color: palette.textSecondary,
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: isLoadingVerses
                          ? Center(
                              child: CircularProgressIndicator(
                                  color: palette.accent))
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: selectedChapter == null
                                  ? book.totalChapters
                                  : vm.maxVerseNumber,
                              itemBuilder: (context, index) {
                                final number = index + 1;
                                return InkWell(
                                  onTap: () async {
                                    if (selectedChapter == null) {
                                      // Step 1: Start Loading
                                      setSheetState(() {
                                        isLoadingVerses = true;
                                      });

                                      // Step 2: Fetch Data
                                      await vm.loadChapter(number);

                                      if (!context.mounted) return;

                                      // Step 3: Stop Loading (Always Stop)
                                      setSheetState(() {
                                        isLoadingVerses = false;
                                      });

                                      // Step 4: Check Data (Fail-Safe)
                                      if (vm.verses.isEmpty) {
                                        // Scenario B: No Data -> Navigate to Reader (Shows "Under Digitalization")
                                        Navigator.pop(ctx);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const BibleReaderScreen(),
                                          ),
                                        );
                                      } else {
                                        // Scenario A: Data Found -> Show Verse Grid
                                        setSheetState(() {
                                          selectedChapter = number;
                                        });
                                      }
                                    } else {
                                      // Verse Selection Mode: Go to Reader at specific verse
                                      Navigator.pop(ctx);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BibleReaderScreen(
                                              targetVerse: number),
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: palette.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: palette.border),
                                    ),
                                    child: Text(
                                      "$number",
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(_LibraryPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 52, color: palette.error),
          const SizedBox(height: 12),
          Text(
            "Gagal memuat daftar kitab.",
            style: GoogleFonts.manrope(color: palette.error, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _LibraryPalette {
  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceElevated;
  final Color accent;
  final Color accentSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color error;
  final Color border;
  final Color chip;
  final Color shadow;

  _LibraryPalette({
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceElevated,
    required this.accent,
    required this.accentSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.error,
    required this.border,
    required this.chip,
    required this.shadow,
  });

  factory _LibraryPalette.fromTheme(ThemeData _) {
    final accent = const Color(0xFF0088CC);
    final accentSecondary = const Color(0xFF007AB8);
    // Using a more interesting background base
    const background = Color(0xFFF0F9FF); // Very light blue tint
    const surface = Color(0xFFFFFFFF);
    const textPrimary = Color(0xFF1A1A1A); // Softer black
    const textSecondary = Color(0xFF555555);
    const success = Color(0xFF2ECC71);
    const error = Color(0xFFE74C3C);
    const border = Color(0xFFE1EFF5); // Blue-ish border
    const chip = Color(0xFFF0F9FF);

    return _LibraryPalette(
      background: background,
      backgroundSecondary: surface,
      surface: surface,
      surfaceElevated: surface,
      accent: accent,
      accentSecondary: accentSecondary,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      success: success,
      error: error,
      border: border,
      chip: chip,
      shadow: const Color(0xFF0088CC).withOpacity(0.08), // Blue-tinted shadow
    );
  }
}
