import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.isUpdateAvailable,
    required this.releaseNotes,
    this.downloadUrl,
    this.fileName,
    this.fileSize,
  });

  final String currentVersion;
  final String latestVersion;
  final bool isUpdateAvailable;
  final String releaseNotes;
  final String? downloadUrl;
  final String? fileName;
  final int? fileSize;
}

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  readyToInstall,
  error,
}

class AppUpdateService {
  const AppUpdateService();

  static const String repoOwner = 'MayureshTardekar';
  static const String repoName = 'FitGo';
  static const String fallbackCurrentVersion = '3.0.4';

  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.isNotEmpty ? info.version : fallbackCurrentVersion;
    } catch (_) {
      return fallbackCurrentVersion;
    }
  }

  Future<AppUpdateInfo> checkForUpdates({http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final currentVersion = await getCurrentVersion();
      final url = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );

      final response = await httpClient.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'FitGo-App',
        },
      );

      if (response.statusCode != 200) {
        return AppUpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          isUpdateAvailable: false,
          releaseNotes: '',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawTag = (data['tag_name'] as String? ?? '').trim();
      final latestVersion = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;
      final releaseNotes = data['body'] as String? ?? '';

      final isNewer = _isVersionNewer(latestVersion, currentVersion);

      String? downloadUrl;
      String? fileName;
      int? fileSize;

      final assets = data['assets'] as List<dynamic>? ?? [];
      // Prefer ARM64 APK for modern Android devices, then universal APK, then any APK
      Map<String, dynamic>? selectedAsset;
      for (final item in assets) {
        final asset = item as Map<String, dynamic>;
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.contains('arm64') && name.endsWith('.apk')) {
          selectedAsset = asset;
          break;
        }
      }

      if (selectedAsset == null) {
        for (final item in assets) {
          final asset = item as Map<String, dynamic>;
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.apk')) {
            selectedAsset = asset;
            break;
          }
        }
      }

      if (selectedAsset != null) {
        downloadUrl = selectedAsset['browser_download_url'] as String?;
        fileName = selectedAsset['name'] as String?;
        fileSize = selectedAsset['size'] as int?;
      }

      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion.isNotEmpty ? latestVersion : currentVersion,
        isUpdateAvailable: isNewer && downloadUrl != null,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSize: fileSize,
      );
    } catch (e) {
      final currentVersion = await getCurrentVersion();
      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        isUpdateAvailable: false,
        releaseNotes: '',
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  Future<File> downloadAndInstallApk({
    required String downloadUrl,
    required String fileName,
    required void Function(double progress, int received, int total) onProgress,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await httpClient.send(request);

      if (response.statusCode != 200) {
        throw HttpException('Download failed with status ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final saveFile = File('${tempDir.path}/$fileName');

      if (await saveFile.exists()) {
        await saveFile.delete();
      }

      final sink = saveFile.openWrite();
      var receivedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes, receivedBytes, totalBytes);
        } else {
          onProgress(0.5, receivedBytes, 0);
        }
      }

      await sink.flush();
      await sink.close();

      // Trigger the Android package installer
      if (!kIsWeb && Platform.isAndroid) {
        await OpenFilex.open(
          saveFile.path,
          type: 'application/vnd.android.package-archive',
        );
      }

      return saveFile;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static bool _isVersionNewer(String latest, String current) {
    try {
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('+')[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (var i = 0; i < 3; i++) {
        final l = i < lParts.length ? lParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
