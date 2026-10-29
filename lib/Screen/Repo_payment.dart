import 'dart:convert';
// `dart:ffi` import removed — not needed, can break Android builds.
import 'package:fastrecovery/Service/SharedPreferenceService.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const String kAgentBillsUrl = 'https://fastrecovery.in/api/agent-bills/me';

final NumberFormat _inr =
NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

num _n(dynamic v) => v is num ? v : num.tryParse('${v ?? 0}') ?? 0;

// ───────────────────────── Models ─────────────────────────

class AgentInfo {
  final String id, name, email, role, phone;
  AgentInfo.fromJson(Map<String, dynamic> j)
      : id = '${j['_id'] ?? ''}',
        name = '${j['name'] ?? ''}',
        email = '${j['email'] ?? ''}',
        role = '${j['role'] ?? ''}',
        phone = '${j['phone'] ?? ''}';
}

class BillTotals {
  final num seizedVehicles, repoPayable, otherPayable, totalPayable;
  final num repoPaid, otherPaid, extraPaid, extraApplied, paid;
  final num unpaid, repoUnpaid, otherUnpaid;
  BillTotals.fromJson(Map<String, dynamic> j)
      : seizedVehicles = _n(j['seizedVehicles']),
        repoPayable = _n(j['repoPayable']),
        otherPayable = _n(j['otherPayable']),
        totalPayable = _n(j['totalPayable']),
        repoPaid = _n(j['repoPaid']),
        otherPaid = _n(j['otherPaid']),
        extraPaid = _n(j['extraPaid']),
        extraApplied = _n(j['extraApplied']),
        paid = _n(j['paid']),
        unpaid = _n(j['unpaid']),
        repoUnpaid = _n(j['repoUnpaid']),
        otherUnpaid = _n(j['otherUnpaid']);

  num get advanceBalance => extraPaid - extraApplied;
}

class PaymentItem {
  final String id, type, mode, reference, remarks, createdByName;
  final num amount;
  final DateTime? date;
  PaymentItem.fromJson(Map<String, dynamic> j)
      : id = '${j['_id'] ?? ''}',
        type = '${j['paymentType'] ?? ''}',
        mode = '${j['paymentMode'] ?? ''}',
        reference = '${j['reference'] ?? ''}',
        remarks = '${j['remarks'] ?? ''}',
        createdByName = '${j['createdByName'] ?? ''}',
        amount = _n(j['amount']),
        date = DateTime.tryParse('${j['paymentDate'] ?? ''}')?.toLocal();

  String get typeLabel {
    switch (type) {
      case 'ADVANCE':
        return 'Extra Paid / Advance';
      case 'REPO':
        return 'Repo Payment';
      default:
        return type
            .split('_')
            .map((w) => w.isEmpty
            ? w
            : w[0].toUpperCase() + w.substring(1).toLowerCase())
            .join(' ');
    }
  }

  String get modeLabel {
    if (mode.isEmpty) return '—';
    if (mode.length <= 4) return mode; // UPI, NEFT, IMPS, RTGS
    return mode[0] + mode.substring(1).toLowerCase().replaceAll('_', ' ');
  }
}

class AgentBill {
  final AgentInfo agent;
  final BillTotals totals;
  final List<Map<String, dynamic>> vehicles;
  final List<PaymentItem> payments;

  AgentBill.fromJson(Map<String, dynamic> j)
      : agent = AgentInfo.fromJson(Map<String, dynamic>.from(j['agent'] ?? {})),
        totals =
        BillTotals.fromJson(Map<String, dynamic>.from(j['totals'] ?? {})),
        vehicles = (j['vehicles'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        payments = (j['payments'] as List? ?? [])
            .map((e) => PaymentItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
}

// ───────────────────────── API ─────────────────────────

Future<AgentBill> fetchAgentBill(String? token) async {
  final res = await http.get(
    Uri.parse(kAgentBillsUrl),
    headers: {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    },
  ).timeout(const Duration(seconds: 20));

  if (res.statusCode == 401 || res.statusCode == 403) {
    throw Exception('Session expired. Please log in again.');
  }
  if (res.statusCode != 200) {
    throw Exception('Server error (${res.statusCode})');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['message']?.toString() ?? 'Request failed');
  }
  return AgentBill.fromJson(Map<String, dynamic>.from(body['data']));
}

// ───────────────────────── Theme helpers ─────────────────────────
// Everything below reads from Theme.of(context), so it automatically follows
// the app's light / dark theme. Only the "paid / unpaid" semantic colours are
// tuned per brightness for readability.

extension _Tx on BuildContext {
  ThemeData get th => Theme.of(this);
  ColorScheme get cs => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get okColor => isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
  Color get badColor => isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828);
  Color get tealColor => isDark ? const Color(0xFF4DB6AC) : const Color(0xFF00796B);
  Color get mutedText => cs.onSurface.withOpacity(0.62);
  Color get cardBorder => cs.onSurface.withOpacity(isDark ? 0.12 : 0.08);
}

BoxDecoration _cardDeco(BuildContext c, {Color? tint}) => BoxDecoration(
  color: c.th.cardColor,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: tint?.withOpacity(0.30) ?? c.cardBorder),
  boxShadow: c.isDark
      ? null
      : [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ],
);

