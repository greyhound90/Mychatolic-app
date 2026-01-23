import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:mychatolic_app/bible/bible_module.dart';
import 'package:mychatolic_app/bible/core/bible_constants.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/presentation/viewmodels/bible_reader_viewmodel.dart';
import 'package:mychatolic_app/bible/presentation/viewmodels/reader_settings_controller.dart';
import 'package:mychatolic_app/bible/presentation/widgets/book_picker_sheet.dart';
import 'package:mychatolic_app/bible/presentation/widgets/empty_state_view.dart';
import 'package:mychatolic_app/bible/presentation/widgets/error_state_view.dart';
import 'package:mychatolic_app/bible/presentation/widgets/verse_action_bottom_sheet.dart';
import 'package:mychatolic_app/bible/presentation/widgets/verse_of_day_card.dart';
import 'package:mychatolic_app/bible/presentation/widgets/verse_row.dart';
import 'package:mychatolic_app/bible/presentation/pages/reader/verse_image_builder_page.dart';

class BibleReaderPage extends StatelessWidget {
  final int? bookId;
  final int? chapter;
  final int? verse;

  const BibleReaderPage({
    super.key,
    this.bookId,
    this.chapter,
    this.verse,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Baca', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: ChangeNotifierProvider.value(
        value: BibleModule.readerSettingsController,
        child: BibleReaderView(
          initialBookId: bookId,
          initialChapter: chapter,
          initialVerse: verse,
          showVerseOfDay: false,
        ),
      ),
    );
  }
}

class BibleReaderView extends StatefulWidget {
  final int? initialBookId;
  final int? initialChapter;
  final int? initialVerse;
  final bool showVerseOfDay;

  const BibleReaderView({
    super.key,
    this.initialBookId,
    this.initialChapter,
    this.initialVerse,
    this.showVerseOfDay = true,
  });

  @override
  State<BibleReaderView> createState() => _BibleReaderViewState();
}

