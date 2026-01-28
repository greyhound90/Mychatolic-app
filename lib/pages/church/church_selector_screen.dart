import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/models/church.dart';
import 'package:mychatolic_app/models/country.dart';
import 'package:mychatolic_app/models/diocese.dart';
import 'package:mychatolic_app/pages/church/church_detail_page.dart';
import 'package:mychatolic_app/services/master_data_service.dart';

class ChurchSelectorScreen extends StatefulWidget {
  const ChurchSelectorScreen({super.key});

  @override
  State<ChurchSelectorScreen> createState() => _ChurchSelectorScreenState();
}

class _ChurchSelectorScreenState extends State<ChurchSelectorScreen> {
  final MasterDataService _masterService = MasterDataService();

  // Data Lists
  List<Country> _countries = [];
  List<Diocese> _dioceses = [];
  List<Church> _churches = [];

  // Selections
  Country? _selectedCountry;
  Diocese? _selectedDiocese;
  Church? _selectedChurch;

  // Loading States
  bool _isLoadingCountries = true;
  bool _isLoadingDioceses = false;
  bool _isLoadingChurches = false;

  @override
  void initState() {
    super.initState();
    _fetchCountries();
  }

  Future<void> _fetchCountries() async {
    try {
      final countries = await _masterService.fetchCountries();
      setState(() {
        _countries = countries;
        _isLoadingCountries = false;
      });
    } catch (e) {
      debugPrint("Error fetching countries: $e");
      setState(() => _isLoadingCountries = false);
    }
  }

  Future<void> _onCountryChanged(Country? country) async {
    if (country == null || country == _selectedCountry) return;

    setState(() {
      _selectedCountry = country;
      _selectedDiocese = null;
      _selectedChurch = null;
      _dioceses = [];
      _churches = [];
      _isLoadingDioceses = true;
    });

    try {
      final dioceses = await _masterService.fetchDioceses(country.id);
      setState(() {
        _dioceses = dioceses;
        _isLoadingDioceses = false;
      });
    } catch (e) {
      debugPrint("Error fetching dioceses: $e");
      setState(() => _isLoadingDioceses = false);
    }
  }

  Future<void> _onDioceseChanged(Diocese? diocese) async {
    if (diocese == null || diocese == _selectedDiocese) return;

    setState(() {
      _selectedDiocese = diocese;
      _selectedChurch = null;
      _churches = [];
      _isLoadingChurches = true;
    });

    try {
      final churches = await _masterService.fetchChurches(diocese.id);
      setState(() {
        _churches = churches;
        _isLoadingChurches = false;
      });
    } catch (e) {
      debugPrint("Error fetching churches: $e");
      setState(() => _isLoadingChurches = false);
    }
  }

  void _onChurchChanged(Church? church) {
    setState(() {
      _selectedChurch = church;
    });
  }

  void _onViewDetails() {
    if (_selectedChurch != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChurchDetailPage(churchData: _selectedChurch!.toJson()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(
          "Cari Paroki",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Temukan Gereja",
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kTextTitle,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Pilih lokasi untuk melihat jadwal misa dan detail paroki.",
              style: GoogleFonts.outfit(color: kTextBody, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // 1. Country Selection
            _buildSelectionTile(
              title: "NEGARA",
              isLoading: _isLoadingCountries,
              isEmpty: _countries.isEmpty,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Country>(
                  isExpanded: true,
                  value: _selectedCountry,
                  hint: Text(
                    "Pilih Negara",
                    style: GoogleFonts.outfit(color: kTextMeta),
                  ),
                  items: _countries.map((country) {
                    return DropdownMenuItem(
                      value: country,
                      child: Text(
                        "${country.flagEmoji ?? ''} ${country.name}".trim(),
                        style: GoogleFonts.outfit(color: kTextTitle),
                      ),
                    );
                  }).toList(),
                  onChanged: _onCountryChanged,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Diocese Selection
            Opacity(
              opacity: _selectedCountry == null ? 0.5 : 1.0,
              child: AbsorbPointer(
                absorbing: _selectedCountry == null,
                child: _buildSelectionTile(
                  title: "KEUSKUPAN",
                  isLoading: _isLoadingDioceses,
                  isEmpty:
                      _dioceses.isEmpty &&
                      _selectedCountry != null &&
                      !_isLoadingDioceses,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Diocese>(
                      isExpanded: true,
                      value: _selectedDiocese,
                      hint: Text(
                        "Pilih Keuskupan",
                        style: GoogleFonts.outfit(color: kTextMeta),
                      ),
                      items: _dioceses.map((diocese) {
                        return DropdownMenuItem(
                          value: diocese,
                          child: Text(
                            diocese.name,
                            style: GoogleFonts.outfit(color: kTextTitle),
                          ),
                        );
                      }).toList(),
                      onChanged: _onDioceseChanged,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Church Selection
            Opacity(
              opacity: _selectedDiocese == null ? 0.5 : 1.0,
              child: AbsorbPointer(
                absorbing: _selectedDiocese == null,
                child: _buildSelectionTile(
                  title: "PAROKI / GEREJA",
                  isLoading: _isLoadingChurches,
                  isEmpty:
                      _churches.isEmpty &&
                      _selectedDiocese != null &&
                      !_isLoadingChurches,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Church>(
                      isExpanded: true,
                      value: _selectedChurch,
                      hint: Text(
                        "Pilih Gereja",
                        style: GoogleFonts.outfit(color: kTextMeta),
                      ),
                      items: _churches.map((church) {
                        return DropdownMenuItem(
                          value: church,
                          child: Text(
                            church.name,
                            style: GoogleFonts.outfit(color: kTextTitle),
                          ),
                        );
                      }).toList(),
                      onChanged: _onChurchChanged,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // View Details Button
            ElevatedButton(
              onPressed: _selectedChurch == null ? null : _onViewDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: kPrimary.withValues(alpha: 0.4),
              ),
              child: Text(
                "LIHAT DETAIL",
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required String title,
    required bool isLoading,
    required bool isEmpty,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            color: kTextMeta,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kPrimary,
                      ),
                    ),
                  ),
                )
              : isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Tidak ada data tersedia",
                    style: GoogleFonts.outfit(color: kTextMeta),
                  ),
                )
              : child,
        ),
      ],
    );
  }
}
