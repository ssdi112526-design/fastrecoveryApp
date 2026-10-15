import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';

// =============================================================
// MODELS
// =============================================================

class _ConfirmationItem {
  final String id;
  final String status;
  final String caseCode;
  final String vehicleNumber;
  final String customerName;
  final String bankName;
  final String branchName;
  final String requestedByName;
  final String requestedByRoleLabel;
  final String requestedByPhone;
  final String shareChannel;
  final String traceMode;
  final String requestNote;
  final DateTime? createdAt;

  const _ConfirmationItem({
    required this.id,
    required this.status,
    required this.caseCode,
    required this.vehicleNumber,
    required this.customerName,
    required this.bankName,
    required this.branchName,
    required this.requestedByName,
    required this.requestedByRoleLabel,
    required this.requestedByPhone,
    required this.shareChannel,
    required this.traceMode,
    required this.requestNote,
    required this.createdAt,
  });

  static String _s(dynamic v) => (v ?? '').toString().trim();

  factory _ConfirmationItem.fromJson(Map<String, dynamic> j) {
    return _ConfirmationItem(
      id: _s(j['_id']),
      status: _s(j['status']),
      caseCode: _s(j['caseCode']),
      vehicleNumber: _s(j['vehicleNumber']),
      customerName: _s(j['customerName']),
      bankName: _s(j['bankName']),
      branchName: _s(j['branchName']),
      requestedByName: _s(j['requestedByName']),
      requestedByRoleLabel: _s(j['requestedByRoleLabel']),
      requestedByPhone: _s(j['requestedByPhone']),
      shareChannel: _s(j['shareChannel']).toLowerCase(),
      traceMode: _s(j['traceMode']),
      requestNote: _s(j['requestNote']),
      createdAt: DateTime.tryParse(_s(j['createdAt']))?.toLocal(),
    );
  }
}

class _VehicleGroup {
  final String key;
  final String vehicleNumber;
  final List<_ConfirmationItem> items;

  _VehicleGroup({
    required this.key,
    required this.vehicleNumber,
    required this.items,
  });

  _ConfirmationItem? get first => items.isEmpty ? null : items.first;
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

  // key -> group (insertion order maintain hota hai)
  final Map<String, _VehicleGroup> _groupMap = {};
  final Set<String> _expanded = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = false;
  String? _error;
  int _page = 1;
  int _vehicleTotal = 0;
  int _requestTotal = 0;
  String _query = '';

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
      final prefs = await SharedPreferences.getInstance();
      final token = (prefs.getString('token') ?? '').trim();
      if (token.isEmpty) throw Exception('Session expired');