class _BibleReaderViewState extends State<BibleReaderView> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _verseKeys = [];
  final Set<int> _selectedVerses = {};

  int? _pendingScrollVerse;
  int? _lastAutoScrolledVerse;
  int? _flashVerse;
  Timer? _flashTimer;

  int? _selectionAnchorIndex;
  bool _dragSelecting = false;
  bool _showChrome = true;
  LastRead? _resumeTarget;

  bool get _selectionMode => _selectedVerses.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pendingScrollVerse = widget.initialVerse;
  }

  @override
  void didUpdateWidget(covariant BibleReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialVerse != null && widget.initialVerse != oldWidget.initialVerse) {
      _setPendingScroll(widget.initialVerse!);
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BibleReaderViewModel(
        bibleRepository: BibleModule.bibleRepository,
        notesRepository: BibleModule.notesRepository,
      )..init(
          bookId: widget.initialBookId,
          chapter: widget.initialChapter,
          loadVerseOfDay: widget.showVerseOfDay,
        ),
      child: Consumer2<BibleReaderViewModel, ReaderSettingsController>(
        builder: (context, vm, settingsController, _) {
          final settings = settingsController.settings;
          final bgColor = settings.mode == 'dark'
              ? BibleColors.darkBackground
              : settings.mode == 'sepia'
                  ? BibleColors.sepiaBackground
                  : BibleColors.lightBackground;
          final textColor = settings.mode == 'dark'
              ? Colors.white
              : settings.mode == 'sepia'
                  ? BibleColors.textSepia
                  : BibleColors.textPrimary;

          _syncVerseKeys(vm.verses.length);
          _captureResumeTarget(vm);
          _maybeScrollToPendingVerse(vm);

          final shouldShowResume = _resumeTarget != null &&
              (vm.selectedBook?.id != _resumeTarget!.bookId || vm.currentChapter != _resumeTarget!.chapter);

          return Stack(
            children: [
              Container(
                color: bgColor,
                child: Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: _showChrome ? _ReaderHeader(
                        showVerseOfDay: widget.showVerseOfDay,
                        verseOfDay: vm.verseOfTheDay,
                        onReadVerseOfDay: () => _jumpToVerseOfDay(vm),
                        onShareVerseOfDay: () => SharePlus.instance.share(
                          ShareParams(text: '${vm.verseOfTheDay?.text ?? ''}\n\n${vm.verseOfTheDay?.reference ?? ''}'),
                        ),
                        onOpenSettings: () => _showSettingsSheet(context, settingsController),
                        onOpenVersion: vm.versions.isEmpty ? null : () => _showVersionPicker(context, vm),
                        selectedVersionLabel: vm.selectedVersion?.abbreviation ?? vm.selectedVersion?.name ?? 'Versi',
                        testament: vm.testament,
                        onChangeTestament: (val) => vm.changeTestament(val),
                        showDeuterocanonical: vm.showDeuterocanonical,
                        onToggleDeuterocanonical: vm.toggleDeuterocanonical,
                        selectedBookLabel: vm.selectedBook?.name ?? 'Pilih Kitab',
                        onPickBook: () => _openBookPicker(context, vm),
                        currentChapter: vm.currentChapter,
                        onPrevChapter: () => _changeChapter(vm, -1),
                        onNextChapter: () => _changeChapter(vm, 1),
                        darkMode: settings.mode == 'dark',
                      ) : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: NotificationListener<UserScrollNotification>(
                        onNotification: (notification) {
                          _handleScroll(notification);
                          return false;
                        },
                        child: RefreshIndicator(
                          onRefresh: () => vm.loadVerses(refresh: true),
                          child: vm.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : vm.errorMessage != null
                                  ? ErrorStateView(message: vm.errorMessage!, onRetry: () => vm.loadVerses(refresh: true))
                                  : vm.verses.isEmpty
                                      ? const EmptyStateView(message: 'Teks untuk pasal ini sedang dalam proses input.')
                                      : GestureDetector(
                                          onHorizontalDragEnd: (details) {
                                            if (details.primaryVelocity == null) return;
                                            if (details.primaryVelocity! < -100) {
                                              _changeChapter(vm, 1);
                                            } else if (details.primaryVelocity! > 100) {
                                              _changeChapter(vm, -1);
                                            }
                                          },
                                          child: ListView.builder(
                                            controller: _scrollController,
                                            addAutomaticKeepAlives: false,
                                            addRepaintBoundaries: true,
                                            cacheExtent: 800,
                                            padding: EdgeInsets.fromLTRB(
                                              AppSpacing.xl,
                                              _showChrome ? AppSpacing.sm : AppSpacing.lg,
                                              AppSpacing.xl,
                                              AppSpacing.xxl + AppSpacing.lg,
                                            ),
                                            itemCount: vm.verses.length,
                                            itemBuilder: (context, index) {
                                              final verse = vm.verses[index];
                                              final selected = _selectedVerses.contains(verse.verse);
                                              return VerseRow(
                                                key: _verseKeys[index],
                                                verse: verse,
                                                fontSize: settings.fontSize,
                                                lineHeight: settings.lineHeight,
                                                textColor: textColor,
                                                selected: selected,
                                                flash: _flashVerse == verse.verse,
                                                paragraphMode: settings.paragraphMode,
                                                onTap: () => _handleVerseTap(context, vm, verse, settings),
                                                onLongPressStart: (_) => _startRangeSelection(vm, index),
                                                onLongPressMoveUpdate: (details) => _updateRangeSelection(vm, details.globalPosition),
                                                onLongPressEnd: (_) => _endRangeSelection(),
                                              );
                                            },
                                          ),
                                        ),
                        ),
                      ),
                    ),
                    if (_selectionMode)
                      _MultiSelectBar(
                        count: _selectedVerses.length,
                        onActions: () => _showRangeActionsSheet(context, vm),
                        onClear: () => setState(() {
                          _selectedVerses.clear();
                          _selectionAnchorIndex = null;
                        }),
                      ),
                  ],
                ),
              ),
              if (shouldShowResume)
                Positioned(
                  right: AppSpacing.xl,
                  bottom: _selectionMode ? (AppSpacing.xxl + AppSpacing.sm) : AppSpacing.xl,
                  child: AnimatedScale(
                    scale: shouldShowResume ? 1 : 0.9,
                    duration: const Duration(milliseconds: 180),
                    child: FloatingActionButton.extended(
                      onPressed: () => _resumeToLastRead(vm),
                      icon: const Icon(Icons.play_circle_fill),
                      label: const Text('Lanjutkan membaca'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _syncVerseKeys(int length) {
    if (_verseKeys.length == length) return;
    _verseKeys
      ..clear()
      ..addAll(List.generate(length, (_) => GlobalKey()));
  }

  void _captureResumeTarget(BibleReaderViewModel vm) {
    if (_resumeTarget != null || vm.lastRead == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _resumeTarget = vm.lastRead);
    });
  }

  void _maybeScrollToPendingVerse(BibleReaderViewModel vm) {
    final targetVerse = _pendingScrollVerse;
    if (targetVerse == null || vm.verses.isEmpty) return;
    if (_lastAutoScrolledVerse == targetVerse) return;
    _lastAutoScrolledVerse = targetVerse;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToVerse(vm, targetVerse);
    });
  }

  Future<void> _scrollToVerse(BibleReaderViewModel vm, int verseNumber) async {
    final index = vm.verses.indexWhere((v) => v.verse == verseNumber);
    if (index == -1) return;
    final key = index < _verseKeys.length ? _verseKeys[index] : null;
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.12,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      final fallbackOffset = max(0.0, index * 60.0);
      await _scrollController.animateTo(
        fallbackOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    if (!mounted) return;
    setState(() {
      _flashVerse = verseNumber;
    });
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _flashVerse = null);
    });
    _pendingScrollVerse = null;
  }

  void _setPendingScroll(int verseNumber) {
    _pendingScrollVerse = verseNumber;
    _lastAutoScrolledVerse = null;
  }

  void _handleScroll(UserScrollNotification notification) {
    if (_selectionMode) return;
    if (notification.metrics.pixels <= 0 && !_showChrome) {
      setState(() => _showChrome = true);
      return;
    }
    if (notification.direction == ScrollDirection.reverse && _showChrome) {
      setState(() => _showChrome = false);
    } else if (notification.direction == ScrollDirection.forward && !_showChrome) {
      setState(() => _showChrome = true);
    }
  }

  void _startRangeSelection(BibleReaderViewModel vm, int index) {
    if (index < 0 || index >= vm.verses.length) return;
    setState(() {
      _selectionAnchorIndex = index;
      _selectedVerses
        ..clear()
        ..add(vm.verses[index].verse);
      _dragSelecting = true;
    });
  }

  void _updateRangeSelection(BibleReaderViewModel vm, Offset globalPosition) {
    if (!_dragSelecting || _selectionAnchorIndex == null) return;
    final index = _indexFromGlobalPosition(globalPosition);
    if (index == null) return;
    _applyRangeSelection(vm, index);
  }

  void _endRangeSelection() {
    _dragSelecting = false;
  }

  int? _indexFromGlobalPosition(Offset globalPosition) {
    double? minDistance;
    int? result;
    for (var i = 0; i < _verseKeys.length; i++) {
      final context = _verseKeys[i].currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return i;
      final distance = (globalPosition.dy - rect.center.dy).abs();
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        result = i;
      }
    }
    return result;
  }

  void _applyRangeSelection(BibleReaderViewModel vm, int index) {
    if (_selectionAnchorIndex == null || index < 0 || index >= vm.verses.length) return;
    final start = min(_selectionAnchorIndex!, index);
    final end = max(_selectionAnchorIndex!, index);
    final selection = <int>{};
    for (var i = start; i <= end; i++) {
      selection.add(vm.verses[i].verse);
    }
    setState(() {
      _selectedVerses
        ..clear()
        ..addAll(selection);
    });
  }

  void _resumeToLastRead(BibleReaderViewModel vm) {
    final target = _resumeTarget;
    if (target == null) return;
    final book = vm.books.firstWhere(
      (b) => b.id == target.bookId,
      orElse: () => vm.selectedBook ?? vm.books.first,
    );
    vm.setLocation(book: book, chapter: target.chapter);
    if (target.verse != null) {
      _setPendingScroll(target.verse!);
    }
  }

  void _showRangeActionsSheet(BuildContext context, BibleReaderViewModel vm) {
    final selected = _selectedVersesList(vm);
    if (selected.isEmpty) return;
    final reference = _rangeReference(vm, selected);
    final preview = _rangeText(selected);
    final mode = context.read<ReaderSettingsController>().settings.mode;
    showModalBottomSheet(
      context: context,
      backgroundColor: mode == 'dark' ? const Color(0xFF1D1D1D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return _RangeActionSheet(
          reference: reference,
          preview: preview,
          darkMode: mode == 'dark',
          onCopy: () {
            Navigator.pop(context);
            _copySelected(vm);
          },
          onShareText: () {
            Navigator.pop(context);
            _shareSelected(vm);
          },
          onShareImage: () {
            Navigator.pop(context);
            _openVerseImageBuilder(context, preview, reference);
          },
          onHighlight: (color) {
            Navigator.pop(context);
            _highlightSelected(vm, color);
          },
          onBookmark: () {
            Navigator.pop(context);
            _bookmarkSelected(vm);
          },
          onNote: () {
            Navigator.pop(context);
            _noteSelected(context, vm);
          },
        );
      },
    );
  }

  void _changeChapter(BibleReaderViewModel vm, int delta) {
    final maxChapter = vm.selectedBook?.chapterCount ?? 150;
    final next = (vm.currentChapter + delta).clamp(1, maxChapter);
    if (next == vm.currentChapter) return;
    _pendingScrollVerse = null;
    _selectedVerses.clear();
    _selectionAnchorIndex = null;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    vm.setChapter(next);
  }

  void _handleVerseTap(
    BuildContext context,
    BibleReaderViewModel vm,
    BibleVerse verse,
    ReaderSettings settings,
  ) {
    if (_selectionMode) {
      _toggleSelection(verse.verse);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: settings.mode == 'dark' ? const Color(0xFF1D1D1D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final reference = '${vm.selectedBook?.name ?? ''} ${verse.chapter}:${verse.verse}';
        return VerseActionBottomSheet(
          verse: verse,
          reference: reference,
          onCopy: () => _copyVerse(verse, reference),
          onShareText: () => _shareVerseText(verse, reference),
          onShareImage: () => _openVerseImageBuilder(context, verse.content, reference),
          onHighlight: (color) => vm.applyHighlight(verse, _colorToHex(color)),
          onBookmark: () => vm.toggleBookmark(verse),
          onNote: () => _showNoteDialog(context, vm, verse),
          darkMode: settings.mode == 'dark',
        );
      },
    );
  }

  void _toggleSelection(int verse) {
    setState(() {
      if (_selectedVerses.contains(verse)) {
        _selectedVerses.remove(verse);
      } else {
        _selectedVerses.add(verse);
      }
    });
  }

  void _copyVerse(BibleVerse verse, String reference) {
    Clipboard.setData(ClipboardData(text: '${verse.content}\n\n$reference'));
    _showMessage('Teks disalin');
  }

  Future<void> _shareVerseText(BibleVerse verse, String reference) async {
    await SharePlus.instance.share(ShareParams(text: '${verse.content}\n\n$reference'));
  }

  void _openVerseImageBuilder(BuildContext context, String text, String reference) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerseImageBuilderPage(
          verseText: text,
          reference: reference,
        ),
      ),
    );
  }

  Future<void> _showNoteDialog(BuildContext context, BibleReaderViewModel vm, BibleVerse verse) async {
    final controller = TextEditingController(text: verse.note ?? '');

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tambah Catatan'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Tulis catatan singkat...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Simpan'),
            )
          ],
        );
      },
    );

    if (result == null) return;
    await vm.saveNote(verse, result);
  }

  List<BibleVerse> _selectedVersesList(BibleReaderViewModel vm) {
    final selected = vm.verses.where((v) => _selectedVerses.contains(v.verse)).toList();
    selected.sort((a, b) => a.verse.compareTo(b.verse));
    return selected;
  }

  String _rangeReference(BibleReaderViewModel vm, List<BibleVerse> selected) {
    if (selected.isEmpty) return '';
    final start = selected.first.verse;
    final end = selected.last.verse;
    final bookName = vm.selectedBook?.name ?? '';
    if (start == end) {
      return '$bookName ${vm.currentChapter}:$start';
    }
    return '$bookName ${vm.currentChapter}:$start-$end';
  }

  String _rangeText(List<BibleVerse> selected) {
    return selected.map((v) => '${v.verse} ${v.content}').join('\n');
  }

  Future<void> _noteSelected(BuildContext context, BibleReaderViewModel vm) async {
    final selected = _selectedVersesList(vm);
    if (selected.isEmpty) return;
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tambah Catatan'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Tulis catatan singkat...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Simpan'),
            )
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;
    for (final verse in selected) {
      await vm.saveNote(verse, result);
    }
    if (!mounted) return;
    setState(() {
      _selectedVerses.clear();
      _selectionAnchorIndex = null;
    });
  }

  void _copySelected(BibleReaderViewModel vm) {
    final selected = _selectedVersesList(vm);
    if (selected.isEmpty) return;
    final text = _rangeText(selected);
    final reference = _rangeReference(vm, selected);
    Clipboard.setData(ClipboardData(text: '$text\n\n$reference'));
    _showMessage('Ayat disalin');
  }

  Future<void> _shareSelected(BibleReaderViewModel vm) async {
    final selected = _selectedVersesList(vm);
    if (selected.isEmpty) return;
    final text = _rangeText(selected);
    final reference = _rangeReference(vm, selected);
    await SharePlus.instance.share(
      ShareParams(text: '$text\n\n$reference'),
    );
  }

  Future<void> _highlightSelected(BibleReaderViewModel vm, Color color) async {
    final selected = _selectedVersesList(vm);
    if (selected.isEmpty) return;
    for (final verse in selected) {
      await vm.applyHighlight(verse, _colorToHex(color));
    }
    setState(() {
      _selectedVerses.clear();
      _selectionAnchorIndex = null;
    });
  }

  Future<void> _bookmarkSelected(BibleReaderViewModel vm) async {
    final selected = _selectedVersesList(vm);
    if (selected.isEmpty) return;
    for (final verse in selected) {
      await vm.toggleBookmark(verse);
    }
    setState(() {
      _selectedVerses.clear();
      _selectionAnchorIndex = null;
    });
  }

  void _showSettingsSheet(BuildContext context, ReaderSettingsController settingsController) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return _ReaderSettingsSheet(
          fontSize: settingsController.settings.fontSize,
          lineHeight: settingsController.settings.lineHeight,
          mode: settingsController.settings.mode,
          paragraphMode: settingsController.settings.paragraphMode,
          onChanged: (fontSize, lineHeight, mode, paragraphMode) {
            settingsController.update(
              fontSize: fontSize,
              lineHeight: lineHeight,
              mode: mode,
              paragraphMode: paragraphMode,
            );
          },
        );
      },
    );
  }

  Future<void> _showVersionPicker(BuildContext context, BibleReaderViewModel vm) async {
    final selected = await showModalBottomSheet<BibleVersion>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return ListView(
          shrinkWrap: true,
          children: vm.versions
              .map((version) => ListTile(
                    title: Text(version.name),
                    subtitle: version.abbreviation == null ? null : Text(version.abbreviation!),
                    onTap: () => Navigator.pop(context, version),
                  ))
              .toList(),
        );
      },
    );

    if (selected != null) {
      vm.setVersion(selected);
    }
  }

  Future<void> _openBookPicker(BuildContext context, BibleReaderViewModel vm) async {
    final book = await showModalBottomSheet<BibleBook>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return BookPickerSheet(
          books: vm.books,
          initialTestament: vm.testament,
          showDeuterocanonical: vm.showDeuterocanonical,
        );
      },
    );

    if (book != null) {
      _pendingScrollVerse = null;
      _selectedVerses.clear();
      _selectionAnchorIndex = null;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      vm.setBook(book);
    }
  }

  void _jumpToVerseOfDay(BibleReaderViewModel vm) {
    final verse = vm.verseOfTheDay;
    if (verse == null || verse.bookId == null || verse.chapter == null) return;

    final target = vm.books.firstWhere(
      (b) => b.id == verse.bookId,
      orElse: () => vm.selectedBook ?? vm.books.first,
    );
    vm.setLocation(book: target, chapter: verse.chapter!);
    if (verse.verse != null) {
      _setPendingScroll(verse.verse!);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReaderHeader extends StatelessWidget {
  final bool showVerseOfDay;
  final VerseOfTheDay? verseOfDay;
  final VoidCallback onReadVerseOfDay;
  final VoidCallback onShareVerseOfDay;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenVersion;
  final String selectedVersionLabel;
  final String testament;
  final ValueChanged<String> onChangeTestament;
  final bool showDeuterocanonical;
  final ValueChanged<bool> onToggleDeuterocanonical;
  final String selectedBookLabel;
  final VoidCallback onPickBook;
  final int currentChapter;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final bool darkMode;

  const _ReaderHeader({
    required this.showVerseOfDay,
    required this.verseOfDay,
    required this.onReadVerseOfDay,
    required this.onShareVerseOfDay,
    required this.onOpenSettings,
    required this.onOpenVersion,
    required this.selectedVersionLabel,
    required this.testament,
    required this.onChangeTestament,
    required this.showDeuterocanonical,
    required this.onToggleDeuterocanonical,
    required this.selectedBookLabel,
    required this.onPickBook,
    required this.currentChapter,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.darkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showVerseOfDay && verseOfDay != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: VerseOfDayCard(
              verse: verseOfDay!,
              onRead: onReadVerseOfDay,
              onShare: onShareVerseOfDay,
              darkMode: darkMode,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: onOpenVersion,
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text(
                  selectedVersionLabel,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ot', label: Text('Lama')),
                    ButtonSegment(value: 'nt', label: Text('Baru')),
                  ],
                  selected: {testament},
                  onSelectionChanged: (val) => onChangeTestament(val.first),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FilterChip(
                label: const Text('Deuterokanonika'),
                selected: showDeuterocanonical,
                onSelected: onToggleDeuterocanonical,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPickBook,
                  child: Text(
                    selectedBookLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                onPressed: onPrevChapter,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Pasal $currentChapter', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              IconButton(
                onPressed: onNextChapter,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReaderSettingsSheet extends StatefulWidget {
  final double fontSize;
  final double lineHeight;
  final String mode;
  final bool paragraphMode;
  final void Function(double, double, String, bool) onChanged;

  const _ReaderSettingsSheet({
    required this.fontSize,
    required this.lineHeight,
    required this.mode,
    required this.paragraphMode,
    required this.onChanged,
  });

  @override
  State<_ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<_ReaderSettingsSheet> {
  late double _fontSize;
  late double _lineHeight;
  late String _mode;
  late bool _paragraphMode;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _lineHeight = widget.lineHeight;
    _mode = widget.mode;
    _paragraphMode = widget.paragraphMode;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Tampilan', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Text('Font'),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 14,
                  max: 26,
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              )
            ],
          ),
          Row(
            children: [
              const Text('Line Height'),
              Expanded(
                child: Slider(
                  value: _lineHeight,
                  min: 1.4,
                  max: 2.2,
                  onChanged: (v) => setState(() => _lineHeight = v),
                ),
              )
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mode paragraf'),
            subtitle: const Text('Tampilkan ayat terasa seperti paragraf ebook'),
            value: _paragraphMode,
            onChanged: (val) => setState(() => _paragraphMode = val),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'light', label: Text('Terang')),
              ButtonSegment(value: 'sepia', label: Text('Sepia')),
              ButtonSegment(value: 'dark', label: Text('Gelap')),
            ],
            selected: {_mode},
            onSelectionChanged: (val) => setState(() => _mode = val.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () {
              widget.onChanged(_fontSize, _lineHeight, _mode, _paragraphMode);
              Navigator.pop(context);
            },
            child: const Text('Terapkan'),
          )
        ],
      ),
    );
  }
}

class _RangeActionSheet extends StatelessWidget {
  final String reference;
  final String preview;
  final VoidCallback onCopy;
  final VoidCallback onShareText;
  final VoidCallback onShareImage;
  final ValueChanged<Color> onHighlight;
  final VoidCallback onBookmark;
  final VoidCallback onNote;
  final bool darkMode;

  const _RangeActionSheet({
    required this.reference,
    required this.preview,
    required this.onCopy,
    required this.onShareText,
    required this.onShareImage,
    required this.onHighlight,
    required this.onBookmark,
    required this.onNote,
    required this.darkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkMode ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reference, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            preview,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _RangeActionChip(icon: Icons.copy_rounded, label: 'Copy', onTap: onCopy),
              _RangeActionChip(icon: Icons.share_rounded, label: 'Share Text', onTap: onShareText),
              _RangeActionChip(icon: Icons.image_outlined, label: 'Bagikan sebagai gambar', onTap: onShareImage),
              _RangeActionChip(icon: Icons.bookmark_border, label: 'Bookmark', onTap: onBookmark),
              _RangeActionChip(icon: Icons.edit_note, label: 'Catatan', onTap: onNote),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Highlight', style: TextStyle(color: textColor)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: _rangeHighlightPalette
                .map((color) => _HighlightDot(color: color, onTap: () => onHighlight(color)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _RangeActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RangeActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _HighlightDot extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _HighlightDot({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
    );
  }
}

class _MultiSelectBar extends StatelessWidget {
  final int count;
  final VoidCallback onActions;
  final VoidCallback onClear;

  const _MultiSelectBar({
    required this.count,
    required this.onActions,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      color: Colors.black.withValues(alpha: 0.9),
      child: Row(
        children: [
          Text('$count ayat dipilih', style: const TextStyle(color: Colors.white)),
          const Spacer(),
          TextButton.icon(
            onPressed: onActions,
            icon: const Icon(Icons.flash_on, color: Colors.white, size: 18),
            label: const Text('Aksi', style: TextStyle(color: Colors.white)),
          ),
          IconButton(onPressed: onClear, icon: const Icon(Icons.close, color: Colors.white)),
        ],
      ),
    );
  }
}

String _colorToHex(Color color) {
  final value = color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
  return '#${value.substring(2)}';
}

const List<Color> _rangeHighlightPalette = [
  Color(0xFFFFF3B0),
  Color(0xFFCDEAC0),
  Color(0xFFBEE3F8),
  Color(0xFFFBCFE8),
];
