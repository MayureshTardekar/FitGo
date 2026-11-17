import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_update_service.dart';

class AppUpdateState {
  const AppUpdateState({
    this.status = UpdateStatus.idle,
    this.info,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  final UpdateStatus status;
  final AppUpdateInfo? info;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final String? errorMessage;

  AppUpdateState copyWith({
    UpdateStatus? status,
    AppUpdateInfo? info,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    String? errorMessage,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      info: info ?? this.info,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return const AppUpdateService();
});

final appUpdateNotifierProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
  final service = ref.watch(appUpdateServiceProvider);
  return AppUpdateNotifier(service);
});

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  AppUpdateNotifier(this._service) : super(const AppUpdateState());

  final AppUpdateService _service;

  Future<void> checkForUpdates() async {
    state = state.copyWith(status: UpdateStatus.checking, errorMessage: null);
    try {
      final info = await _service.checkForUpdates();
      if (info.isUpdateAvailable) {
        state = state.copyWith(status: UpdateStatus.available, info: info);
      } else {
        state = state.copyWith(status: UpdateStatus.upToDate, info: info);
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> startDownloadAndInstall() async {
    final info = state.info;
    if (info == null || info.downloadUrl == null || info.fileName == null) return;

    state = state.copyWith(
      status: UpdateStatus.downloading,
      progress: 0.0,
      receivedBytes: 0,
      totalBytes: info.fileSize ?? 0,
    );

    try {
      await _service.downloadAndInstallApk(
        downloadUrl: info.downloadUrl!,
        fileName: info.fileName!,
        onProgress: (progress, received, total) {
          state = state.copyWith(
            progress: progress,
            receivedBytes: received,
            totalBytes: total,
          );
        },
      );
      state = state.copyWith(status: UpdateStatus.readyToInstall);
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Download failed: $e',
      );
    }
  }
}
