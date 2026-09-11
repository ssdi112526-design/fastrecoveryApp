import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Profile_page.dart';

class IdCardPage extends StatefulWidget {
  const IdCardPage({super.key});

  @override
  State<IdCardPage> createState() => _IdCardPageState();
}

class _IdCardPageState extends State<IdCardPage> {
  static const String apiUrl =
      'https://www.fastrecovery.in/api/auth/id-card-data';

  // The exact key your login screen uses isn't known, so every common
  // name is tried in order and the first non-empty match wins. Once you
  // confirm which one your login flow actually uses (check the console
  // print below after a successful load), you can trim this down to
  // just that single key.
  static const List<String> tokenPrefsKeyCandidates = [
    'authToken',
    'token',
    'access_token',
    'accessToken',
    'jwt',
    'userToken',
    'auth_token',
  ];

  bool isLoading = true;
  String errorMessage = '';

  Map<String, dynamic> userData = {};
  Map<String, dynamic> companyData = {};

  static const List<String> photoKeyCandidates = [
    'photoUrl',
    'photo',
    'profileImage',
    'profile_pic',
    'image',
    'avatar',
  ];

  String userValue(String key) {
    return userData[key]?.toString() ?? '';
  }

  String _resolvePhotoUrl() {
    for (final key in photoKeyCandidates) {
      final value = userData[key]?.toString();
      if (value != null && value.isNotEmpty) {
        debugPrint('ID CARD: photo found under key "$key" -> $value');
        return value;
      }
    }
    debugPrint('ID CARD: no photo key matched. Available keys: ${userData.keys}');
    return '';
  }

  @override
  void initState() {
    super.initState();
    fetchIdCardData();
  }

