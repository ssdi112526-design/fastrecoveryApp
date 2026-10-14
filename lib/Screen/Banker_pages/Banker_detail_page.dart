// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// const String _kBase = 'https://fastrecovery.in/api';
// const Color _kBlue1 = Color(0xFF38B6FF);
// const Color _kBlue2 = Color(0xFF1D3FAE);
//
// /// ---------------------------------------------------------------------------
// /// Models
// /// ---------------------------------------------------------------------------
// class BankInfo {
//   final String bankId, bankName, bankCode, phone, status;
//   final DateTime? linkedAt;
//
//   BankInfo.fromJson(Map<String, dynamic> j)
//       : bankId = '${j['bankId'] ?? ''}',
//         bankName = '${j['bankName'] ?? ''}',
//         bankCode = '${j['bankCode'] ?? ''}',
//         phone = '${j['phone'] ?? ''}',
//         status = '${j['status'] ?? ''}',
//         linkedAt = DateTime.tryParse('${j['linkedAt'] ?? ''}')?.toLocal();
// }
//
// class UploadBatch {
//   final String batchId, fileName, status, errorMessage;
//   final int totalRows, processedRows, successRows, failedRows, duplicateRows;
//   final String uploaderName, uploaderEmail, uploaderPhone, uploaderRole;
//   final DateTime? createdAt, updatedAt;
//   final List<dynamic> failedDetails;
//
//   UploadBatch.fromJson(Map<String, dynamic> j)
//       : batchId = '${j['batchId'] ?? j['_id'] ?? ''}',
//         fileName = '${j['fileName'] ?? ''}',
//         status = '${j['status'] ?? ''}',
//         errorMessage = '${j['errorMessage'] ?? ''}',
//         totalRows = _int(j['totalRows']),
//         processedRows = _int(j['processedRows']),
//         successRows = _int(j['successRows']),
//         failedRows = _int(j['failedRows']),
//         duplicateRows = _int(j['duplicateRows']),
//         failedDetails = (j['failedDetails'] as List?) ?? const [],
//         uploaderName = '${(j['uploadedBy'] ?? {})['name'] ?? ''}',
//         uploaderEmail = '${(j['uploadedBy'] ?? {})['email'] ?? ''}',
//         uploaderPhone = '${(j['uploadedBy'] ?? {})['phone'] ?? ''}',
//         uploaderRole = '${(j['uploadedBy'] ?? {})['role'] ?? ''}',
//         createdAt = DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal(),
//         updatedAt = DateTime.tryParse('${j['updatedAt'] ?? ''}')?.toLocal();
//
//   static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
// }
//
// /// ---------------------------------------------------------------------------
// /// Screen
// /// ---------------------------------------------------------------------------
// class BankerDetailsScreen extends StatefulWidget {
//   final String bankId;
//   final String? bankName;
//
//   const BankerDetailsScreen({super.key, required this.bankId, this.bankName});
//
//   @override
//   State<BankerDetailsScreen> createState() => _BankerDetailsScreenState();
// }
//
// class _BankerDetailsScreenState extends State<BankerDetailsScreen> {
//   static const int _limit = 20;
//
//   final _scroll = ScrollController();
//   final _searchCtrl = TextEditingController();
//
//   BankInfo? _bank;
//   final List<UploadBatch> _batches = [];
//   int _page = 1;
//   int _total = 0;
//   bool _hasNext = false;
//   bool _loading = true;
//   bool _loadingMore = false;
//   String? _error;
//   String _query = '';
//
//   @override
//   void initState() {
//     super.initState();
//     _scroll.addListener(() {
//       if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
//         _loadMore();
//       }
//     });
//     _load();
//   }
//
//   @override
//   void dispose() {
//     _scroll.dispose();
//     _searchCtrl.dispose();
//     super.dispose();
//   }
//
//   Future<Map<String, dynamic>> _fetch(int page) async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('token') ?? '';
//     final uri = Uri.parse('$_kBase/bank/repo-uploads').replace(queryParameters: {
//       'bankId': widget.bankId,
//       'page': '$page',
//       'limit': '$_limit',
//     });
//     final res = await http.get(uri, headers: {
//       'Accept': 'application/json',
//       'Authorization': 'Bearer $token',
//     });
//     final body = jsonDecode(res.body) as Map<String, dynamic>;
//     if (res.statusCode != 200 || body['success'] != true) {
//       throw Exception(body['message'] ?? 'Failed (${res.statusCode})');
//     }
//     return body['data'] as Map<String, dynamic>;
//   }
//
//   Future<void> _load() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//     try {
//       final data = await _fetch(1);
//       final list = (data['batches'] as List? ?? [])
//           .map((e) => UploadBatch.fromJson(e as Map<String, dynamic>))
//           .toList();
//       final pg = (data['pagination'] ?? {}) as Map<String, dynamic>;
//       if (!mounted) return;
//       setState(() {
//         _bank = data['bank'] == null
//             ? null
//             : BankInfo.fromJson(data['bank'] as Map<String, dynamic>);
//         _batches
//           ..clear()
//           ..addAll(list);
//         _page = 1;
//         _total = (pg['total'] ?? data['total'] ?? list.length) as int;
//         _hasNext = pg['hasNextPage'] == true;
//         _loading = false;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _error = e.toString().replaceFirst('Exception: ', '');
//         _loading = false;
//       });
//     }
//   }
//
//   Future<void> _loadMore() async {
//     if (_loadingMore || !_hasNext || _loading) return;
//     setState(() => _loadingMore = true);
//     try {
//       final data = await _fetch(_page + 1);
//       final list = (data['batches'] as List? ?? [])
//           .map((e) => UploadBatch.fromJson(e as Map<String, dynamic>))
//           .toList();
//       final pg = (data['pagination'] ?? {}) as Map<String, dynamic>;
//       if (!mounted) return;
//       setState(() {
//         _batches.addAll(list);
//         _page += 1;
//         _hasNext = pg['hasNextPage'] == true;
//         _loadingMore = false;
//       });
//     } catch (_) {
//       if (mounted) setState(() => _loadingMore = false);
//     }
//   }
//
//   List<UploadBatch> get _filtered {
//     final q = _query.trim().toLowerCase();
//     if (q.isEmpty) return _batches;
//     return _batches.where((b) => b.fileName.toLowerCase().contains(q)).toList();
//   }
//
//   /// Unique uploader phones, shown under the bank name (like the web header).
//   String get _phonesLine {
//     final set = <String>{
//       if ((_bank?.phone ?? '').isNotEmpty) _bank!.phone,
//       ..._batches.map((b) => b.uploaderPhone).where((p) => p.isNotEmpty),
//     };
//     return set.join(', ');
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final bg = isDark ? const Color(0xFF0F1420) : const Color(0xFFF4F6FB);
//     final card = isDark ? const Color(0xFF1A2130) : Colors.white;
//     final text = isDark ? Colors.white : const Color(0xFF111827);
//     final sub = isDark ? Colors.white60 : const Color(0xFF6B7280);
//     final border = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
//
//     final items = _filtered;
//
//     return Scaffold(
//       backgroundColor: bg,
//       body: SafeArea(
//         child: RefreshIndicator(
//           onRefresh: _load,
//           child: ListView(
//             controller: _scroll,
//             physics: const AlwaysScrollableScrollPhysics(),
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
//             children: [
//               // Back + title
//               Row(
//                 children: [
//                   InkWell(
//                     onTap: () => Navigator.maybePop(context),
//                     borderRadius: BorderRadius.circular(12),
//                     child: Container(
//                       padding: const EdgeInsets.all(10),
//                       decoration: BoxDecoration(
//                         color: card,
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: border),
//                       ),
//                       child: Icon(Icons.arrow_back_rounded, color: text, size: 20),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Text('Banker Details',
//                         style: TextStyle(
//                             color: text, fontSize: 20, fontWeight: FontWeight.w700)),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 14),
//
//               _headerCard(),
//               const SizedBox(height: 14),
//
//               // Search
//               TextField(
//                 controller: _searchCtrl,
//                 onChanged: (v) => setState(() => _query = v),
//                 style: TextStyle(color: text),
//                 decoration: InputDecoration(
//                   hintText: 'Search file name…',
//                   hintStyle: TextStyle(color: sub),
//                   prefixIcon: Icon(Icons.search_rounded, color: sub),
//                   suffixIcon: _query.isEmpty
//                       ? null
//                       : IconButton(
//                     icon: Icon(Icons.close_rounded, color: sub),
//                     onPressed: () {
//                       _searchCtrl.clear();
//                       setState(() => _query = '');
//                     },
//                   ),
//                   filled: true,
//                   fillColor: card,
//                   contentPadding: const EdgeInsets.symmetric(vertical: 14),
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(14),
//                       borderSide: BorderSide(color: border)),
//                   enabledBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(14),
//                       borderSide: BorderSide(color: border)),
//                   focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(14),
//                       borderSide: const BorderSide(color: _kBlue2, width: 1.4)),
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Text('$_total Uploads',
//                   style: TextStyle(
//                       color: sub, fontSize: 12, fontWeight: FontWeight.w600)),
//               const SizedBox(height: 10),
//
//               if (_loading)
//                 const Padding(
//                   padding: EdgeInsets.symmetric(vertical: 60),
//                   child: Center(child: CircularProgressIndicator()),
//                 )
//               else if (_error != null)
//                 _errorBox(card, border, text, sub)
//               else if (items.isEmpty)
//                   Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 60),
//                     child: Center(
//                       child: Text('No uploads found', style: TextStyle(color: sub)),
//                     ),
//                   )
//                 else
//                   ...items.map((b) => _batchCard(b, isDark, card, text, sub, border)),
//
//               if (_loadingMore)
//                 const Padding(
//                   padding: EdgeInsets.all(16),
//                   child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ------------------------------------------------------------------ header
//   Widget _headerCard() {
//     final name = (_bank?.bankName.isNotEmpty ?? false)
//         ? _bank!.bankName
//         : (widget.bankName ?? 'Bank');
//     final phones = _phonesLine;
//
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [_kBlue1, _kBlue2],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(18),
//         boxShadow: [
//           BoxShadow(
//               color: _kBlue2.withOpacity(0.25),
//               blurRadius: 16,
//               offset: const Offset(0, 6)),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.18),
//               borderRadius: BorderRadius.circular(14),
//             ),
//             child: const Icon(Icons.account_balance_rounded,
//                 color: Colors.white, size: 26),
//           ),
//           const SizedBox(width: 14),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(name,
//                     style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.w700)),
//                 const SizedBox(height: 4),
//                 Text(
//                   phones.isEmpty ? 'Upload history' : 'Upload history · $phones',
//                   style: TextStyle(
//                       color: Colors.white.withOpacity(0.85), fontSize: 12),
//                 ),
//                 if (_bank?.linkedAt != null) ...[
//                   const SizedBox(height: 2),
//                   Text('Linked ${_fmt(_bank!.linkedAt)}',
//                       style: TextStyle(
//                           color: Colors.white.withOpacity(0.75), fontSize: 11)),
//                 ],
//               ],
//             ),
//           ),
//           if ((_bank?.status ?? '').isNotEmpty)
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Text(_bank!.status,
//                   style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 11,
//                       fontWeight: FontWeight.w600)),
//             ),
//         ],
//       ),
//     );
//   }
//
//   // -------------------------------------------------------------- batch card
//   Widget _batchCard(UploadBatch b, bool isDark, Color card, Color text, Color sub,
//       Color border) {
//     final sc = _statusColor(b.status);
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: InkWell(
//         onTap: () => _showDetails(b),
//         borderRadius: BorderRadius.circular(16),
//         child: Container(
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: card,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: border),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // file + status
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF1E6B3A).withOpacity(0.12),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: const Icon(Icons.table_chart_rounded,
//                         color: Color(0xFF1E6B3A), size: 20),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(b.fileName,
//                             maxLines: 2,
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(
//                                 color: text,
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w700)),
//                         const SizedBox(height: 2),
//                         Text('Batch #${b.batchId}',
//                             style: TextStyle(color: sub, fontSize: 12)),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   _chip(_cap(b.status), sc),
//                 ],
//               ),
//               const SizedBox(height: 12),
//
//               // uploaded by
//               Row(
//                 children: [
//                   CircleAvatar(
//                     radius: 16,
//                     backgroundColor: _kBlue2.withOpacity(0.12),
//                     child: Text(
//                       b.uploaderName.isEmpty ? '?' : b.uploaderName[0].toUpperCase(),
//                       style: const TextStyle(
//                           color: _kBlue2, fontWeight: FontWeight.w700),
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(b.uploaderName,
//                             style: TextStyle(
//                                 color: text,
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.w600)),
//                         Text(_role(b.uploaderRole),
//                             style: TextStyle(color: sub, fontSize: 11)),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 10),
//               _iconLine(Icons.phone_rounded, b.uploaderPhone, sub, text),
//               const SizedBox(height: 4),
//               _iconLine(Icons.mail_outline_rounded, b.uploaderEmail, sub, text),
//               const SizedBox(height: 4),
//               _iconLine(Icons.schedule_rounded, _fmt(b.createdAt), sub, text),
//               const SizedBox(height: 12),
//
//               // stats
//               Row(
//                 children: [
//                   _stat('Total', b.totalRows, _kBlue2, isDark),
//                   const SizedBox(width: 8),
//                   _stat('Success', b.successRows, const Color(0xFF16A34A), isDark),
//                   const SizedBox(width: 8),
//                   _stat('Failed', b.failedRows, const Color(0xFFDC2626), isDark),
//                   const SizedBox(width: 8),
//                   _stat('Dupes', b.duplicateRows, const Color(0xFFD97706), isDark),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _iconLine(IconData icon, String value, Color sub, Color text) {
//     return Row(
//       children: [
//         Icon(icon, size: 14, color: sub),
//         const SizedBox(width: 8),
//         Expanded(
//           child: Text(value.isEmpty ? '—' : value,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(color: text, fontSize: 12.5)),
//         ),
//       ],
//     );
//   }
//
//   Widget _stat(String label, int value, Color color, bool isDark) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 8),
//         decoration: BoxDecoration(
//           color: color.withOpacity(isDark ? 0.18 : 0.09),
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Column(
//           children: [
//             Text('$value',
//                 style: TextStyle(
//                     color: color, fontSize: 15, fontWeight: FontWeight.w800)),
//             const SizedBox(height: 2),
//             Text(label,
//                 style: TextStyle(
//                     color: color.withOpacity(0.85),
//                     fontSize: 10.5,
//                     fontWeight: FontWeight.w600)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _chip(String label, Color color) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.14),
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Text(label,
//           style: TextStyle(
//               color: color, fontSize: 11, fontWeight: FontWeight.w700)),
//     );
//   }
//
//   Widget _errorBox(Color card, Color border, Color text, Color sub) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: card,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: border),
//       ),
//       child: Column(
//         children: [
//           const Icon(Icons.error_outline_rounded,
//               color: Color(0xFFDC2626), size: 32),
//           const SizedBox(height: 8),
//           Text(_error ?? 'Something went wrong',
//               textAlign: TextAlign.center, style: TextStyle(color: text)),
//           const SizedBox(height: 12),
//           FilledButton.icon(
//             onPressed: _load,
//             icon: const Icon(Icons.refresh_rounded),
//             label: const Text('Retry'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ----------------------------------------------------------- detail sheet
//   void _showDetails(UploadBatch b) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final card = isDark ? const Color(0xFF1A2130) : Colors.white;
//     final text = isDark ? Colors.white : const Color(0xFF111827);
//     final sub = isDark ? Colors.white60 : const Color(0xFF6B7280);
//
//     final rows = <MapEntry<String, String>>[
//       MapEntry('Bank Name', _bank?.bankName ?? widget.bankName ?? ''),
//       MapEntry('Upload Date & Time', _fmt(b.createdAt)),
//       MapEntry('Completion Time', _fmt(b.updatedAt)),
//       MapEntry('Uploaded By', '${b.uploaderName} — ${_role(b.uploaderRole)}'),
//       MapEntry('Phone', b.uploaderPhone),
//       MapEntry('Mail ID', b.uploaderEmail),
//       MapEntry('Original File Name', b.fileName),
//       MapEntry('Batch ID', '#${b.batchId}'),
//       MapEntry('Total Rows', '${b.totalRows}'),
//       MapEntry('Processed Rows', '${b.processedRows}'),
//       MapEntry('Success Rows', '${b.successRows}'),
//       MapEntry('Failed Rows', '${b.failedRows}'),
//       MapEntry('Duplicates', '${b.duplicateRows}'),
//       MapEntry('Processing Status', _cap(b.status)),
//       MapEntry(
//           'Error Information',
//           b.errorMessage.isNotEmpty
//               ? b.errorMessage
//               : (b.failedDetails.isNotEmpty
//               ? '${b.failedDetails.length} failed row(s)'
//               : 'No errors')),
//     ];
//
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: card,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       builder: (_) => DraggableScrollableSheet(
//         expand: false,
//         initialChildSize: 0.8,
//         minChildSize: 0.5,
//         maxChildSize: 0.95,
//         builder: (ctx, sc) => ListView(
//           controller: sc,
//           padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
//           children: [
//             Center(
//               child: Container(
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: sub.withOpacity(0.4),
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 14),
//             Text('Upload Details',
//                 style: TextStyle(
//                     color: text, fontSize: 18, fontWeight: FontWeight.w800)),
//             const SizedBox(height: 12),
//             ...rows.map((r) => InkWell(
//               onLongPress: () {
//                 Clipboard.setData(ClipboardData(text: r.value));
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('${r.key} copied')),
//                 );
//               },
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 9),
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     SizedBox(
//                       width: 130,
//                       child: Text(r.key,
//                           style: TextStyle(
//                               color: sub,
//                               fontSize: 12.5,
//                               fontWeight: FontWeight.w600)),
//                     ),
//                     Expanded(
//                       child: Text(r.value.isEmpty ? '—' : r.value,
//                           style: TextStyle(
//                               color: text,
//                               fontSize: 13.5,
//                               fontWeight: FontWeight.w600)),
//                     ),
//                   ],
//                 ),
//               ),
//             )),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ----------------------------------------------------------------- helpers
//   Color _statusColor(String s) {
//     switch (s.toLowerCase()) {
//       case 'completed':
//         return const Color(0xFF16A34A);
//       case 'failed':
//         return const Color(0xFFDC2626);
//       default:
//         return const Color(0xFFD97706);
//     }
//   }
//
//   String _cap(String s) =>
//       s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1).toLowerCase();
//
//   String _role(String r) => r
//       .split('_')
//       .where((w) => w.isNotEmpty)
//       .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
//       .join(' ');
//
//   String _fmt(DateTime? d) {
//     if (d == null) return '—';
//     const m = [
//       'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
//       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
//     ];
//     final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
//     final ap = d.hour >= 12 ? 'PM' : 'AM';
//     final mm = d.minute.toString().padLeft(2, '0');
//     return '${d.day} ${m[d.month - 1]} ${d.year}, $h12:$mm $ap';
//   }
// }