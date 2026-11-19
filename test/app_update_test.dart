import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fitgo/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS does not contact GitHub for Android APK updates', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });

    final info = await const AppUpdateService().checkForUpdates(client: client);

    expect(requests, 0);
    expect(info.isUpdateAvailable, isFalse);
    expect(info.downloadUrl, isNull);
    expect(info.latestVersion, info.currentVersion);
  });

  test('Android checks the latest release and prefers the arm64 APK', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final client = MockClient((request) async {
      expect(request.url.host, 'api.github.com');
      return http.Response(
        jsonEncode({
          'tag_name': 'v9.9.9',
          'body': 'Release notes',
          'assets': [
            {
              'name': 'app-release.apk',
              'browser_download_url': 'https://example.com/app-release.apk',
              'size': 100,
            },
            {
              'name': 'app-arm64-v8a-release.apk',
              'browser_download_url':
                  'https://example.com/app-arm64-v8a-release.apk',
              'size': 200,
            },
          ],
        }),
        200,
      );
    });

    final info = await const AppUpdateService().checkForUpdates(client: client);

    expect(info.latestVersion, '9.9.9');
    expect(info.isUpdateAvailable, isTrue);
    expect(info.fileName, 'app-arm64-v8a-release.apk');
    expect(info.fileSize, 200);
  });

  test('iOS refuses to download an APK', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await expectLater(
      const AppUpdateService().downloadAndInstallApk(
        downloadUrl: 'https://example.com/app.apk',
        fileName: 'app.apk',
        onProgress: (_, _, _) {},
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