// ───────────────────────── Page ─────────────────────────

class RepoPaymentPage extends StatefulWidget {
  final String? token;
  const RepoPaymentPage({super.key, this.token});

  @override
  State<RepoPaymentPage> createState() => _RepoPaymentPageState();
}

class _RepoPaymentPageState extends State<RepoPaymentPage> {
  late Future<AgentBill> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AgentBill> _load() async =>
      fetchAgentBill(await SharedPreferenceService.getToken());

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No hard-coded background / appbar colours: inherits your app theme.
      appBar: AppBar(
        title: const Text('Repo Payments'),
        centerTitle: true,
      ),
      body: FutureBuilder<AgentBill>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _refresh,
            );
          }
          final bill = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _AgentCard(agent: bill.agent),
                const SizedBox(height: 14),
                Text(
                  'Your seized vehicle payables and payments recorded by admin. View only.',
                  style: TextStyle(
                      fontSize: 12.5, height: 1.35, color: context.mutedText),
                ),
                const SizedBox(height: 14),
                _StatGrid(t: bill.totals),
                const SizedBox(height: 12),
                _BreakdownCard(t: bill.totals),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Seized Vehicles',
                  count: bill.vehicles.length,
                ),
                if (bill.vehicles.isEmpty)
                  const _EmptyState(
                    icon: Icons.directions_car_outlined,
                    text: 'No seized vehicles found',
                  )
                else
                  ...bill.vehicles.map((v) => _VehicleCard(v: v)),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Payment History',
                  count: bill.payments.length,
                ),
                if (bill.payments.isEmpty)
                  const _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    text: 'No payments recorded',
                  )
                else
                  ...bill.payments.map((p) => _PaymentCard(p: p)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Agent card ─────────────────────────

class _AgentCard extends StatelessWidget {
  final AgentInfo agent;
  const _AgentCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(context),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: cs.primary.withOpacity(0.14),
            child: Text(
              agent.name.isNotEmpty ? agent.name[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cs.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agent.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.phone_outlined,
                        size: 14, color: context.mutedText),
                    const SizedBox(width: 4),
                    Text(agent.phone,
                        style: TextStyle(
                            fontSize: 13, color: context.mutedText)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              agent.role.replaceAll('_', ' '),
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Stat tiles ─────────────────────────

class _StatGrid extends StatelessWidget {
  final BillTotals t;
  const _StatGrid({required this.t});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatData(Icons.account_balance_wallet_outlined, 'Total Payment',
          _inr.format(t.totalPayable), 'Repo + other payable', context.cs.primary),
      _StatData(Icons.check_circle_outline, 'Paid',
          _inr.format(t.paid), 'Amount already paid', context.okColor),
      _StatData(Icons.hourglass_bottom_rounded, 'Unpaid',
          _inr.format(t.unpaid), 'Remaining balance', context.badColor),
      _StatData(Icons.add_circle_outline, 'Extra / Advance',
          _inr.format(t.extraPaid), 'Adjusted against future vehicles',
          context.tealColor),
    ];
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children:
        items.map((e) => SizedBox(width: w, child: _StatTile(e))).toList(),
      );
    });
  }
}

class _StatData {
  final IconData icon;
  final String label, value, hint;
  final Color color;
  _StatData(this.icon, this.label, this.value, this.hint, this.color);
}

class _StatTile extends StatelessWidget {
  final _StatData d;
  const _StatTile(this.d);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(context, tint: d.color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: d.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(d.icon, size: 18, color: d.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(d.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(d.value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: d.color)),
          ),
          const SizedBox(height: 4),
          Text(d.hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: context.mutedText)),
        ],
      ),
    );
  }
}

// ───────────────────────── Breakdown (collapsible) ─────────────────────────

class _BreakdownCard extends StatelessWidget {
  final BillTotals t;
  const _BreakdownCard({required this.t});

