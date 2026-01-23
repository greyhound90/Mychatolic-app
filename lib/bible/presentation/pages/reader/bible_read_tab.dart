import 'package:flutter/material.dart';
import 'package:mychatolic_app/bible/presentation/pages/reader/bible_reader_page.dart';

class BibleReadTab extends StatelessWidget {
  const BibleReadTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const BibleReaderView(showVerseOfDay: true);
  }
}
