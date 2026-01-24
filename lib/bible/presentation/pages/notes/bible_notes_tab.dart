import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mychatolic_app/bible/bible_module.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';
import 'package:mychatolic_app/bible/presentation/pages/reader/bible_reader_page.dart';
import 'package:mychatolic_app/bible/presentation/viewmodels/bible_notes_viewmodel.dart';
import 'package:mychatolic_app/bible/presentation/widgets/empty_state_view.dart';
import 'package:mychatolic_app/bible/presentation/widgets/error_state_view.dart';

class BibleNotesTab extends StatelessWidget {
  const BibleNotesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          BibleNotesViewModel(notesRepository: BibleModule.notesRepository)
            ..loadAll(),
      child: const _BibleNotesTabs(),
    );
  }
}

class _BibleNotesTabs extends StatelessWidget {
  const _BibleNotesTabs();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: const [
          TabBar(
            tabs: [
              Tab(text: 'Highlight'),
              Tab(text: 'Bookmark'),
              Tab(text: 'Catatan'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_HighlightTab(), _BookmarkTab(), _NotesTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightTab extends StatelessWidget {
  const _HighlightTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<BibleNotesViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (vm.errorMessage != null) {
          return ErrorStateView(message: vm.errorMessage!, onRetry: vm.loadAll);
        }
        if (vm.highlights.isEmpty) {
          return const EmptyStateView(message: 'Belum ada highlight');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: vm.highlights.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final item = vm.highlights[index];
            return ListTile(
              leading: CircleAvatar(backgroundColor: _parseColor(item.color)),
              title: Text(
                item.reference ?? 'Ayat',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                item.text ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () =>
                  _openReader(context, item.bookId, item.chapter, item.verse),
            );
          },
        );
      },
    );
  }
}

class _BookmarkTab extends StatelessWidget {
  const _BookmarkTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<BibleNotesViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (vm.errorMessage != null) {
          return ErrorStateView(message: vm.errorMessage!, onRetry: vm.loadAll);
        }
        if (vm.bookmarks.isEmpty) {
          return const EmptyStateView(message: 'Belum ada bookmark');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: vm.bookmarks.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final item = vm.bookmarks[index];
            return ListTile(
              leading: const Icon(Icons.bookmark_rounded),
              title: Text(
                item.reference ?? 'Ayat',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                item.text ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () =>
                  _openReader(context, item.bookId, item.chapter, item.verse),
            );
          },
        );
      },
    );
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<BibleNotesViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (vm.errorMessage != null) {
          return ErrorStateView(message: vm.errorMessage!, onRetry: vm.loadAll);
        }
        if (vm.notes.isEmpty) {
          return const EmptyStateView(message: 'Belum ada catatan');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: vm.notes.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final item = vm.notes[index];
            final title = item.title?.isNotEmpty == true
                ? item.title!
                : '${item.content.split(' ').take(5).join(' ')}...';
            final date = item.createdAt != null
                ? '${item.createdAt!.day}/${item.createdAt!.month}/${item.createdAt!.year}'
                : '';
            return ListTile(
              title: Text(
                title,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('${item.reference ?? ''} $date'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  _openReader(context, item.bookId, item.chapter, item.verse),
            );
          },
        );
      },
    );
  }
}

void _openReader(BuildContext context, int bookId, int chapter, int verse) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          BibleReaderPage(bookId: bookId, chapter: chapter, verse: verse),
    ),
  );
}

Color _parseColor(String hex) {
  var value = hex.replaceAll('#', '').toUpperCase();
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return Colors.amber;
  return Color(parsed);
}
