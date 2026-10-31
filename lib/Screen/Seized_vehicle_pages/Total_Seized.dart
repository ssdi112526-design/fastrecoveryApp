import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:excel_plus/excel_plus.dart' as xl;
import 'package:fastrecovery/Service/SharedPreferenceService.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Confimation_cases/ConfirmedCases.dart';
import 'Seized_update_inventory.dart';

const String _kBase = 'https://fastrecovery.in/api';

// Brand colors
const Color _kBrandA = Color(0xFF38B6FF);
const Color _kBrandB = Color(0xFF1D3FAE);
const Color _kGreen = Color(0xFF16A34A);
const Color _kExcel = Color(0xFF2E7D32);

/// One row of GET /confirmations?view=inventory-confirmed
class SeizedItem {
  final String id;
  final String caseId;
  final String caseCode;
  final String vehicleNumber;
  final String customerName;
  final String bankName;
  final String branchName;
  final String requestedByName;
  final String status;
  final DateTime? createdAt;

  final String requestNote;
  final String reviewNote;
  final String loadedShort;
  final String loadedDetail;
  final String reviewedByName;
  final bool inventorySubmitted;
  final bool inventoryConfirmed;
  final bool inventoryRevisionRequested;
  final num vehicleBillAmount;
  final num otherBillAmount;
  final num totalAmount;

  SeizedItem({
    required this.id,
    required this.caseId,
    required this.caseCode,
    required this.vehicleNumber,
    required this.customerName,
    required this.bankName,
    required this.branchName,
    required this.requestedByName,
    required this.status,
    required this.createdAt,
    required this.requestNote,
    required this.reviewNote,
    required this.loadedShort,
    required this.loadedDetail,
    required this.reviewedByName,
    required this.inventorySubmitted,
    required this.inventoryConfirmed,
    required this.inventoryRevisionRequested,
    required this.vehicleBillAmount,
    required this.otherBillAmount,
    required this.totalAmount,
  });

  static String _s(dynamic v) => v == null ? '' : v.toString().trim();
  static num _n(dynamic v) => v is num ? v : num.tryParse(_s(v)) ?? 0;

  factory SeizedItem.fromJson(Map<String, dynamic> j) => SeizedItem(
    id: _s(j['_id'] ?? j['id']),
    caseId: _s(j['caseId']),
    caseCode: _s(j['caseCode']),
    vehicleNumber: _s(j['vehicleNumber']),
    customerName: _s(j['customerName']).replaceAll(RegExp(r'\s+'), ' '),
    bankName: _s(j['bankName']),
    branchName: _s(j['branchName']),
    requestedByName: _s(j['requestedByName']),
    status: _s(j['status']),
    createdAt: DateTime.tryParse(_s(j['createdAt']))?.toLocal(),
    requestNote: _s(j['requestNote']),
    reviewNote: _s(j['reviewNote']),
    loadedShort: _s(j['loadedShort']),
    loadedDetail: _s(j['loadedDetail']),
    reviewedByName: _s(j['reviewedByName']),
    inventorySubmitted: j['inventorySubmitted'] == true,
    inventoryConfirmed: j['inventoryConfirmed'] == true,
    inventoryRevisionRequested: j['inventoryRevisionRequested'] == true,
    vehicleBillAmount: _n(j['vehicleBillAmount']),
    otherBillAmount: _n(j['otherBillAmount']),
    totalAmount: _n(j['totalAmount']),
  );

  /// SeizedConfirmedDetailPage ke liye (wo Map<String, dynamic> leta hai)
  Map<String, dynamic> toMap() => {
    '_id': id,
    'caseId': caseId,
    'caseCode': caseCode,
    'vehicleNumber': vehicleNumber,
    'customerName': customerName,
    'bankName': bankName,
    'branchName': branchName,
    'requestedByName': requestedByName,
    'status': status,
    'createdAt': createdAt?.toIso8601String(),
    'requestNote': requestNote,
    'reviewNote': reviewNote,
    'loadedShort': loadedShort,
    'loadedDetail': loadedDetail,
    'reviewedByName': reviewedByName,
    'inventorySubmitted': inventorySubmitted,
    'inventoryConfirmed': inventoryConfirmed,
    'inventoryRevisionRequested': inventoryRevisionRequested,
    'vehicleBillAmount': vehicleBillAmount,
    'otherBillAmount': otherBillAmount,
    'totalAmount': totalAmount,
  };