      final uri = Uri.parse('$_baseUrl/api/confirmations').replace(
        queryParameters: {
          'status': 'PENDING',
          'page': '$_page',
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

      // 1) flat items: id -> item
      final byId = <String, _ConfirmationItem>{};
      final rawData = body['data'];
      if (rawData is List) {
        for (final e in rawData) {
          if (e is Map) {
            final item =
            _ConfirmationItem.fromJson(Map<String, dynamic>.from(e));
            if (item.id.isNotEmpty) byId[item.id] = item;
          }
        }
      }

      // 2) groups (server ne vehicle ke hisaab se diye)
      final newGroups = <String, _VehicleGroup>{};
      final rawGroups = body['groups'];
      if (rawGroups is List && rawGroups.isNotEmpty) {
        for (final g in rawGroups) {
          if (g is! Map) continue;
          final ids = (g['confirmationIds'] is List)
              ? (g['confirmationIds'] as List).map((e) => e.toString())
              : <String>[];
          final items = ids
              .map((id) => byId[id])
              .whereType<_ConfirmationItem>()
              .toList();
          if (items.isEmpty) continue;

          final vehicle = (g['vehicleNumber'] ?? items.first.vehicleNumber)
              .toString();
          final key = (g['vehicleKey'] ?? 'v:$vehicle').toString();
          newGroups[key] = _VehicleGroup(
            key: key,
            vehicleNumber: vehicle,
            items: items,
          );
        }
      } else {
        // fallback: khud vehicle number se group karo
        for (final item in byId.values) {
          final key = 'v:${item.vehicleNumber}';
          newGroups
              .putIfAbsent(
            key,
                () => _VehicleGroup(
              key: key,
              vehicleNumber: item.vehicleNumber,
              items: [],
            ),
          )
              .items
              .add(item);
        }
      }

      final pagination = body['pagination'];
      final hasNext = pagination is Map && pagination['hasNextPage'] == true;

      if (!mounted) return;
      setState(() {
        if (reset) _groupMap.clear();
        newGroups.forEach((key, group) {
          final old = _groupMap[key];
          if (old == null) {
            _groupMap[key] = group;
          } else {
            // doosre page par wahi vehicle aaye to merge
            final ids = old.items.map((e) => e.id).toSet();
            old.items.addAll(group.items.where((e) => !ids.contains(e.id)));
          }
        });

        _vehicleTotal = _toInt(body['vehicleTotal'], _groupMap.length);
        _requestTotal = _toInt(
          body['requestTotal'],
          _groupMap.values.fold<int>(0, (s, g) => s + g.items.length),
        );
        _hasNext = hasNext;
        if (hasNext) _page += 1;
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
        // purana data dikh raha ho to full error screen mat dikhao
        if (_groupMap.isEmpty) {
          _error = e.toString().contains('Session expired')
              ? 'Session expired. Please login again.'
              : 'Unable to load pending confirmations.';
        }
      });
      if (_groupMap.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not refresh. Check your internet.'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    }
  }

  int _toInt(dynamic v, int fallback) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  List<_VehicleGroup> get _filtered {
    final all = _groupMap.values.toList();
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;

    return all.where((g) {
      if (g.vehicleNumber.toLowerCase().contains(q)) return true;
      return g.items.any((i) =>
      i.customerName.toLowerCase().contains(q) ||
          i.caseCode.toLowerCase().contains(q) ||
          i.bankName.toLowerCase().contains(q));
    }).toList();
  }

  // ---------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
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

  IconData _channelIcon(String c) {
    switch (c) {
      case 'whatsapp':
        return Icons.chat_rounded;
      case 'sms':
        return Icons.sms_rounded;
      case 'email':
        return Icons.email_rounded;
      default:
        return Icons.send_rounded;
    }
  }

  Color _channelColor(String c) {
    switch (c) {
      case 'whatsapp':
        return const Color(0xff16A34A);
      case 'sms':
        return const Color(0xff2563EB);
      case 'email':
        return const Color(0xffF59E0B);
      default:
        return const Color(0xff64748B);
    }
  }

  String _channelLabel(String c) {
    if (c.isEmpty) return 'Request';
    if (c == 'sms') return 'SMS';
    return c[0].toUpperCase() + c.substring(1);
  }

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
              const SizedBox(height: 16),
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
                decoration: BoxDecoration(color: backBg, shape: BoxShape.circle),
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
          // IconButton(
          //   onPressed: _loading ? null : () => _load(reset: true),
          //   icon: Icon(Icons.refresh_rounded, color: textColor),
          // ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading && _groupMap.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue600),
        ),
      );
    }

    if (_error != null && _groupMap.isEmpty) {
      return _messageView(
        isDark: isDark,
        icon: Icons.error_outline_rounded,
        title: _error!,
        showRetry: true,
      );
    }

    final groups = _filtered;

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      color: AppColors.blue600,
      backgroundColor: isDark ? const Color(0xff121A2E) : Colors.white,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildSummary(isDark),
          const SizedBox(height: 14),
          _buildSearch(isDark),
          const SizedBox(height: 14),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: _messageView(
                isDark: isDark,
                icon: Icons.inbox_rounded,
                title: _query.isEmpty
                    ? 'No pending confirmations'
                    : 'No result found',
              ),
            )
          else
            ...groups.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildGroupCard(g, isDark),
            )),
          if (_loadingMore)
            const Padding(
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
            ),
        ],
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
  // SUMMARY + SEARCH
  // ---------------------------------------------------------

  Widget _buildSummary(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _summaryTile(
            isDark: isDark,
            icon: Icons.directions_car_rounded,
            label: 'Vehicles',
            value: _vehicleTotal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryTile(
            isDark: isDark,
            icon: Icons.pending_actions_rounded,
            label: 'Requests',
            value: _requestTotal,
          ),
        ),
      ],
    );
  }

  Widget _summaryTile({
    required bool isDark,
    required IconData icon,
    required String label,
    required int value,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xff0F172A);
    final muted = isDark ? const Color(0xff7F8BA4) : const Color(0xff64748B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(isDark),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.blue600.withOpacity(.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.blue600, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xff0F172A);
    final muted = isDark ? const Color(0xff7F8BA4) : const Color(0xff64748B);

    return Container(
      decoration: _cardDecoration(isDark),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        decoration: InputDecoration(
          hintText: 'Search vehicle, customer, case code',
          hintStyle: TextStyle(fontSize: 13, color: muted),
          prefixIcon: Icon(Icons.search_rounded, color: muted),
          suffixIcon: _query.isEmpty
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
    );
  }

  // ---------------------------------------------------------
  // GROUP CARD
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

  Widget _buildGroupCard(_VehicleGroup g, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xff0F172A);
    final muted = isDark ? const Color(0xff7F8BA4) : const Color(0xff64748B);
    final isOpen = _expanded.contains(g.key);
    final first = g.first;

    return Container(
      decoration: _cardDecoration(isDark),
      child: Column(
        children: [
          // ── Header ──
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() {
              isOpen ? _expanded.remove(g.key) : _expanded.add(g.key);
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.blue600.withOpacity(.11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: AppColors.blue600,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.vehicleNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .4,
                            color: textColor,
                          ),
                        ),
                        if (first != null && first.customerName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            first.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ],
                        if (first != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            [first.bankName, first.branchName]
                                .where((e) => e.isNotEmpty && e != '-')
                                .join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xffF59E0B).withOpacity(.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${g.items.length} ${g.items.length == 1 ? 'request' : 'requests'}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xffD97706),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isOpen ? .5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Requests list ──
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  Divider(
                    height: 1,
                    color: isDark
                        ? const Color(0xff24304A)
                        : const Color(0xffE5EAF2),
                  ),
                  const SizedBox(height: 10),
                  ...g.items.map((i) => _buildRequestTile(i, isDark)),
                ],
              ),
            ),
            crossFadeState:
            isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(_ConfirmationItem i, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xff0F172A);
    final muted = isDark ? const Color(0xff7F8BA4) : const Color(0xff64748B);
    final color = _channelColor(i.shareChannel);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(.04)
            : const Color(0xffF8FAFD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_channelIcon(i.shareChannel), color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_channelLabel(i.shareChannel)} request',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xffF59E0B).withOpacity(.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        i.status.isEmpty ? 'PENDING' : i.status,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xffD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _line(Icons.person_rounded,
                    '${i.requestedByName}'
                        '${i.requestedByRoleLabel.isNotEmpty ? ' (${i.requestedByRoleLabel})' : ''}',
                    muted),
                if (i.requestedByPhone.isNotEmpty)
                  _line(Icons.phone_rounded, i.requestedByPhone, muted),
                if (i.caseCode.isNotEmpty)
                  _line(Icons.tag_rounded, i.caseCode, muted),
                _line(Icons.schedule_rounded, _formatDate(i.createdAt), muted),
                if (i.requestNote.isNotEmpty)
                  _line(Icons.notes_rounded, i.requestNote, muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}