import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mychatolic_app/bible/core/bible_theme.dart';
import 'package:mychatolic_app/bible/bible_module.dart';
import 'package:mychatolic_app/bible/presentation/pages/reader/bible_read_tab.dart';
import 'package:mychatolic_app/bible/presentation/pages/plan/bible_plan_tab.dart';
import 'package:mychatolic_app/bible/presentation/pages/search/bible_search_tab.dart';
import 'package:mychatolic_app/bible/presentation/pages/notes/bible_notes_tab.dart';
import 'package:mychatolic_app/bible/presentation/pages/me/bible_me_tab.dart';

class BibleRootPage extends StatelessWidget {
  const BibleRootPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChangeNotifierProvider.value(
      value: BibleModule.readerSettingsController,
      child: Theme(
        data: isDark ? BibleTheme.dark() : BibleTheme.light(),
        child: DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                'Alkitab',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
              centerTitle: false,
              bottom: TabBar(
                isScrollable: true,
                labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Baca'),
                  Tab(text: 'Rencana'),
                  Tab(text: 'Cari'),
                  Tab(text: 'Catatan'),
                  Tab(text: 'Saya'),
                ],
              ),
            ),
            body: const TabBarView(
              physics: BouncingScrollPhysics(),
              children: [
                BibleReadTab(),
                BiblePlanTab(),
                BibleSearchTab(),
                BibleNotesTab(),
                BibleMeTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
