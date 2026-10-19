import 'package:flutter/material.dart';
import '../Service/Offline_sync_service.dart';
import '../theme/app_theme.dart';

String _fmt(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
);

String _ago(DateTime? t) {
  if (t == null) return 'never';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hr ago';
  return '${d.inDays} day ago';
}

/// Home screen par dikhne wala sync status card.
/// - Pehle sync ke dauran progress dikhata hai.
/// - Sync complete hone par "Sync Complete" popup aata hai; OK dabane ke baad
///   card hamesha ke liye hide. Baad ke incremental syncs silent hain.
class OfflineSyncCard extends StatefulWidget {
  const OfflineSyncCard({super.key});

  @override
  State<OfflineSyncCard> createState() => _OfflineSyncCardState();
}

class _OfflineSyncCardState extends State<OfflineSyncCard> {
  final svc = OfflineSyncService.instance;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    svc.addListener(_checkPopup);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPopup());
  }

  @override
  void dispose() {
    svc.removeListener(_checkPopup);
    super.dispose();
  }

  void _checkPopup() {
    if (!mounted || _dialogOpen || !svc.showDonePopup) return;
    _dialogOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _dialogOpen = false;
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.cloud_done_rounded,
            color: Color(0xff059669),
            size: 44,
          ),
          title: const Text('Sync Complete'),
          content: Text(
            'All data has been downloaded (${_fmt(svc.localCount)} records). '
                'You can now search even without internet.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _dialogOpen = false;
      svc.acknowledgeDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: svc,
      builder: (context, _) {
        // Online mode mein ya sync complete hone par card hide
        if (!svc.useOffline || svc.status == SyncStatus.completed) {
          return const SizedBox.shrink();
        }

        final bg = isDark ? const Color(0xff111827) : Colors.white;
        final border =
        isDark ? const Color(0xff334155) : const Color(0xffE5EAF2);
        final titleC = isDark ? Colors.white : const Color(0xff0F172A);
        final mutedC =
        isDark ? const Color(0xff8A97B0) : const Color(0xff64748B);

        late final IconData icon;
        late final Color accent;
        late final String subtitle;

        switch (svc.status) {
          case SyncStatus.syncing:
            icon = Icons.cloud_sync_rounded;
            accent = AppColors.blue600;
            subtitle = 'Downloading records…';
            break;
          case SyncStatus.completed:
            icon = Icons.cloud_done_rounded;
            accent = const Color(0xff059669);
            subtitle = 'Ready for offline search • ${_ago(svc.lastSyncedAt)}';
            break;
          case SyncStatus.paused:
            icon = Icons.cloud_off_rounded;
            accent = const Color(0xffF59E0B);
            subtitle = svc.isOnline
                ? 'Sync paused'
                : 'Waiting for internet — will resume automatically';
            break;
          case SyncStatus.error:
            icon = Icons.sync_problem_rounded;
            accent = Colors.redAccent;
            subtitle =
            '${svc.error ?? 'Sync failed'} • switch Online → Offline to retry';
            break;
          case SyncStatus.idle:
            icon = Icons.cloud_download_rounded;
            accent = AppColors.blue600;
            subtitle = 'Preparing download…';
            break;
        }

        final showProgress = svc.status == SyncStatus.syncing ||
            (svc.status == SyncStatus.paused && svc.hasData);

        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? .24 : .045),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(.11),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Syncing Data',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: titleC,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: mutedC),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showProgress) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: svc.progress,
                    minHeight: 6,
                    backgroundColor: accent.withOpacity(.12),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  svc.totalEstimate > 0
                      ? '${_fmt(svc.localCount)} / ${_fmt(svc.totalEstimate)} records'
                      : '${_fmt(svc.localCount)} records saved',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: mutedC,
                  ),
                ),
              ] else if (svc.hasData) ...[
                const SizedBox(height: 12),
                Text(
                  '${_fmt(svc.localCount)} records saved on this device',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: mutedC,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Internet na ho to header ke neeche chhota banner.
// class OfflineBanner extends StatelessWidget {
//   const OfflineBanner({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final svc = OfflineSyncService.instance;
//     return AnimatedBuilder(
//       animation: svc,
//       builder: (context, _) {
//         if (!svc.useOffline) return const SizedBox.shrink();
//         return Container(
//           width: double.infinity,
//           margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
//           decoration: BoxDecoration(
//             color: const Color(0xffF59E0B).withOpacity(.14),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: const Color(0xffF59E0B).withOpacity(.4)),
//           ),
//           child: Row(
//             children: [
//               const Icon(Icons.wifi_off_rounded,
//                   size: 16, color: Color(0xffF59E0B)),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   !svc.hasData
//                       ? 'Offline — no saved data yet'
//                       : svc.isOnline
//                       ? 'Offline mode ON — searching saved data'
//                       : 'No internet — searching saved data',
//                   style: const TextStyle(
//                     fontSize: 11.5,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xffF59E0B),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

/// Chhota Online / Offline switch.
/// Solid (white / dark) container mein hai, isliye blue header ya kisi bhi
/// background par colors saaf dikhte hain.
class OfflineModeToggle extends StatelessWidget {
  const OfflineModeToggle({super.key});

  static const _green = Color(0xff059669);
  static const _amber = Color(0xffF59E0B);

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(msg),
      ));
  }

  void _onTap(BuildContext context, OfflineSyncService svc, bool offline) {
    if (offline) {
      // Online par jao
      if (!svc.isOnline) {
        _toast(context, 'No internet connection');
        return;
      }
      svc.setOfflineMode(false);
      return;
    }

    // Offline par jao: net ho to sync apne aap start hoga
    if (!svc.isOnline) {
      if (!svc.hasData) {
        _toast(context, 'Internet on karo, pehli baar data download karna hoga');
        return;
      }
      if (svc.status != SyncStatus.completed) {
        _toast(context,
            'Data poora download nahi hua — kuch records miss ho sakte hain');
      }
    }
    svc.setOfflineMode(true);
  }

  @override
  Widget build(BuildContext context) {
    final svc = OfflineSyncService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: svc,
      builder: (context, _) {
        final offline = svc.useOffline;
        final color = offline ? _amber : _green;
        final bg = isDark ? const Color(0xff111827) : Colors.white;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onTap(context, svc, offline),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
            decoration: BoxDecoration(
              color: bg, // solid background
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color, width: 1.3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? .30 : .12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  offline ? Icons.cloud_off_rounded : Icons.wifi_rounded,
                  size: 16,
                  color: color,
                ),
                // const SizedBox(width: 5),
                // Text(
                //   offline ? 'Sync off' : 'sync',
                //   // offline ? 'Offline' : 'Online',
                //   style: TextStyle(
                //     fontSize: 12.5,
                //     fontWeight: FontWeight.w800,
                //     color: color,
                //   ),
                // ),
                const SizedBox(width: 8),
                // Mini switch: track 40x22, knob 16
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    alignment:
                    offline ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}