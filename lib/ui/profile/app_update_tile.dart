import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_update_provider.dart';
import '../../services/app_update_service.dart';
import '../components/fitgo_list_row.dart';
import '../haptics.dart';
import '../theme/fitgo_tokens.dart';

class AppUpdateTile extends ConsumerStatefulWidget {
  const AppUpdateTile({super.key});

  @override
  ConsumerState<AppUpdateTile> createState() => _AppUpdateTileState();
}

class _AppUpdateTileState extends ConsumerState<AppUpdateTile> {
  @override
  void initState() {
    super.initState();
    // Silently check on profile open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appUpdateNotifierProvider.notifier).checkForUpdates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(appUpdateNotifierProvider);
    final tokens = context.tokens;
    final currentVer = updateState.info?.currentVersion ?? AppUpdateService.fallbackCurrentVersion;

    return FitGoListRow(
      leadingIcon: Icons.info_outline_rounded,
      title: 'App version',
      subtitle: 'v$currentVer (FitGo 3.0)',
      showChevron: false,
      trailing: _buildBadge(context, updateState, tokens),
      onTap: () => _handleTap(context, ref, updateState),
    );
  }

  Widget _buildBadge(BuildContext context, AppUpdateState state, FitGoTokens tokens) {
    switch (state.status) {
      case UpdateStatus.checking:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.ember,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Checking…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    fontSize: 12,
                  ),
            ),
          ],
        );

      case UpdateStatus.available:
        final latest = state.info?.latestVersion ?? '';
        return DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.ember.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.ember.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_circle_up_rounded,
                  size: 15,
                  color: tokens.ember,
                ),
                const SizedBox(width: 4),
                Text(
                  'Update $latest',
                  style: TextStyle(
                    color: tokens.ember,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );

      case UpdateStatus.downloading:
        final percent = (state.progress * 100).toInt();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                strokeWidth: 2,
                color: tokens.ember,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$percent%',
              style: TextStyle(
                color: tokens.ember,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        );

      case UpdateStatus.upToDate:
      default:
        // Mint green badge matching Image 2
        return DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.mint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: tokens.mint,
                ),
                const SizedBox(width: 4),
                Text(
                  'Up to date',
                  style: TextStyle(
                    color: tokens.mint,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  void _handleTap(BuildContext context, WidgetRef ref, AppUpdateState state) {
    FitGoHaptics.select();

    if (state.status == UpdateStatus.available) {
      _showUpdateDialog(context, ref, state);
      return;
    }

    if (state.status == UpdateStatus.checking || state.status == UpdateStatus.downloading) {
      return;
    }

    // Trigger a manual re-check
    ref.read(appUpdateNotifierProvider.notifier).checkForUpdates();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.status == UpdateStatus.upToDate
              ? 'FitGo is up to date (v${state.info?.currentVersion ?? AppUpdateService.fallbackCurrentVersion}).'
              : 'Checking for updates…',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, WidgetRef ref, AppUpdateState state) {
    final info = state.info;
    if (info == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final liveState = ref.watch(appUpdateNotifierProvider);
            final tokens = context.tokens;
            final isDownloading = liveState.status == UpdateStatus.downloading;
            final percent = (liveState.progress * 100).toInt();

            final sizeMb = (info.fileSize != null && info.fileSize! > 0)
                ? '${(info.fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB'
                : '9.8 MB';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.cardRadius),
              ),
              title: const Text('Update FitGo?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A new version of FitGo is available!\n\n'
                    'Version ${info.latestVersion} is now available — you have ${info.currentVersion} ($sizeMb).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (isDownloading) ...[
                    const SizedBox(height: FitGoSpacing.lg),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: liveState.progress > 0 ? liveState.progress : null,
                        color: tokens.ember,
                        backgroundColor: tokens.surfaceMuted,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: FitGoSpacing.xs),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Downloading… $percent%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.ember,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!isDownloading) ...[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'LATER',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.ember,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      ref.read(appUpdateNotifierProvider.notifier).startDownloadAndInstall();
                    },
                    child: const Text('UPDATE NOW'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'CONTINUE IN BACKGROUND',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
