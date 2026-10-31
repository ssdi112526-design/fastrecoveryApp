import 'dart:convert';
import 'dart:io';

import 'package:excel_plus/excel_plus.dart' as xl;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';

// =============================================================
// MODEL
// =============================================================

class _ConfirmationItem {
  final String id;
  final String status;
  final String vehicleNumber;
  final String customerName;
  final String requestNote;
  final String loadedShort;
  final String loadedDetail;
  final String caseCode;
  final String bankName;
  final DateTime? createdAt;

  const _ConfirmationItem({
    required this.id,
    required this.status,
    required this.vehicleNumber,
    required this.customerName,
    required this.requestNote,
    required this.loadedShort,
    required this.loadedDetail,
    required this.caseCode,
    required this.bankName,
    required this.createdAt,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();

  factory _ConfirmationItem.fromJson(Map<String, dynamic> j) {
    return _ConfirmationItem(
      id: _s(j['_id']),
      status: _s(j['status']),
      vehicleNumber: _s(j['vehicleNumber']),
      customerName: _s(j['customerName']).replaceAll(RegExp(r'\s+'), ' '),
      requestNote: _s(j['requestNote']),
      loadedShort: _s(j['loadedShort']),
      loadedDetail: _s(j['loadedDetail']),
      caseCode: _s(j['caseCode']),
      bankName: _s(j['bankName']),
      createdAt: DateTime.tryParse(_s(j['createdAt']))?.toLocal(),
    );
  }

  /// Loaded short + detail ek text mein
  String get loadedText =>
      [loadedShort, loadedDetail].where((e) => e.isNotEmpty).join('\n');

  String get searchBlob => [
    vehicleNumber,
    customerName,
    status,
    requestNote,
    loadedShort,
    loadedDetail,
    caseCode,
    bankName,
  ].join(' ').toLowerCase().replaceAll(' ', '');
}

class _PageResult {
  final List<_ConfirmationItem> items;
  final bool hasNext;
  final int? total;
  const _PageResult(this.items, this.hasNext, this.total);
}

// =============================================================
// PAGE
// =============================================================

class PendingConfirmationPage extends StatefulWidget {
  const PendingConfirmationPage({super.key});

  @override
  State<PendingConfirmationPage> createState() =>
      _PendingConfirmationPageState();
}

class _PendingConfirmationPageState extends State<PendingConfirmationPage> {
  static const String _baseUrl = 'https://www.fastrecovery.in';
  static const int _limit = 50;

  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  // id -> item (insertion order maintain hota hai)
  final Map<String, _ConfirmationItem> _map = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _downloading = false;
  bool _hasNext = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  String _query = '';

  List<_ConfirmationItem> get _all => _map.values.toList();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // DATA
  // ---------------------------------------------------------

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final nearEnd =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 300;
    if (nearEnd && _hasNext && !_loading && !_loadingMore) {
      _load(reset: false);
    }
  }

  Future<_PageResult> _fetchPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('token') ?? '').trim();
    if (token.isEmpty) throw Exception('Session expired');