  Future<String?> _resolveToken(SharedPreferences prefs) async {
    for (final key in tokenPrefsKeyCandidates) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        debugPrint('ID CARD: using token found under key "$key"');
        return value;
      }
    }
    return null;
  }

  Future<void> fetchIdCardData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await _resolveToken(prefs);

      if (token == null || token.isEmpty) {
        debugPrint(
          'ID CARD: no token found under any of $tokenPrefsKeyCandidates. '
              'Saved keys were: ${prefs.getKeys()}',
        );
        setState(() {
          isLoading = false;
          errorMessage = 'You are not logged in. Please login again.';
        });
        return;
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('ID CARD STATUS: ${response.statusCode}');
      debugPrint('ID CARD RESPONSE: ${response.body}');

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final user = body['data']['user'];

        setState(() {
          userData = Map<String, dynamic>.from(user ?? {});
          companyData = Map<String, dynamic>.from(
            user?['company'] ?? {},
          );
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          isLoading = false;
          errorMessage =
              body['message']?.toString() ??
                  'Unauthorized. Please login again.';
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage =
              body['message']?.toString() ??
                  'Unable to load ID card.';
        });
      }
    } catch (e) {
      debugPrint('ID CARD ERROR: $e');

      setState(() {
        isLoading = false;
        errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  String companyValue(String key) {
    return companyData[key]?.toString() ?? '';
  }

  Future<pw.Document> _generateIdCardPdf() async {
    final pdf = pw.Document();

    pw.ImageProvider? photoImage;
    final photoUrl = _resolvePhotoUrl();
    if (photoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(photoUrl));
        if (response.statusCode == 200) {
          photoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('PDF: photo fetch failed -> $e');
      }
    }

    final navy = PdfColor.fromInt(0xff1B3A5C);
    final muted = PdfColors.grey600;
    final dark = PdfColor.fromInt(0xff0F172A);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            margin: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.fromLTRB(24, 22, 24, 20),
                  decoration: pw.BoxDecoration(
                    color: navy,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(16),
                      topRight: pw.Radius.circular(16),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyValue('companyName').isEmpty
                            ? 'Company'
                            : companyValue('companyName'),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        companyValue('companyCode').isEmpty
                            ? '—'
                            : companyValue('companyCode'),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Body: photo + fields
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(24, 22, 24, 22),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 110,
                        height: 140,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: photoImage != null
                            ? pw.ClipRRect(
                          horizontalRadius: 10,
                          verticalRadius: 10,
                          child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                        )
                            : pw.Center(child: pw.Text('No Photo')),
                      ),
                      pw.SizedBox(width: 24),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              userValue('name').isEmpty ? 'Employee' : userValue('name'),
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: dark,
                              ),
                            ),
                            pw.SizedBox(height: 14),
                            _pdfFieldRow(muted, dark, 'Post', userValue('post')),
                            pw.SizedBox(height: 10),
                            _pdfFieldRow(muted, dark, 'Date of birth', userValue('dateOfBirth')),
                            pw.SizedBox(height: 10),
                            _pdfFieldRow(muted, dark, 'Pincode', userValue('pincode')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Divider(height: 1, color: PdfColors.grey300),

                // Footer
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(16),
                      bottomRight: pw.Radius.circular(16),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text('Office: ', style: pw.TextStyle(color: muted, fontSize: 12)),
                      pw.Text(
                        companyValue('office').isEmpty ? '—' : companyValue('office'),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: dark),
                      ),
                      pw.SizedBox(width: 40),
                      pw.Text('Mobile: ', style: pw.TextStyle(color: muted, fontSize: 12)),
                      pw.Text(
                        userValue('phone').isEmpty ? '—' : userValue('phone'),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: dark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _pdfFieldRow(PdfColor labelColor, PdfColor valueColor, String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(label, style: pw.TextStyle(color: labelColor, fontSize: 12)),
        ),
        pw.Text(
          value.isEmpty ? '—' : value,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: valueColor),
        ),
      ],
    );
  }

  Future<void> _downloadIdCardPdf() async {
    try {
      final pdf = await _generateIdCardPdf();
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'id_card_${userValue('id')}.pdf',
      );
    } catch (e) {
      debugPrint('DOWNLOAD ERROR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF download failed. Try again.')),
      );
    }
  }

  Future<void> _printIdCard() async {
    try {
      final pdf = await _generateIdCardPdf();
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      debugPrint('PRINT ERROR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Print failed. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xff0A0F1C) : const Color(0xffF4F6FA),
      appBar: AppBar(
        title: Text(
          'ID Card',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xff0F172A),
          ),
        ),
        centerTitle: false,
        backgroundColor:
        isDark ? const Color(0xff0A0F1C) : const Color(0xffF4F6FA),
        foregroundColor: isDark ? Colors.white : const Color(0xff0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: const Color(0xff2563EB),
          strokeWidth: 2.6,
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xffEF4444).withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 34,
                  color: Color(0xffEF4444),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xff0F172A),
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: fetchIdCardData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchIdCardData,
      color: const Color(0xff2563EB),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                _buildIdCard(isDark),
                const SizedBox(height: 28),
                _buildActions(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Centralized theme colors for the "Details" section of the card.
  // Every background/foreground pair is resolved together here, so
  // nothing can go invisible when the theme switches.
  // ---------------------------------------------------------------------

  Color _cardSurface(bool isDark) =>
      isDark ? const Color(0xff121A2E) : Colors.white;

  Color _sectionTitleColor(bool isDark) =>
      isDark ? Colors.white : const Color(0xff0F172A);

  Color _mutedTextColor(bool isDark) =>
      isDark ? const Color(0xff8B98B3) : const Color(0xff64748B);

  Color _dividerColor(bool isDark) =>
      isDark ? const Color(0xff26314D) : const Color(0xffEEF1F6);

  Color _gridTileBg(bool isDark) =>
      isDark ? const Color(0xff17213A) : const Color(0xffF8FAFC);

  Color _gridTileBorder(bool isDark) =>
      isDark ? const Color(0xff283553) : const Color(0xffE7EBF2);

  Color _gridValueColor(bool isDark) =>
      isDark ? Colors.white : const Color(0xff0F172A);

  Color _verifiedBg(bool isDark) =>
      isDark ? const Color(0xff0C2A1A) : const Color(0xffF0FDF4);

  Color _verifiedBorder(bool isDark) =>
      isDark ? const Color(0xff1B4A31) : const Color(0xffBBF7D0);

  Color _verifiedIconBg(bool isDark) =>
      isDark ? const Color(0xff0F3A24) : const Color(0xffDCFCE7);

  Color _actionCardBg(bool isDark) =>
      isDark ? const Color(0xff121A2E) : Colors.white;

  Color _actionCardBorder(bool isDark) =>
      isDark ? const Color(0xff26314D) : const Color(0xffEEF1F6);

  Widget _buildIdCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .45 : .10),
            blurRadius: 40,
            spreadRadius: -6,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          children: [
            // Premium header — fixed dark gradient in both themes, so its
            // white/gold text and icons never depend on isDark.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xff071A35),
                    Color(0xff123B78),
                    Color(0xff1B6FC9),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.12),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(.20),
                          ),
                        ),
                        child: const Icon(
                          Icons.business_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              companyValue('companyName').isEmpty
                                  ? 'Company'
                                  : companyValue('companyName'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'OFFICIAL EMPLOYEE IDENTIFICATION',
                              style: TextStyle(
                                color: Colors.white.withOpacity(.60),
                                fontSize: 9,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _companyCodeBadge(),
                    ],
                  ),

                  const SizedBox(height: 26),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPremiumPhoto(),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userValue('name').isEmpty
                                  ? 'Employee'
                                  : userValue('name'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 9),
                            _roleBadgePremium(),
                            const SizedBox(height: 16),
                            _darkInfo(
                              Icons.badge_outlined,
                              'Employee ID',
                              userValue('id'),
                            ),
                            const SizedBox(height: 8),
                            _darkInfo(
                              Icons.phone_outlined,
                              'Mobile',
                              userValue('phone'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Details section — fully theme-aware via the helper colors above.
            Container(
              color: _cardSurface(isDark),
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xff2563EB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .1,
                          color: _sectionTitleColor(isDark),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Auto-synced',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _mutedTextColor(isDark),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  Divider(height: 24, color: _dividerColor(isDark)),

                  _buildPremiumDetails(isDark),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _verifiedBg(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _verifiedBorder(isDark)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _verifiedIconBg(isDark),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Color(0xff16A34A),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verified Identity',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _sectionTitleColor(isDark),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'This ID card is issued by the company',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _mutedTextColor(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff2563EB).withOpacity(.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            companyValue('companyCode').isEmpty
                                ? '—'
                                : companyValue('companyCode'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumPhoto() {
    final photoUrl = _resolvePhotoUrl();

    return Container(
      width: 100,
      height: 118,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: Colors.white.withOpacity(.28),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: photoUrl.isEmpty
            ? Container(
          color: Colors.white,
          child: const Icon(
            Icons.person_rounded,
            size: 50,
            color: Color(0xff94A3B8),
          ),
        )
            : Image.network(
          photoUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.white,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xff2563EB),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('ID CARD: image load FAILED for $photoUrl');
            debugPrint('ID CARD: error -> $error');
            return Container(
              color: Colors.white,
              child: const Icon(
                Icons.person_rounded,
                size: 50,
                color: Color(0xff94A3B8),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _roleBadgePremium() {
    final role = userValue('role').replaceAll('_', ' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xffFBBF24),
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            role.isEmpty ? 'EMPLOYEE' : role.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumDetails(bool isDark) {
    final details = [
      (Icons.person_outline_rounded, 'Father Name', userValue('fatherName')),
      (Icons.bloodtype_outlined, 'Blood Group', userValue('bloodGroup')),
      (Icons.cake_outlined, 'Date of Birth', userValue('dateOfBirth')),
      (Icons.location_city_outlined, 'District', userValue('district')),
      (Icons.pin_drop_outlined, 'Pincode', userValue('pincode')),
      (Icons.markunread_mailbox_outlined, 'Post', userValue('post')),
      (Icons.location_on_outlined, 'City', userValue('city')),
      (Icons.map_outlined, 'State', userValue('state')),
      (
      Icons.business_center_outlined,
      'Agency Code',
      companyValue('companyCode'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 600 ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: details.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.3,
          ),
          itemBuilder: (_, index) {
            final item = details[index];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: _gridTileBg(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _gridTileBorder(isDark)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xff2563EB).withOpacity(.10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      item.$1,
                      size: 16,
                      color: const Color(0xff2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.$2,
                          style: TextStyle(
                            fontSize: 9,
                            color: _mutedTextColor(isDark),
                            fontWeight: FontWeight.w600,
                            letterSpacing: .2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3.isEmpty ? 'Not provided' : item.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: item.$3.isEmpty
                                ? _mutedTextColor(isDark)
                                : _gridValueColor(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ID Card Actions',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _sectionTitleColor(isDark),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage, print or save your employee ID',
          style: TextStyle(
            fontSize: 12,
            color: _mutedTextColor(isDark),
          ),
        ),
        const SizedBox(height: 16),

        _premiumAction(
          isDark: isDark,
          icon: Icons.edit_rounded,
          title: 'Edit Profile',
          subtitle: 'Update your personal information',
          color: const Color(0xff2563EB),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
        ),
        const SizedBox(height: 12),
        _premiumAction(
          isDark: isDark,
          icon: Icons.print_rounded,
          title: 'Print ID Card',
          subtitle: 'Print your official employee card',
          color: const Color(0xff7C3AED),
          onTap: _printIdCard,
        ),
        const SizedBox(height: 12),
        _premiumAction(
          isDark: isDark,
          icon: Icons.download_rounded,
          title: 'Download PDF',
          subtitle: 'Save a digital copy of your ID card',
          color: const Color(0xff059669),
          onTap: _downloadIdCardPdf,
        ),
      ],
    );
  }

  Widget _companyCodeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Text(
        companyValue('companyCode').isEmpty
            ? 'ID'
            : companyValue('companyCode'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _darkInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white.withOpacity(.55)),
        const SizedBox(width: 6),
        Text(
          '$label  ',
          style: TextStyle(
            color: Colors.white.withOpacity(.50),
            fontSize: 10,
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _premiumAction({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Each button gets its own color-tinted background/border so it reads
    // as a distinct, tappable button rather than a plain list row — and
    // stays legible in both themes since the tint is derived from `color`.
    final bgTint = color.withOpacity(isDark ? .16 : .09);
    final borderTint = color.withOpacity(isDark ? .38 : .28);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: color.withOpacity(.15),
        highlightColor: color.withOpacity(.08),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: bgTint,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderTint, width: 1.3),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _sectionTitleColor(isDark),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _mutedTextColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}