  /// 31/10/2026
  String get dateText {
    final d = createdAt;
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  /// 26/10/2026, 11:59:16  (Reported At)
  String get reportedText {
    final d = createdAt;
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}, '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  /// Field Note: requestNote, na ho to reviewNote
  String get fieldNote => requestNote.isNotEmpty ? requestNote : reviewNote;

  String get loadedText =>
      [loadedShort, loadedDetail].where((e) => e.isNotEmpty).join('\n');

  String get inventoryLabel {
    if (inventoryConfirmed) return 'Confirmed';
    if (inventoryRevisionRequested) return 'Update requested';
    if (inventorySubmitted) return 'Pending approval';
    return 'Not uploaded';
  }

  static String money(num v) {
    final isInt = v == v.roundToDouble();
    final s = isInt ? v.toInt().toString() : v.toStringAsFixed(2);
    final parts = s.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
    );
    return '₹ ${parts.length > 1 ? '$whole.${parts[1]}' : whole}';
  }
}

// ═════════════════════════════════════════════════════════════
//                     SEIZED LIST SCREEN
// ═════════════════════════════════════════════════════════════
class SeizedSuccessfullyScreen extends StatefulWidget {
  /// Optional: custom handler for View / card tap.
  final void Function(SeizedItem item)? onOpen;

  const SeizedSuccessfullyScreen({super.key, this.onOpen});

  @override
  State<SeizedSuccessfullyScreen> createState() =>
      _SeizedSuccessfullyScreenState();
}

