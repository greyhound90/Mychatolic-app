import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';

class BookPickerSheet extends StatefulWidget {
  final List<BibleBook> books;
  final String initialTestament;
  final bool showDeuterocanonical;

  const BookPickerSheet({
    super.key,
    required this.books,
    required this.initialTestament,
    required this.showDeuterocanonical,
  });

  @override
  State<BookPickerSheet> createState() => _BookPickerSheetState();
}

class _BookPickerSheetState extends State<BookPickerSheet> {
  late String _testament;
  int _canonFilter = 0; // 0: semua, 1: protokanonika, 2: deuterokanonika
  String _query = '';

  @override
  void initState() {
    super.initState();
    _testament = widget.initialTestament;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.books.where((book) {
      final matchesTestament = _testament == 'ot' ? book.isOldTestament : !book.isOldTestament;
      if (!matchesTestament) return false;

      if (_canonFilter == 1 && book.isDeuterocanonical) return false;
      if (_canonFilter == 2 && !book.isDeuterocanonical) return false;

      if (_query.isNotEmpty && !book.name.toLowerCase().contains(_query)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            onChanged: (val) => setState(() => _query = val.toLowerCase()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari kitab...'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ot', label: Text('Lama')),
                    ButtonSegment(value: 'nt', label: Text('Baru')),
                  ],
                  selected: {_testament},
                  onSelectionChanged: (val) => setState(() => _testament = val.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: _canonFilter == 0,
                onSelected: (_) => setState(() => _canonFilter = 0),
              ),
              ChoiceChip(
                label: const Text('Protokanonika'),
                selected: _canonFilter == 1,
                onSelected: (_) => setState(() => _canonFilter = 1),
              ),
              ChoiceChip(
                label: const Text('Deuterokanonika'),
                selected: _canonFilter == 2,
                onSelected: (_) => setState(() => _canonFilter = 2),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Tidak ada kitab ditemukan'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final book = filtered[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                        tileColor: Colors.white,
                        title: Text(book.name, style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                        trailing: book.isDeuterocanonical
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: const Text('Deuterokanonika', style: TextStyle(fontSize: 10)),
                              )
                            : null,
                        onTap: () => Navigator.pop(context, book),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
