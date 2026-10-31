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
// THEME COLORS
// ─────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF4F6FB);
  static const primary = Color(0xFF2653C8);
  static const green = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const dangerBg = Color(0xFFFDECEA);
  static const text = Color(0xFF1F2430);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E8F0);
  static const noteBg = Color(0xFFFFF8E6);
  static const noteBorder = Color(0xFFF5DFA3);
  static const reviewBg = Color(0xFFEEF3FF);
  static const reviewBorder = Color(0xFFCFDBFA);
  static const loadBg = Color(0xFFEFF8F0);
  static const loadBorder = Color(0xFFC5E3C8);
}

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
  final String chassisNumber;
  final String loadedShort;
  final String loadedDetail;
  final String parkingYardArea;
  final String parkingYardPincode;
  final String parkingYardPhone;
  final String parkingYardCode;
  final String parkingYardManagerName;
  final String parkingYardManagerPhone;
  final int photosCount;
  final int inventoryImagesCount;
  final int inventoryVideosCount;
  final int inventoryPdfsCount;
  final bool inventoryRevisionRequested;
  final String inventoryRevisionNote;
  final DateTime? confirmedAt;
  final DateTime? inventoryConfirmedAt;

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
    required this.chassisNumber,
    required this.loadedShort,
    required this.loadedDetail,
    required this.parkingYardArea,
    required this.parkingYardPincode,
    required this.parkingYardPhone,
    required this.parkingYardCode,
    required this.parkingYardManagerName,
    required this.parkingYardManagerPhone,
    required this.photosCount,
    required this.inventoryImagesCount,
    required this.inventoryVideosCount,
    required this.inventoryPdfsCount,
    required this.inventoryRevisionRequested,
    required this.inventoryRevisionNote,
    required this.confirmedAt,
    required this.inventoryConfirmedAt,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();
  static num _n(dynamic v) => v is num ? v : num.tryParse(_s(v)) ?? 0;
  static int _len(dynamic v) => v is List ? v.length : 0;
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
    chassisNumber: _s(j['chassisNumber']),
    loadedShort: _s(j['loadedShort']),
    loadedDetail: _s(j['loadedDetail']),
    parkingYardArea: _s(j['parkingYardArea']),
    parkingYardPincode: _s(j['parkingYardPincode']),
    parkingYardPhone: _s(j['parkingYardPhone']),
    parkingYardCode: _s(j['parkingYardCode']),
    parkingYardManagerName: _s(j['parkingYardManagerName']),
    parkingYardManagerPhone: _s(j['parkingYardManagerPhone']),
    photosCount: _len(j['photos']),
    inventoryImagesCount: _len(j['inventoryImages']),
    inventoryVideosCount: _len(j['inventoryVideos']),
    inventoryPdfsCount: _len(j['inventoryPdfs']),
    inventoryRevisionRequested: j['inventoryRevisionRequested'] == true,
    inventoryRevisionNote: _s(j['inventoryRevisionNote']),
    confirmedAt: _d(j['confirmedAt']),
    inventoryConfirmedAt: _d(j['inventoryConfirmedAt']),
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
    chassisNumber,
    loadedShort,
    loadedDetail,
    parkingYardName,
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
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
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
        'Chassis Number',
        'Loaded Short',
        'Loaded Detail',
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
          xl.TextCellValue(
              r.createdAt == null ? '' : _fmt.format(r.createdAt!)),
          xl.TextCellValue(r.reviewedByName),
          xl.TextCellValue(
              r.reviewedAt == null ? '' : _fmt.format(r.reviewedAt!)),
          xl.TextCellValue(r.chassisNumber),
          xl.TextCellValue(r.loadedShort),
          xl.TextCellValue(r.loadedDetail),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _C.text,
        titleSpacing: 0,
        title: const Text(
          'Cancel confirmations',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _C.dangerBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${list.length} cases',
                style: const TextStyle(
                  color: _C.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopBar(),
          const Divider(height: 1, color: _C.border),
          Expanded(child: _buildBody(list)),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _doSearch(),
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Search vehicle, customer, bank, case code…',
                hintStyle: const TextStyle(color: _C.muted, fontSize: 13.5),
                prefixIcon: const Icon(Icons.search, color: _C.muted),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _reset,
                ),
                filled: true,
                fillColor: _C.bg,
                isDense: true,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.primary, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Download Excel',
            child: Material(
              color: _downloading ? Colors.grey.shade400 : _C.green,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _downloading ? null : _downloadExcel,
                child: SizedBox(
                  width: 46,
                  height: 46,
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: _C.dangerBg, shape: BoxShape.circle),
                child: const Icon(Icons.wifi_off_rounded,
                    size: 34, color: _C.danger),
              ),
              const SizedBox(height: 14),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _C.muted)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text('Koi cancel confirmation nahi mila',
                style: TextStyle(color: _C.muted, fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
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

  String _v(String s) => (s.isEmpty || s == '-') ? '—' : s;
  String _dt(DateTime? d) => d == null ? '—' : fmt.format(d);

  @override
  Widget build(BuildContext context) {
    final loadedText = [item.loadedShort, item.loadedDetail]
        .where((e) => e.isNotEmpty)
        .join('\n');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // red accent strip
              Container(width: 4, color: _C.danger),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header: S.No + Registration Number + Status
                      Row(
                        children: [
                          Container(
                            constraints: const BoxConstraints(minWidth: 32),
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _C.bg,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text('$sno',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('REGISTRATION NUMBER'),
                                const SizedBox(height: 1),
                                Text(
                                  _v(item.vehicleNumber),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: _C.text,
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
                              color: _C.dangerBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'CANCEL',
                              style: TextStyle(
                                color: _C.danger,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Customer Name
                      _label('CUSTOMER NAME'),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 18, color: _C.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _v(item.customerName),
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: _C.text),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── Action
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded,
                              size: 17, color: _C.muted),
                          const SizedBox(width: 6),
                          const Text('Action',
                              style:
                              TextStyle(fontSize: 12.5, color: _C.muted)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _C.bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _C.border),
                            ),
                            child: Text(
                              _v(item.finalAction).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _C.text,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── Field Note
                      const SizedBox(height: 12),
                      _noteBox('Field Note', _v(item.requestNote), _C.noteBg,
                          _C.noteBorder, Icons.sticky_note_2_outlined),
                      const SizedBox(height: 8),

                      // ── Loaded Details
                      _noteBox(
                          'Loaded Details',
                          loadedText.isEmpty ? '—' : loadedText,
                          _C.loadBg,
                          _C.loadBorder,
                          Icons.local_shipping_outlined),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: _C.border),
                      const SizedBox(height: 10),

                      // ── Reported At
                      Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 14, color: _C.muted),
                          const SizedBox(width: 6),
                          const Text('Reported At',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: _C.muted)),
                          const Spacer(),
                          Text(
                            _dt(item.createdAt),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _C.text),
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
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: _C.muted,
      ),
    );
  }

  Widget _noteBox(
      String title, String text, Color bg, Color border, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: _C.muted),
              const SizedBox(width: 5),
              Text(title.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: _C.muted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: _C.text)),
        ],
      ),
    );
  }
}