class _SeizedSuccessfullyScreenState extends State<SeizedSuccessfullyScreen> {
  static const int _limit = 50;

  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<SeizedItem> _items = [];
  int _page = 1;
  int _total = 0;
  bool _hasNext = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _downloading = false;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
          _hasNext &&
          !_loadingMore &&
          !_loading) {
        _fetch(page: _page + 1);
      }
    });
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ───────────────────────── Data ─────────────────────────
  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Uri _uri(int page) =>
      Uri.parse('$_kBase/confirmations').replace(queryParameters: {
        'status': 'CONFIRMED',
        'page': '$page',
        'limit': '$_limit',
        'view': 'inventory-confirmed',
        'uniqueBy': 'vehicle',
        if (_query.isNotEmpty) 'search': _query,
      });

  /// Ek page laata hai -> (rows, pagination)
  Future<({List<SeizedItem> rows, Map pg})> _getPage(
      int page, String token) async {
    final res = await http.get(_uri(page), headers: {
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Server error (${res.statusCode})');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Request failed');
    }

    final raw = (body['data'] as List?) ?? const [];
    final rows = raw
        .whereType<Map>()
        .map((e) => SeizedItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (rows: rows, pg: (body['pagination'] as Map?) ?? const {});
  }

  Future<void> _fetch({int page = 1}) async {
    final append = page > 1;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });

    try {
      final r = await _getPage(page, await _token());
      if (!mounted) return;
      setState(() {
        if (append) {
          _items.addAll(r.rows);
        } else {
          _items
            ..clear()
            ..addAll(r.rows);
        }
        _page = (r.pg['page'] as num?)?.toInt() ?? page;
        _total = (r.pg['total'] as num?)?.toInt() ?? _items.length;
        _hasNext = r.pg['hasNextPage'] == true;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  // ───────────────────────── Excel ─────────────────────────
  Future<void> _downloadExcel() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final token = await _token();

      // Saare pages (current search ke saath) fetch karo
      final all = <SeizedItem>[];
      final seen = <String>{};
      var page = 1;
      while (page <= 200) {
        final r = await _getPage(page, token);
        for (final i in r.rows) {
          if (i.id.isEmpty || seen.add(i.id)) all.add(i);
        }
        if (r.pg['hasNextPage'] != true || r.rows.isEmpty) break;
        page++;
      }

      if (all.isEmpty) {
        _snack('Download karne ke liye koi data nahi hai');
        return;
      }

      final excel = xl.Excel.createExcel();
      final sheet = excel['Seized Vehicles'];
      excel.delete('Sheet1');

      sheet.appendRow([
        'S.No',
        'Registration Number',
        'Customer Name',
        'Status',
        'Field Note',
        'Loaded Details',
        'Inventory',
        'Confirmed By',
        'Reported At',
        'Vehicle Bill Amount',
        'Other Bill Amount',
        'Total Amount',
      ].map((h) => xl.TextCellValue(h)).toList());

      for (var i = 0; i < all.length; i++) {
        final r = all[i];
        sheet.appendRow([
          xl.TextCellValue('${all.length - i}'),
          xl.TextCellValue(r.vehicleNumber),
          xl.TextCellValue(r.customerName),
          xl.TextCellValue('SEIZED'),
          xl.TextCellValue(r.fieldNote),
          xl.TextCellValue(r.loadedText.replaceAll('\n', ' - ')),
          xl.TextCellValue(r.inventoryLabel),
          xl.TextCellValue(r.reviewedByName),
          xl.TextCellValue(r.createdAt == null ? '' : r.reportedText),
          xl.DoubleCellValue(r.vehicleBillAmount.toDouble()),
          xl.DoubleCellValue(r.otherBillAmount.toDouble()),
          xl.DoubleCellValue(r.totalAmount.toDouble()),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Excel file ban nahi payi');

      final dir = await getTemporaryDirectory();
      final n = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}';
      final file = File('${dir.path}/seized_vehicles_$stamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Seized Vehicles (${all.length})',
      );
    } catch (e) {
      _snack('Excel error: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ───────────────────────── Search ─────────────────────────
  void _onChanged(String _) {
    setState(() {}); // refresh clear icon
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final q = _searchCtrl.text.trim();
      if (q != _query) {
        _query = q;
        _fetch();
      }
    });
  }

  void _onSubmitted(String _) {
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    FocusScope.of(context).unfocus();
    if (q != _query) {
      _query = q;
      _fetch();
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    FocusScope.of(context).unfocus();
    final hadQuery = _query.isNotEmpty;
    _query = '';
    setState(() {});
    if (hadQuery) _fetch();
  }

  // ───────────────────────── Navigation ─────────────────────────
  Future<void> _open(SeizedItem it) async {
    if (widget.onOpen != null) {
      widget.onOpen!(it);
      return;
    }

    final token = await _token();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeizedConfirmedDetailPage(
          token: token,
          item: it.toMap(),
          onChanged: () {
            if (mounted) _fetch();
          },
        ),
      ),
    );
  }

  // ───────────────────────── Build ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9);
    final card = isDark ? const Color(0xFF162033) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final border = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _header(context),
          Transform.translate(
            offset: const Offset(0, -22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _searchRow(isDark, card, text, muted),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -10),
              child: _buildBody(isDark, card, text, muted, border),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Header ─────────────────────────
  Widget _header(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final canPop = Navigator.of(context).canPop();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(8, top + 8, 16, 38),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBrandA, _kBrandB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            )
          else
            const SizedBox(width: 12),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seized Vehicles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _loading
                      ? 'Loading…'
                      : '$_total vehicle${_total == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Search + Download ─────────────────────────
  Widget _searchRow(bool isDark, Color card, Color text, Color muted) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onChanged,
              onSubmitted: _onSubmitted,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search vehicle, customer, chassis, loan…',
                hintStyle: TextStyle(color: muted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: muted, size: 22),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: Icon(Icons.close_rounded, color: muted, size: 20),
                  onPressed: _clearSearch,
                ),
                filled: true,
                fillColor: card,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _kBrandB, width: 1.4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Download Excel',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _kExcel.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: _downloading ? Colors.grey.shade500 : _kExcel,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _downloading ? null : _downloadExcel,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Center(
                    child: _downloading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.download_rounded,
                        color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Body ─────────────────────────
  Widget _buildBody(
      bool isDark, Color card, Color text, Color muted, Color border) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off_rounded,
                    color: Colors.red.shade400, size: 32),
              ),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 14)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _fetch(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBrandB,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _kBrandB,
      onRefresh: () => _fetch(),
      child: _items.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kBrandB.withOpacity(isDark ? 0.25 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2_outlined,
                  size: 40, color: isDark ? _kBrandA : _kBrandB),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _query.isEmpty
                  ? 'No seized vehicles yet.'
                  : 'No results found for "$_query".',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      )
          : ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final base = _total >= _items.length ? _total : _items.length;
          return _tile(_items[i], base - i, isDark, card, text, muted, border);
        },
      ),
    );
  }

  // ───────────────────────── Case card ─────────────────────────
  Widget _tile(SeizedItem it, int sno, bool isDark, Color card, Color text,
      Color muted, Color border) {
    final tileBg = isDark ? Colors.white10 : const Color(0xFFF1F5F9);
    final noteBg = isDark
        ? const Color(0xFFF59E0B).withOpacity(.10)
        : const Color(0xFFFFF8E6);
    final noteBorder = isDark
        ? const Color(0xFFF59E0B).withOpacity(.25)
        : const Color(0xFFF5DFA3);
    final loadBg = isDark ? _kGreen.withOpacity(.10) : const Color(0xFFEFF8F0);
    final loadBorder =
    isDark ? _kGreen.withOpacity(.25) : const Color(0xFFC5E3C8);

    final invColor = it.inventoryConfirmed
        ? _kGreen
        : (it.inventoryRevisionRequested
        ? const Color(0xFFEA580C)
        : const Color(0xFFD97706));

    String v(String s) => (s.isEmpty || s == '-') ? '—' : s;

    Widget label(String t) => Text(t,
        style: TextStyle(
            color: muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .5));

    Widget noteBox(
        String title, String body, IconData icon, Color bg, Color bd) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: muted),
                const SizedBox(width: 5),
                Text(title.toUpperCase(),
                    style: TextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5)),
              ],
            ),
            const SizedBox(height: 4),
            Text(body,
                style: TextStyle(
                    color: text,
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    Widget row(IconData icon, String name,
        {String? value, Widget? trailing}) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(icon, size: 15, color: muted),
            const SizedBox(width: 6),
            Text(name,
                style: TextStyle(
                    color: muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (trailing != null)
              trailing
            else
              Flexible(
                child: Text(value ?? '—',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      );
    }

    // Bills: 3 chhote tiles ek row mein
    Widget billTile(String title, num amount, {bool highlight = false}) {
      final hl = isDark ? _kBrandA : _kBrandB;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: highlight ? hl.withOpacity(.10) : tileBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: highlight ? hl.withOpacity(.35) : border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(SeizedItem.money(amount),
                    style: TextStyle(
                        color: highlight ? hl : text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(it),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // green accent strip
                Container(width: 4, color: _kGreen),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header: S.No + Registration Number + Status
                        Row(
                          children: [
                            Container(
                              constraints: const BoxConstraints(minWidth: 32),
                              height: 32,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: tileBg,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text('$sno',
                                  style: TextStyle(
                                      color: text,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  label('REGISTRATION NUMBER'),
                                  const SizedBox(height: 1),
                                  Text(v(it.vehicleNumber),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: text,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: .8)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: _kGreen.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 12, color: _kGreen),
                                  SizedBox(width: 4),
                                  Text('SEIZED',
                                      style: TextStyle(
                                          color: _kGreen,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4)),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ── Customer Name
                        label('CUSTOMER NAME'),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 17, color: muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(v(it.customerName),
                                  style: TextStyle(
                                      color: text,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ── Field Note
                        noteBox('Field Note', v(it.fieldNote),
                            Icons.sticky_note_2_outlined, noteBg, noteBorder),
                        const SizedBox(height: 8),

                        // ── Loaded Details
                        noteBox(
                            'Loaded Details',
                            it.loadedText.isEmpty ? '—' : it.loadedText,
                            Icons.local_shipping_outlined,
                            loadBg,
                            loadBorder),

                        const SizedBox(height: 10),
                        Divider(height: 1, color: border),

                        // ── Inventory / Confirmed By / Reported At
                        row(
                          Icons.inventory_2_outlined,
                          'Inventory',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: invColor.withOpacity(.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(it.inventoryLabel.toUpperCase(),
                                style: TextStyle(
                                    color: invColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                        row(Icons.verified_user_outlined, 'Confirmed By',
                            value: v(it.reviewedByName)),
                        row(Icons.schedule_rounded, 'Reported At',
                            value: it.reportedText),

                        const SizedBox(height: 12),

                        // ── Bills
                        Row(
                          children: [
                            billTile('Vehicle Bill', it.vehicleBillAmount),
                            const SizedBox(width: 8),
                            billTile('Other Bill', it.otherBillAmount),
                            const SizedBox(width: 8),
                            billTile('Total Amount', it.totalAmount,
                                highlight: true),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ── Action
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_kBrandA, _kBrandB]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _open(it),
                              icon: const Icon(Icons.visibility_rounded,
                                  size: 16),
                              label: const Text('View',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//                     SEIZED DETAIL PAGE
// ═════════════════════════════════════════════════════════════
class SeizedDetailPage extends StatelessWidget {
  final SeizedItem item;
  const SeizedDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9);
    final card = isDark ? const Color(0xFF162033) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final border = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(8, top + 8, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kBrandA, _kBrandB],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(26),
                bottomRight: Radius.circular(26),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: Text(
                    'Seized Vehicle Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Vehicle number + status
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        item.vehicleNumber.isEmpty ? '—' : item.vehicleNumber,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kGreen.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 14, color: _kGreen),
                            SizedBox(width: 6),
                            Text(
                              'SEIZED SUCCESSFULLY',
                              style: TextStyle(
                                color: _kGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Details
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: [
                      _row(Icons.person_outline_rounded, 'Customer',
                          item.customerName, text, muted, border),
                      _row(Icons.account_balance_outlined, 'Bank',
                          item.bankName, text, muted, border),
                      _row(Icons.location_city_outlined, 'Branch',
                          item.branchName, text, muted, border),
                      _row(Icons.tag_rounded, 'Case Code', item.caseCode,
                          text, muted, border),
                      _row(Icons.badge_outlined, 'Requested By',
                          item.requestedByName, text, muted, border),
                      _row(Icons.flag_outlined, 'Status', item.status, text,
                          muted, border),
                      _row(Icons.calendar_today_outlined, 'Date',
                          item.dateText, text, muted, border,
                          last: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color text,
      Color muted, Color border,
      {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kBrandB),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}