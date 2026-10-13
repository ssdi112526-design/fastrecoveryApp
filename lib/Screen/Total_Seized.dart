import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _kBase = 'https://fastrecovery.in/api';

// Brand colors
const Color _kBrandA = Color(0xFF38B6FF);
const Color _kBrandB = Color(0xFF1D3FAE);

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
  });

  static String _s(dynamic v) => v == null ? '' : v.toString();

  factory SeizedItem.fromJson(Map<String, dynamic> j) => SeizedItem(
    id: _s(j['_id'] ?? j['id']),
    caseId: _s(j['caseId']),
    caseCode: _s(j['caseCode']),
    vehicleNumber: _s(j['vehicleNumber']),
    customerName: _s(j['customerName']),
    bankName: _s(j['bankName']),
    branchName: _s(j['branchName']),
    requestedByName: _s(j['requestedByName']),
    status: _s(j['status']),
    createdAt: DateTime.tryParse(_s(j['createdAt']))?.toLocal(),
  );
}

class SeizedSuccessfullyScreen extends StatefulWidget {
  /// Called when a row is tapped (open your confirmation detail screen here).
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final uri = Uri.parse('$_kBase/confirmations').replace(queryParameters: {
        'status': 'CONFIRMED',
        'page': '$page',
        'limit': '$_limit',
        'view': 'inventory-confirmed',
        'uniqueBy': 'vehicle',
        if (_query.isNotEmpty) 'search': _query,
      });

      final res = await http.get(uri, headers: {
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
      final pg = (body['pagination'] as Map?) ?? const {};

      if (!mounted) return;
      setState(() {
        if (append) {
          _items.addAll(rows);
        } else {
          _items
            ..clear()
            ..addAll(rows);
        }
        _page = (pg['page'] as num?)?.toInt() ?? page;
        _total = (pg['total'] as num?)?.toInt() ?? _items.length;
        _hasNext = pg['hasNextPage'] == true;
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

  void _search() {
    _debounce?.cancel();
    _query = _searchCtrl.text.trim();
    FocusScope.of(context).unfocus();
    _fetch();
  }

  void _reset() {
    _debounce?.cancel();
    _searchCtrl.clear();
    _query = '';
    FocusScope.of(context).unfocus();
    setState(() {});
    _fetch();
  }

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
          // Search card overlapping the header
          Transform.translate(
            offset: const Offset(0, -22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _searchCard(isDark, card, text, muted, border),
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
                  'Seized Successfully',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _loading ? 'Loading…' : '$_total vehicle${_total == 1 ? '' : 's'}',
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

  // ───────────────────────── Search card ─────────────────────────
  Widget _searchCard(
      bool isDark, Color card, Color text, Color muted, Color border) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: _onChanged,
            onSubmitted: (_) => _search(),
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
                onPressed: _reset,
              ),
              filled: true,
              fillColor: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBrandB, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_kBrandA, _kBrandB]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _search,
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Search',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: text,
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
                  ? 'No cases with admin-confirmed inventory yet.'
                  : 'No results found for "$_query".',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: muted, fontSize: 15, fontWeight: FontWeight.w500),
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
          return _tile(_items[i], isDark, card, text, muted, border);
        },
      ),
    );
  }

  // ───────────────────────── Case card ─────────────────────────
  Widget _tile(SeizedItem it, bool isDark, Color card, Color text, Color muted,
      Color border) {
    String date = '';
    if (it.createdAt != null) {
      final d = it.createdAt!;
      date =
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    final bankLine =
    [it.bankName, it.branchName].where((s) => s.isNotEmpty).join(' • ');

    return Material(
      color: card,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onOpen == null ? null : () => widget.onOpen!(it),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // green accent strip
                Container(
                  width: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                it.vehicleNumber.isEmpty
                                    ? '—'
                                    : it.vehicleNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: text,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A)
                                    .withOpacity(0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 12, color: Color(0xFF16A34A)),
                                  SizedBox(width: 4),
                                  Text(
                                    'SEIZED',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (it.customerName.isNotEmpty)
                          _infoRow(Icons.person_outline_rounded,
                              it.customerName, text, muted,
                              bold: true),
                        if (bankLine.isNotEmpty)
                          _infoRow(Icons.account_balance_outlined, bankLine,
                              muted, muted),
                        if (it.caseCode.isNotEmpty)
                          _infoRow(Icons.tag_rounded, 'Case ${it.caseCode}',
                              muted, muted),
                        if (it.requestedByName.isNotEmpty || date.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Divider(height: 1, color: border),
                          ),
                          Row(
                            children: [
                              if (it.requestedByName.isNotEmpty) ...[
                                Icon(Icons.badge_outlined,
                                    size: 14, color: muted),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    it.requestedByName,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                    TextStyle(color: muted, fontSize: 12),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (date.isNotEmpty) ...[
                                Icon(Icons.calendar_today_outlined,
                                    size: 13, color: muted),
                                const SizedBox(width: 5),
                                Text(date,
                                    style:
                                    TextStyle(color: muted, fontSize: 12)),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.onOpen != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.chevron_right_rounded, color: muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value, Color valueColor, Color iconColor,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontSize: 13.5,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}