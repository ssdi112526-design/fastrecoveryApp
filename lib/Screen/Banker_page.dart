// pubspec.yaml dependencies:
//   http: ^1.2.2
//   intl: ^0.19.0
//   shared_preferences: ^2.3.2
//
// main() mein runApp se pehle:
//   WidgetsFlutterBinding.ensureInitialized();
//   await SharedPreferenceService.init();

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../Service/SharedPreferenceService.dart';

// NOTE: Is file mein koi hardcoded color nahi hai.
// Sab kuch Theme.of(context) (colorScheme + textTheme) se aa raha hai,
// to tumhare project ka theme apne-aap lag jayega.

// ───────────────────────── Model ─────────────────────────

class BankItem {
  final String bankId;
  final String bankName;
  final String bankCode;
  final String phone;
  final String email;
  final String bankerNames;
  final String bankerPhone;
  final DateTime? linkedAt;
  final String status;

  BankItem({
    required this.bankId,
    required this.bankName,
    required this.bankCode,
    required this.phone,
    required this.email,
    required this.bankerNames,
    required this.bankerPhone,
    required this.linkedAt,
    required this.status,
  });

  factory BankItem.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => v == null ? '' : v.toString();
    return BankItem(
      bankId: s(j['bankId']),
      bankName: s(j['bankName']),
      bankCode: s(j['bankCode']),
      phone: s(j['phone']),
      email: s(j['email']),
      bankerNames: s(j['name']),
      bankerPhone: s(j['bankerPhone']),
      linkedAt: DateTime.tryParse(s(j['linkedAt'])),
      status: s(j['status']),
    );
  }

  /// "9654008500, 8979875238" -> ["9654008500", "8979875238"]
  List<String> get phoneList {
    final raw = bankerPhone.isNotEmpty ? bankerPhone : phone;
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String get displayEmail => email.isNotEmpty ? email : '—';

  bool get isActive => status.toLowerCase() == 'active';

  // "9 Oct 2026, 12:21 pm" (IST)
  String get displayLinkedAt {
    if (linkedAt == null) return '—';
    final ist = linkedAt!.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('d MMM y, h:mm a')
        .format(ist)
        .replaceAll('\u202f', ' ')
        .replaceAll('AM', 'am')
        .replaceAll('PM', 'pm');
  }

  bool matches(String q) {
    final hay = [bankName, bankCode, phone, bankerPhone, email, bankerNames]
        .join(' ')
        .toLowerCase();
    return hay.contains(q.toLowerCase());
  }
}

// ───────────────────────── API service ─────────────────────────

class BankApi {
  static const _url = 'https://fastrecovery.in/api/bank/repo-connected-banks';

  static Future<List<BankItem>> fetchConnectedBanks({
    required String token,
  }) async {
    final res = await http.get(
      Uri.parse(_url),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 20));

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception('Session expired. Please login again.');
    }

    if (res.statusCode != 200 || body['success'] == false) {
      throw Exception(
          (body['message'] as String?) ?? 'Request failed (${res.statusCode})');
    }

    final list = (body['data']?['banks'] as List?) ?? [];
    return list
        .map((e) => BankItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ───────────────────────── Page ─────────────────────────

class BankRepoListPage extends StatefulWidget {
  /// Optional. Na do to SharedPreferenceService se token utha lega.
  final String? token;
  const BankRepoListPage({super.key, this.token});

  @override
  State<BankRepoListPage> createState() => _BankRepoListPageState();
}

class _BankRepoListPageState extends State<BankRepoListPage> {
  final _searchCtrl = TextEditingController();
  List<BankItem> _all = [];
  List<BankItem> _shown = [];
  bool _loading = true;
  String? _error;

  String? get _token => widget.token ?? SharedPreferenceService.getToken();

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

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Token not found. Please login again.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final banks = await BankApi.fetchConnectedBanks(token: token);
      if (!mounted) return;
      setState(() {
        _all = banks;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim();
    setState(() {
      _shown =
      q.isEmpty ? List.of(_all) : _all.where((b) => b.matches(q)).toList();
    });
  }

  void _openBank(BankItem bank) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BankUploadsPage(bank: bank)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(
                children: [
                  if (Navigator.of(context).canPop())
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      iconSize: 20,
                      tooltip: 'Back',
                    ),
                  Expanded(
                    child: Text(
                      'Bank/NBFC Repo List Details',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Bank recovery data from banks linked to your agency '
                    '(same cases as admin; loan and banker contacts are admin-only).',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _buildSearchRow(),
              const SizedBox(height: 14),
              _buildBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchRow() {
    final cs = Theme.of(context).colorScheme;

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => _applyFilter(),
            onSubmitted: (_) => _applyFilter(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search banks…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: cs.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              enabledBorder: border(cs.outlineVariant),
              focusedBorder: border(cs.primary, 1.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 46,
          // Style nahi diya, to tumhare ElevatedButtonTheme se hi aayega
          child: ElevatedButton(
            onPressed: _applyFilter,
            child: const Text('Search'),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 32),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.error),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_shown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'No banks found.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_shown.length} ${_shown.length == 1 ? 'Bank' : 'Banks'}',
          style: tt.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        ..._shown.map(
              (b) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BankCard(bank: b, onTap: () => _openBank(b)),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Bank card ─────────────────────────

class BankCard extends StatelessWidget {
  final BankItem bank;
  final VoidCallback onTap;
  const BankCard({super.key, required this.bank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final valueStyle = tt.bodyMedium?.copyWith(color: cs.onSurface, height: 1.3);

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: icon + name + status
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.account_balance,
                        color: cs.onPrimaryContainer, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      bank.bankName.isEmpty ? '—' : bank.bankName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  _StatusBadge(status: bank.status, active: bank.isActive),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: cs.outlineVariant),
              const SizedBox(height: 14),

              if (bank.bankerNames.isNotEmpty) ...[
                _InfoRow(
                  icon: Icons.people_outline,
                  label: 'Bankers',
                  child: Text(bank.bankerNames, style: valueStyle),
                ),
                const SizedBox(height: 12),
              ],

              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                child: bank.phoneList.isEmpty
                    ? Text('—', style: valueStyle)
                    : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: bank.phoneList
                      .map(
                        (p) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p,
                        style: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),

              _InfoRow(
                icon: Icons.mail_outline,
                label: 'Mail ID',
                child: Text(bank.displayEmail, style: valueStyle),
              ),
              const SizedBox(height: 12),

              _InfoRow(
                icon: Icons.schedule,
                label: 'Linked on',
                child: Text(bank.displayLinkedAt, style: valueStyle),
              ),
              const SizedBox(height: 14),

              // Footer action
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View upload history',
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 18, color: cs.onPrimaryContainer),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _InfoRow(
      {required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool active;
  const _StatusBadge({required this.status, required this.active});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? cs.primaryContainer : cs.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.isEmpty ? '—' : status,
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: active ? cs.onPrimaryContainer : cs.onErrorContainer,
        ),
      ),
    );
  }
}

// ───────────────────────── Upload history (placeholder) ─────────────────────────

class BankUploadsPage extends StatelessWidget {
  final BankItem bank;
  const BankUploadsPage({super.key, required this.bank});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(bank.bankName)),
      body: Center(
        child: Text('Upload history for bankId: ${bank.bankId}'),
      ),
    );
  }
}