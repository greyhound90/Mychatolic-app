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
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: bgColor,
      // Minimalist AppBar
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          "Alkitab",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Consumer<BibleViewModel>(
        builder: (context, vm, child) {
          if (vm.isLoadingBooks) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.books.isEmpty) {
            return Center(
              child: Text(
                "Gagal memuat daftar kitab.",
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            );
          }

          // Group Books
          List<BibleBook> currentGroupBooks = [];
          
          // If searching, show all matches regardless of tab? 
          // Or keep tabs? Let's keep tabs for organization, 
          // but if search is active, maybe search across all?
          // For simplicity/UX: keep tab filtering active.
          
          if (_selectedTabIndex == 0) {
            currentGroupBooks = vm.books.where((b) => b.group == BibleBookGroup.oldTestament).toList();
          } else if (_selectedTabIndex == 1) {
            currentGroupBooks = vm.books.where((b) => b.group == BibleBookGroup.newTestament).toList();
          } else {
            currentGroupBooks = vm.books.where((b) => b.group == BibleBookGroup.deuterocanonical).toList();
          }

          final displayBooks = _filterBooks(currentGroupBooks);

          return Column(
            children: [
              // 1. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
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
                    style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: "Cari kitab (contoh: Kejadian)",
                      hintStyle: GoogleFonts.outfit(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),

              // 2. Pill Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildPillTab("Perjanjian Lama", 0, isDark, primaryColor),
                    const SizedBox(width: 8),
                    _buildPillTab("Perjanjian Baru", 1, isDark, primaryColor),
                    const SizedBox(width: 8),
                    _buildPillTab("Deutero", 2, isDark, primaryColor),
                  ],
                ),
              ),

              // 3. Book List
              Expanded(
                child: displayBooks.isEmpty
                    ? Center(child: Text("Tidak ada kitab ditemukan", style: GoogleFonts.outfit(color: Colors.grey)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayBooks.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final book = displayBooks[index];
                          return _buildBookTile(book, cardColor, isDark, primaryColor);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPillTab(String label, int index, bool isDark, Color primaryColor) {
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
            color: isSelected ? primaryColor : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
            borderRadius: BorderRadius.circular(30),
            border: isSelected ? null : Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : (isDark ? Colors.grey : Colors.black54),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildBookTile(BibleBook book, Color cardColor, bool isDark, Color primaryColor) {
    return InkWell(
      onTap: () {
        context.read<BibleViewModel>().openBook(book);
        _showChapterSheet(context, book, cardColor, isDark, primaryColor);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            // Abbreviation Circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                book.abbreviation,
                style: GoogleFonts.outfit(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Title
            Expanded(
              child: Text(
                book.name,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            // Trailing Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${book.totalChapters} Bab",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChapterSheet(BuildContext context, BibleBook book, Color cardColor, bool isDark, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.name,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            "Pilih Bab",
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: book.totalChapters,
                    itemBuilder: (context, index) {
                      final chapter = index + 1;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const BibleReaderScreen()));
                          context.read<BibleViewModel>().loadChapter(chapter);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                            ),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                          ),
                          child: Text(
                            "$chapter",
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