  @override
  Widget build(BuildContext context) {
    Widget row(String l, String v, {bool bold = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(l,
                    style: TextStyle(
                        fontSize: 13,
                        color: bold ? null : context.mutedText,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
              ),
              Text(v,
                  style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
            ],
          ),
        );

    Widget group(String title) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
              color: context.cs.primary)),
    );

    return Container(
      decoration: _cardDeco(context),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: context.th.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Icon(Icons.analytics_outlined, color: context.cs.primary),
          title: const Text('Detailed breakdown',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: Text('${t.seizedVehicles} seized vehicles',
              style: TextStyle(fontSize: 11.5, color: context.mutedText)),
          children: [
            group('Repo'),
            row('Payable', _inr.format(t.repoPayable)),
            row('Paid', _inr.format(t.repoPaid), color: context.okColor),
            row('Unpaid', _inr.format(t.repoUnpaid), color: context.badColor),
            group('Other'),
            row('Payable', _inr.format(t.otherPayable)),
            row('Paid', _inr.format(t.otherPaid), color: context.okColor),
            row('Unpaid', _inr.format(t.otherUnpaid), color: context.badColor),
            group('Advance'),
            row('Extra paid', _inr.format(t.extraPaid)),
            row('Applied', _inr.format(t.extraApplied)),
            const Divider(height: 18),
            row('Advance balance', _inr.format(t.advanceBalance), bold: true),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Section header / empty ─────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 2),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: context.cs.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: context.cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: context.cs.primary)),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 30),
    decoration: _cardDeco(context),
    child: Column(
      children: [
        Icon(icon, size: 36, color: context.mutedText),
        const SizedBox(height: 8),
        Text(text, style: TextStyle(color: context.mutedText)),
      ],
    ),
  );
}

// ───────────────────────── Vehicle card ─────────────────────────
// Vehicle keys are best guesses; adjust once a real vehicle object is seen.

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> v;
  const _VehicleCard({required this.v});

  String _pick(List<String> keys) {
    for (final k in keys) {
      final val = v[k];
      if (val != null && '$val'.isNotEmpty) return '$val';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final reg = _pick(['registrationNo', 'regNo', 'vehicleNo', 'vehicleNumber']);
    final customer = _pick(['customerName', 'customer', 'borrowerName']);
    final payable = _n(v['totalPayable'] ?? v['payable'] ?? v['amount']);
    final paid = _n(v['paid']);
    final unpaid = _n(v['unpaid']);
    final extra = _n(v['extra'] ?? v['extraPaid'] ?? v['advance']);
    final settled = unpaid <= 0;
    final sc = settled ? context.okColor : context.badColor;

    Widget cell(String l, num val, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l,
              style: TextStyle(fontSize: 10.5, color: context.mutedText)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_inr.format(val),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color)),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(context),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: context.cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_car_filled_outlined,
                    size: 20, color: context.cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reg,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    Text(customer,
                        style: TextStyle(
                            fontSize: 12, color: context.mutedText)),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(settled ? 'SETTLED' : 'PENDING',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: sc)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: context.cardBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              cell('Total Payable', payable),
              cell('Paid', paid, color: context.okColor),
              cell('Unpaid', unpaid, color: context.badColor),
              cell('Extra', extra),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Payment card ─────────────────────────

class _PaymentCard extends StatelessWidget {
  final PaymentItem p;
  const _PaymentCard({required this.p});

  Color _typeColor(BuildContext c) {
    switch (p.type) {
      case 'ADVANCE':
        return c.tealColor;
      case 'REPO':
        return c.cs.primary;
      default:
        return c.cs.secondary;
    }
  }

  IconData get _modeIcon {
    switch (p.mode) {
      case 'CASH':
        return Icons.payments_outlined;
      case 'UPI':
        return Icons.qr_code_2;
      case 'CHEQUE':
        return Icons.receipt_long_outlined;
      default:
        return Icons.account_balance_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(context);
    final dateStr =
    p.date != null ? DateFormat('dd MMM yyyy').format(p.date!) : '—';

    Widget meta(IconData i, String t) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 13, color: context.mutedText),
          const SizedBox(width: 5),
          Expanded(
            child: Text(t,
                style: TextStyle(fontSize: 12, color: context.mutedText)),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_modeIcon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.typeLabel,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                meta(Icons.calendar_today_outlined,
                    '$dateStr  ·  ${p.modeLabel}'),
                if (p.reference.isNotEmpty)
                  meta(Icons.tag, 'Ref: ${p.reference}'),
                if (p.remarks.isNotEmpty)
                  meta(Icons.notes_outlined, p.remarks),
                if (p.createdByName.isNotEmpty)
                  meta(Icons.person_outline, 'Recorded by ${p.createdByName}'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_inr.format(p.amount),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.okColor)),
        ],
      ),
    );
  }
}

// ───────────────────────── Error view ─────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.badColor),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}