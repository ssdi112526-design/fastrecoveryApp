import 'dart:convert';
import 'dart:io';
import 'package:excel_plus/excel_plus.dart' as xl;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────
class CancelItem {
  final String id;
  final String caseId;
  final String caseCode;
  final String status;
  final String finalAction;
  final String vehicleNumber;
  final String customerName;
  final String bankName;
  final String branchName;
  final String requestNote;
  final String reviewNote;
  final String requestedByName;
  final String requestedByRoleLabel;
  final String requestedByPhone;
  final String reviewedByName;
  final String traceMode;
  final String shareChannel;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final num vehicleBillAmount;
  final num otherBillAmount;
  final num totalAmount;
  final String parkingYardName;
  final String parkingYardAddress;
  final bool inventorySubmitted;
  final bool inventoryConfirmed;

  CancelItem({
    required this.id,
    required this.caseId,
    required this.caseCode,
    required this.status,
    required this.finalAction,
    required this.vehicleNumber,
    required this.customerName,
    required this.bankName,
    required this.branchName,
    required this.requestNote,
    required this.reviewNote,
    required this.requestedByName,
    required this.requestedByRoleLabel,
    required this.requestedByPhone,
    required this.reviewedByName,
    required this.traceMode,
    required this.shareChannel,
    required this.createdAt,
    required this.reviewedAt,
    required this.vehicleBillAmount,
    required this.otherBillAmount,
    required this.totalAmount,
    required this.parkingYardName,
    required this.parkingYardAddress,
    required this.inventorySubmitted,
    required this.inventoryConfirmed,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();
  static num _n(dynamic v) => v is num ? v : num.tryParse(_s(v)) ?? 0;
  static DateTime? _d(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory CancelItem.fromJson(Map<String, dynamic> j) => CancelItem(
    id: _s(j['_id']),
    caseId: _s(j['caseId']),
    caseCode: _s(j['caseCode']),
    status: _s(j['status']),
    finalAction: _s(j['finalAction']),
    vehicleNumber: _s(j['vehicleNumber']),
    customerName: _s(j['customerName']).replaceAll(RegExp(r'\s+'), ' '),
    bankName: _s(j['bankName']),
    branchName: _s(j['branchName']),
    requestNote: _s(j['requestNote']),
    reviewNote: _s(j['reviewNote']),
    requestedByName: _s(j['requestedByName']),
    requestedByRoleLabel: _s(j['requestedByRoleLabel']),
    requestedByPhone: _s(j['requestedByPhone']),
    reviewedByName: _s(j['reviewedByName']),
    traceMode: _s(j['traceMode']),
    shareChannel: _s(j['shareChannel']),
    createdAt: _d(j['createdAt']),
    reviewedAt: _d(j['reviewedAt']),
    vehicleBillAmount: _n(j['vehicleBillAmount']),
    otherBillAmount: _n(j['otherBillAmount']),
    totalAmount: _n(j['totalAmount']),
    parkingYardName: _s(j['parkingYardName']),
    parkingYardAddress: _s(j['parkingYardAddress']),
    inventorySubmitted: j['inventorySubmitted'] == true,
    inventoryConfirmed: j['inventoryConfirmed'] == true,
  );

  /// Search ke liye ek hi string
  String get searchBlob => [
    vehicleNumber,
    customerName,
    caseCode,
    bankName,
    branchName,
    requestedByName,
    requestedByPhone,
    reviewedByName,
    shareChannel,
    requestNote,
    reviewNote,
  ].join(' ').toLowerCase().replaceAll(' ', '');
}

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────
class CancelConfirmationsScreen extends StatefulWidget {
  final String? token;
  const CancelConfirmationsScreen({super.key, required this.token});

  @override
  State<CancelConfirmationsScreen> createState() =>
      _CancelConfirmationsScreenState();
}

class _CancelConfirmationsScreenState extends State<CancelConfirmationsScreen> {
  static const String _base = 'https://fastrecovery.in/api/confirmations';
  static const int _limit = 50;

  final TextEditingController _searchCtrl = TextEditingController();
  final DateFormat _fmt = DateFormat('dd/MM/yyyy, HH:mm:ss');

  List<CancelItem> _all = [];
  String _query = '';
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── API ────────────────────────────────────────────────────
  // NOTE: token ka key apne app ke hisaab se change karo (yahan 'token').
  Future<Map<String, String>> _headers() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token') ?? sp.getString('authToken') ?? '';
    return {
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Saare pages fetch karta hai (page=1.. hasNextPage tak)
  Future<List<CancelItem>> _fetchAll() async {
    final headers = await _headers();
    final out = <CancelItem>[];
    int page = 1;
    while (true) {
      final uri = Uri.parse('$_base?status=REJECTED&page=$page&limit=$_limit');
      final res =
      await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('Server error ${res.statusCode}');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        throw Exception(body['message']?.toString() ?? 'Failed');
      }
      final list = (body['data'] as List? ?? [])
          .map((e) => CancelItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      out.addAll(list);
      final pg = body['pagination'] as Map<String, dynamic>? ?? {};
      if (pg['hasNextPage'] != true || list.isEmpty) break;
      page++;
    }
    return out;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _fetchAll();
      if (!mounted) return;
      setState(() {
        _all = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ── SEARCH ─────────────────────────────────────────────────
  List<CancelItem> get _filtered {
    final q = _query.toLowerCase().replaceAll(' ', '');
    if (q.isEmpty) return _all;
    return _all.where((e) => e.searchBlob.contains(q)).toList();
  }

  void _doSearch() => setState(() => _query = _searchCtrl.text.trim());

  void _reset() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  // ── EXCEL ──────────────────────────────────────────────────
  Future<void> _downloadExcel() async {
    final rows = _filtered;
    if (rows.isEmpty) {
      _snack('Download karne ke liye koi data nahi hai');
      return;
    }
    setState(() => _downloading = true);
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Cancel Confirmations'];
      excel.delete('Sheet1');

      final headers = [
        'S.No',
        'Case Code',
        'Registration Number',
        'Customer Name',
        'Bank / NBFC',
        'Branch',
        'Status',
        'Final Action',
        'Field Note',
        'Review Note',
        'Reported By',
        'Role',
        'Phone',
        'Share Channel',
        'Trace Mode',
        'Reported At',
        'Reviewed By',
        'Reviewed At',
      ];
      sheet.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());

      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        sheet.appendRow([
          xl.TextCellValue('${_all.length - _all.indexOf(r)}'),
          xl.TextCellValue(r.caseCode),
          xl.TextCellValue(r.vehicleNumber),
          xl.TextCellValue(r.customerName),
          xl.TextCellValue(r.bankName),
          xl.TextCellValue(r.branchName),
          xl.TextCellValue('CANCEL'),
          xl.TextCellValue(r.finalAction),
          xl.TextCellValue(r.requestNote),
          xl.TextCellValue(r.reviewNote),
          xl.TextCellValue(r.requestedByName),
          xl.TextCellValue(r.requestedByRoleLabel),
          xl.TextCellValue(r.requestedByPhone),
          xl.TextCellValue(r.shareChannel),
          xl.TextCellValue(r.traceMode),
          xl.TextCellValue(r.createdAt == null ? '' : _fmt.format(r.createdAt!)),
          xl.TextCellValue(r.reviewedByName),
          xl.TextCellValue(r.reviewedAt == null ? '' : _fmt.format(r.reviewedAt!)),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Excel file ban nahi payi');

      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/cancel_confirmations_$stamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Cancel Confirmations (${rows.length} cases)',
      );
    } catch (e) {
      _snack('Excel error: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ── UI ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Cancel confirmations'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text('${list.length} cases',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(child: _buildBody(list)),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _doSearch(),
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search vehicle, customer, bank, case code…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.close), onPressed: _reset),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _doSearch,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2653C8),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _downloading ? null : _downloadExcel,
                  icon: _downloading
                      ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download, size: 18),
                  label: const Text('Download Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<CancelItem> list) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (list.isEmpty) {
      return const Center(child: Text('Koi cancel confirmation nahi mila'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final item = list[i];
          final sno = _all.length - _all.indexOf(item); // web jaisa descending S.No
          return _CancelCard(item: item, sno: sno, fmt: _fmt);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CARD
// ─────────────────────────────────────────────────────────────
class _CancelCard extends StatelessWidget {
  final CancelItem item;
  final int sno;
  final DateFormat fmt;

  const _CancelCard({required this.item, required this.sno, required this.fmt});

  String _v(String s) => s.isEmpty ? '—' : s;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: S.No + vehicle + CANCEL badge
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFEDEFF5),
                  child: Text('$sno',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _v(item.vehicleNumber),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: .5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE4E1),
                    border: Border.all(color: const Color(0xFFE57373)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('CANCEL',
                      style: TextStyle(
                          color: Color(0xFFB71C1C),
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 20),
            _row(Icons.person, 'Customer', item.customerName),
            _row(Icons.confirmation_number, 'Case Code', item.caseCode),
            _row(Icons.account_balance, 'Bank / NBFC', item.bankName),
            _row(Icons.location_city, 'Branch', item.branchName),
            _row(Icons.sticky_note_2_outlined, 'Field Note', item.requestNote),
            _row(Icons.rate_review_outlined, 'Review Note', item.reviewNote),
            const Divider(height: 20),
            _row(Icons.badge_outlined, 'Reported By',
                '${_v(item.requestedByName)} (${_v(item.requestedByRoleLabel)})'),
            _row(Icons.phone, 'Phone', item.requestedByPhone),
            _row(Icons.share, 'Share Channel', item.shareChannel.toUpperCase()),
            _row(Icons.travel_explore, 'Trace Mode', item.traceMode),
            _row(Icons.schedule, 'Reported At',
                item.createdAt == null ? '' : fmt.format(item.createdAt!)),
            _row(Icons.verified_user_outlined, 'Reviewed By', item.reviewedByName),
            _row(Icons.event_available, 'Reviewed At',
                item.reviewedAt == null ? '' : fmt.format(item.reviewedAt!)),
            if (item.parkingYardName.isNotEmpty ||
                item.totalAmount > 0 ||
                item.inventorySubmitted) ...[
              const Divider(height: 20),
              _row(Icons.local_parking, 'Parking Yard', item.parkingYardName),
              _row(Icons.place_outlined, 'Yard Address', item.parkingYardAddress),
              _row(Icons.currency_rupee, 'Vehicle Bill', '${item.vehicleBillAmount}'),
              _row(Icons.currency_rupee, 'Other Bill', '${item.otherBillAmount}'),
              _row(Icons.currency_rupee, 'Total', '${item.totalAmount}'),
              _row(Icons.inventory_2_outlined, 'Inventory',
                  item.inventoryConfirmed
                      ? 'Confirmed'
                      : item.inventorySubmitted
                      ? 'Submitted'
                      : 'Not submitted'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(_v(value),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}