import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mychatolic_app/bible/bible_module.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';
import 'package:mychatolic_app/bible/presentation/pages/reader/bible_reader_page.dart';
import 'package:mychatolic_app/bible/presentation/viewmodels/bible_search_viewmodel.dart';
import 'package:mychatolic_app/bible/presentation/widgets/theme_chip.dart';
import 'package:mychatolic_app/bible/presentation/widgets/empty_state_view.dart';
import 'package:mychatolic_app/bible/presentation/widgets/error_state_view.dart';

class BibleSearchTab extends StatelessWidget {
  const BibleSearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          BibleSearchViewModel(bibleRepository: BibleModule.bibleRepository),
      child: const _BibleSearchTabs(),
    );
  }
}

class _BibleSearchTabs extends StatelessWidget {
  const _BibleSearchTabs();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: const [
          TabBar(
            tabs: [
              Tab(text: 'Ayat'),
              Tab(text: 'Referensi'),
              Tab(text: 'Tema'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _KeywordSearchTab(),
                _ReferenceSearchTab(),
                _ThemeSearchTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeywordSearchTab extends StatefulWidget {
  const _KeywordSearchTab();

  @override
  State<_KeywordSearchTab> createState() => _KeywordSearchTabState();
}

class _KeywordSearchTabState extends State<_KeywordSearchTab> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<BibleSearchViewModel>().searchKeyword(value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TextField(
            controller: _controller,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cari kata kunci...',
            ),
          ),
        ),
        const _SearchResultList(),
      ],
    );
  }
}

class _ReferenceSearchTab extends StatefulWidget {
  const _ReferenceSearchTab();

  @override
  State<_ReferenceSearchTab> createState() => _ReferenceSearchTabState();
}

class _ReferenceSearchTabState extends State<_ReferenceSearchTab> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => context
                .read<BibleSearchViewModel>()
                .lookupReference(_controller.text),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.auto_awesome),
              hintText: 'Contoh: Yohanes 3:16',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => context
                    .read<BibleSearchViewModel>()
                    .lookupReference(_controller.text),
              ),
            ),
          ),
        ),
        const _SearchResultList(),
      ],
    );
  }
}

class _ThemeSearchTab extends StatefulWidget {
  const _ThemeSearchTab();

  @override
  State<_ThemeSearchTab> createState() => _ThemeSearchTabState();
}

class _ThemeSearchTabState extends State<_ThemeSearchTab> {
  final List<String> _themes = const [
    'Doa',
    'Pertobatan',
    'Maria',
    'Roh Kudus',
    'Ekaristi',
    'Kasih',
    'Harapan',
  ];
  String? _selectedTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.sm,
            children: _themes.map((theme) {
              return ThemeChip(
                label: theme,
                selected: _selectedTheme == theme,
                onTap: () {
                  setState(() => _selectedTheme = theme);
                  context.read<BibleSearchViewModel>().searchTheme(theme);
                },
              );
            }).toList(),
          ),
        ),
        const _SearchResultList(),
      ],
    );
  }
}

class _SearchResultList extends StatelessWidget {
  const _SearchResultList();

  @override
  Widget build(BuildContext context) {
    return Consumer<BibleSearchViewModel>(
      builder: (context, vm, _) {
        Widget body;
        if (vm.errorMessage != null) {
          body = ErrorStateView(message: vm.errorMessage!);
        } else if (vm.results.isEmpty) {
          body = const EmptyStateView(message: 'Tidak ada hasil.');
        } else {
          body = ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            itemCount: vm.results.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final item = vm.results[index];
              final query = vm.highlightQuery;
              final snippetWidget = (query != null && query.isNotEmpty)
                  ? _HighlightedText(
                      text: item.snippet,
                      query: query,
                      maxLines: 2,
                    )
                  : Text(
                      item.snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );

              return ListTile(
                title: Text(
                  item.reference,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                ),
                subtitle: snippetWidget,
                onTap: () {
                  if (item.bookId != null && item.chapter != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BibleReaderPage(
                          bookId: item.bookId,
                          chapter: item.chapter,
                          verse: item.verse,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        }

        return Expanded(
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: vm.isLoading
                    ? const LinearProgressIndicator(minHeight: 2)
                    : const SizedBox(height: 2),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final int? maxLines;

  const _HighlightedText({
    required this.text,
    required this.query,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    final highlightStyle = (baseStyle ?? const TextStyle()).copyWith(
      backgroundColor: Colors.amber.withValues(alpha: 0.35),
      fontWeight: FontWeight.w600,
    );

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    if (lowerQuery.isEmpty || !lowerText.contains(lowerQuery)) {
      return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: highlightStyle,
        ),
      );
      start = index + query.length;
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}
