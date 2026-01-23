import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mychatolic_app/bible/core/design_tokens.dart';

class VerseImageBuilderPage extends StatefulWidget {
  final String verseText;
  final String reference;

  const VerseImageBuilderPage({
    super.key,
    required this.verseText,
    required this.reference,
  });

  @override
  State<VerseImageBuilderPage> createState() => _VerseImageBuilderPageState();
}

class _VerseImageBuilderPageState extends State<VerseImageBuilderPage> {
  static const _templateKey = 'bible_verse_image_template';
  static const _fontSizeKey = 'bible_verse_image_font_size';
  static const _showRefKey = 'bible_verse_image_show_ref';

  final GlobalKey _boundaryKey = GlobalKey();
  int _selectedTemplate = 0;
  double _fontSize = 22;
  bool _showReference = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedTemplate = prefs.getInt(_templateKey) ?? 0;
      _fontSize = prefs.getDouble(_fontSizeKey) ?? 22;
      _showReference = prefs.getBool(_showRefKey) ?? true;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_templateKey, _selectedTemplate);
    await prefs.setDouble(_fontSizeKey, _fontSize);
    await prefs.setBool(_showRefKey, _showReference);
  }

  @override
  Widget build(BuildContext context) {
    final templates = _buildTemplates();
    final template = templates[_selectedTemplate.clamp(0, templates.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: Text('Bagikan sebagai gambar', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Container(
                      decoration: template.decoration,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: constraints.maxWidth,
                                      child: Text(
                                        widget.verseText,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.sourceSerif4(
                                          fontSize: _fontSize,
                                          height: 1.4,
                                          color: template.textColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_showReference)
                            Text(
                              widget.reference,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: template.referenceColor,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'MyCatholic',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: template.referenceColor.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Template', style: AppTypography.subtitle(Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: templates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final t = templates[index];
                      final selected = index == _selectedTemplate;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedTemplate = index);
                          _savePrefs();
                        },
                        child: Container(
                          width: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Container(decoration: t.decoration),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Text('Ukuran font'),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 16,
                        max: 32,
                        onChanged: (value) {
                          setState(() => _fontSize = value);
                          _savePrefs();
                        },
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tampilkan referensi ayat'),
                  value: _showReference,
                  onChanged: (val) {
                    setState(() => _showReference = val);
                    _savePrefs();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportAndShare,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share_rounded),
                    label: Text(_isExporting ? 'Membuat gambar...' : 'Bagikan'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_VerseTemplate> _buildTemplates() {
    return [
      _VerseTemplate(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDF8F3), Color(0xFFF3E9DD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        textColor: const Color(0xFF2D2A26),
        referenceColor: const Color(0xFF6E6258),
      ),
      _VerseTemplate(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B2430), Color(0xFF3A4B63)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        textColor: Colors.white,
        referenceColor: const Color(0xFFC9D4E3),
      ),
      _VerseTemplate(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F7FF), Color(0xFFE7E9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        textColor: const Color(0xFF1D1E42),
        referenceColor: const Color(0xFF565AA6),
      ),
      _VerseTemplate(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF102A2E), Color(0xFF1C4B4D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        textColor: const Color(0xFFEAF4F4),
        referenceColor: const Color(0xFFAED3D2),
      ),
      _VerseTemplate(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2B1B1B), Color(0xFF623434)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        textColor: const Color(0xFFFFF7EC),
        referenceColor: const Color(0xFFE9C7A1),
      ),
      _VerseTemplate(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E1B29), Color(0xFF204764)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        textColor: const Color(0xFFEAF0F6),
        referenceColor: const Color(0xFFA6C1D8),
      ),
    ];
  }

  Future<void> _exportAndShare() async {
    setState(() => _isExporting = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final pixelRatio = (MediaQuery.of(context).devicePixelRatio * 2).clamp(2.5, 4.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/verse_story_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: widget.reference,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}

class _VerseTemplate {
  final BoxDecoration decoration;
  final Color textColor;
  final Color referenceColor;

  const _VerseTemplate({
    required this.decoration,
    required this.textColor,
    required this.referenceColor,
  });
}