    final uri = Uri.parse('$_baseUrl/api/confirmations').replace(
      queryParameters: {
        'status': 'PENDING',
        'page': '$page',
        'limit': '$_limit',
        'groupBy': 'vehicle',
      },
    );

    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 20));

    if (res.statusCode == 401) throw Exception('Session expired');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Server error (${res.statusCode})');
    }

    final body = jsonDecode(res.body);
    if (body is! Map || body['success'] != true) {
      throw Exception('Invalid response');
    }

    final items = <_ConfirmationItem>[];
    final rawData = body['data'];
    if (rawData is List) {
      for (final e in rawData) {
        if (e is Map) {
          final item =
          _ConfirmationItem.fromJson(Map<String, dynamic>.from(e));
          if (item.id.isNotEmpty) items.add(item);
        }
      }
    }

    final pg = body['pagination'];
    final hasNext = pg is Map && pg['hasNextPage'] == true;

    int? total;
    final rt = body['requestTotal'];
    if (rt != null) {
      total = rt is int ? rt : int.tryParse(rt.toString());
    } else if (pg is Map && pg['total'] != null) {
      final t = pg['total'];
      total = t is int ? t : int.tryParse(t.toString());
    }

    return _PageResult(items, hasNext, total);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final r = await _fetchPage(_page);
      if (!mounted) return;
      setState(() {
        if (reset) _map.clear();
        for (final i in r.items) {
          _map[i.id] = i;
        }
        _total = r.total ?? _map.length;
        _hasNext = r.hasNext;
        if (r.hasNext) _page += 1;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('[PENDING CONFIRMATION] error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (_map.isEmpty) {
          _error = e.toString().contains('Session expired')
              ? 'Session expired. Please login again.'
              : 'Unable to load pending confirmations.';
        }
      });
      if (_map.isNotEmpty) _snack('Could not refresh. Check your internet.');
    }
  }

  // ---------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------

  List<_ConfirmationItem> _applyFilter(List<_ConfirmationItem> src) {
    final q = _query.toLowerCase().replaceAll(' ', '');
    if (q.isEmpty) return src;
    return src.where((e) => e.searchBlob.contains(q)).toList();
  }

  int _snoOf(int indexInAll) {
    final base = _total >= _map.length ? _total : _map.length;
    return base - indexInAll;
  }

  // ---------------------------------------------------------
  // EXCEL
  // ---------------------------------------------------------

  Future<void> _downloadExcel() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      // Saare pages fetch karo (sirf wahi nahi jo screen par load hue)
      final all = <_ConfirmationItem>[];
      final seen = <String>{};
      int page = 1;
      while (true) {
        final r = await _fetchPage(page);
        for (final i in r.items) {
          if (seen.add(i.id)) all.add(i);
        }
        if (!r.hasNext || r.items.isEmpty) break;
        page++;
      }

      final total = all.length;
      final rows = <MapEntry<int, _ConfirmationItem>>[];
      for (int i = 0; i < all.length; i++) {
        rows.add(MapEntry(total - i, all[i]));
      }
      final q = _query.toLowerCase().replaceAll(' ', '');
      final filtered = q.isEmpty
          ? rows
          : rows.where((e) => e.value.searchBlob.contains(q)).toList();

      if (filtered.isEmpty) {
        _snack('Download karne ke liye koi data nahi hai');
        return;
      }

      final excel = xl.Excel.createExcel();
      final sheet = excel['Pending Confirmations'];
      excel.delete('Sheet1');

      sheet.appendRow([
        'S.No',
        'Registration Number',
        'Customer Name',
        'Status',
        'Field Note',
        'Loaded Details',
        'Reported At',
      ].map((h) => xl.TextCellValue(h)).toList());

      for (final e in filtered) {
        final r = e.value;
        sheet.appendRow([
          xl.TextCellValue('${e.key}'),
          xl.TextCellValue(r.vehicleNumber),
          xl.TextCellValue(r.customerName),
          xl.TextCellValue(r.status.isEmpty ? 'PENDING' : r.status),
          xl.TextCellValue(r.requestNote),
          xl.TextCellValue(r.loadedText.replaceAll('\n', ' - ')),
          xl.TextCellValue(r.createdAt == null ? '' : _formatDate(r.createdAt)),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Excel file ban nahi payi');

      final dir = await getTemporaryDirectory();
      final n = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}';
      final file = File('${dir.path}/pending_confirmations_$stamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Pending Confirmations (${filtered.length} cases)',
      );
    } catch (e) {
      _snack(e.toString().contains('Session expired')
          ? 'Session expired. Please login again.'
          : 'Excel error: $e');
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

  // ---------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} '
        '${d.year}, $h12:$mm $ap';
  }

  String _v(String s) => (s.isEmpty || s == '-') ? '—' : s;

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xff080D18) : const Color(0xffF5F7FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(
            children: [
              _buildTopBar(isDark),
              const SizedBox(height: 14),
              _buildSearchRow(isDark),
              const SizedBox(height: 14),
              Expanded(child: _buildBody(isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    final barColor = isDark ? const Color(0xff10182A) : Colors.white;
    final border = isDark ? const Color(0xff263550) : const Color(0xffE5EAF2);
    final textColor = isDark ? Colors.white : Colors.black;
    final backBg =
    isDark ? Colors.white.withOpacity(.08) : const Color(0xffF3F6FA);
    final shown = _applyFilter(_all).length;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .22 : .045),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 44,
                height: 44,
                decoration:
                BoxDecoration(color: backBg, shape: BoxShape.circle),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: textColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pending Confirmation',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -.2,
                color: textColor,
              ),
            ),
          ),
          if (!_loading && _error == null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xffF59E0B).withOpacity(.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _query.isEmpty ? '$_total cases' : '$shown cases',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xffD97706),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchRow(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xff0F172A);
    final muted = isDark ? const Color(0xff7F8BA4) : const Color(0xff64748B);

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: _cardDecoration(isDark),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Search vehicle, customer, case code',
                hintStyle: TextStyle(fontSize: 13, color: muted),
                prefixIcon: Icon(Icons.search_rounded, color: muted),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: Icon(Icons.close_rounded, color: muted),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
                border: InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Download Excel',
          child: Material(
            color: _downloading ? Colors.grey.shade400 : const Color(0xff2E7D32),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _downloading ? null : _downloadExcel,
              child: SizedBox(
                width: 50,
                height: 50,
                child: Center(
                  child: _downloading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.download_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading && _map.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue600),
        ),
      );
    }

    if (_error != null && _map.isEmpty) {
      return _messageView(
        isDark: isDark,
        icon: Icons.error_outline_rounded,
        title: _error!,
        showRetry: true,
      );
    }

    final all = _all;
    final filtered = _applyFilter(all);

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      color: AppColors.blue600,
      backgroundColor: isDark ? const Color(0xff121A2E) : Colors.white,
      child: filtered.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          _messageView(
            isDark: isDark,
            icon: Icons.inbox_rounded,
            title: _query.isEmpty
                ? 'No pending confirmations'
                : 'No result found',
          ),
        ],
      )
          : ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: filtered.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= filtered.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.blue600),
                  ),
                ),
              ),
            );
          }
          final item = filtered[i];
          final sno = _snoOf(all.indexOf(item));
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCard(item, sno, isDark),
          );
        },
      ),
    );
  }

  Widget _messageView({
    required bool isDark,
    required IconData icon,
    required String title,
    bool showRetry = false,
  }) {
    final muted = isDark ? const Color(0xff8996AF) : const Color(0xff64748B);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          if (showRetry) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => _load(reset: true),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // CARD
  // ---------------------------------------------------------

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xff10182A) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? const Color(0xff24304A) : const Color(0xffE5EAF2),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? .23 : .04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildCard(_ConfirmationItem i, int sno, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xff0F172A);
    final muted = isDark ? const Color(0xff7F8BA4) : const Color(0xff64748B);
    final divider = isDark ? const Color(0xff24304A) : const Color(0xffE5EAF2);
    final snoBg = isDark ? Colors.white.withOpacity(.08) : const Color(0xffF1F4F9);

    final status = i.status.isEmpty ? 'PENDING' : i.status.toUpperCase();

    return Container(
      decoration: _cardDecoration(isDark),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // amber accent strip
            Container(width: 4, color: const Color(0xffF59E0B)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: S.No + Registration + Status
                    Row(
                      children: [
                        Container(
                          constraints: const BoxConstraints(minWidth: 32),
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: snoBg,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '$sno',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'REGISTRATION NUMBER',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .5,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _v(i.vehicleNumber),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xffF59E0B).withOpacity(.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .4,
                              color: Color(0xffD97706),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Customer
                    _label('CUSTOMER NAME', muted),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 17, color: muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _v(i.customerName),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Field Note
                    _noteBox(
                      title: 'Field Note',
                      text: _v(i.requestNote),
                      icon: Icons.sticky_note_2_outlined,
                      bg: isDark
                          ? const Color(0xffF59E0B).withOpacity(.10)
                          : const Color(0xffFFF8E6),
                      border: isDark
                          ? const Color(0xffF59E0B).withOpacity(.25)
                          : const Color(0xffF5DFA3),
                      textColor: textColor,
                      muted: muted,
                    ),
                    const SizedBox(height: 8),

                    // ── Loaded Details
                    _noteBox(
                      title: 'Loaded Details',
                      text: i.loadedText.isEmpty ? '—' : i.loadedText,
                      icon: Icons.local_shipping_outlined,
                      bg: isDark
                          ? const Color(0xff16A34A).withOpacity(.10)
                          : const Color(0xffEFF8F0),
                      border: isDark
                          ? const Color(0xff16A34A).withOpacity(.25)
                          : const Color(0xffC5E3C8),
                      textColor: textColor,
                      muted: muted,
                    ),

                    const SizedBox(height: 12),
                    Divider(height: 1, color: divider),
                    const SizedBox(height: 10),

                    // ── Reported At
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: muted),
                        const SizedBox(width: 6),
                        Text(
                          'Reported At',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(i.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
        color: color,
      ),
    );
  }

  Widget _noteBox({
    required String title,
    required String text,
    required IconData icon,
    required Color bg,
    required Color border,
    required Color textColor,
    required Color muted,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: muted),
              const SizedBox(width: 5),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                  color: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}