import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/auth/google_federated_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleFederatedAuthService.ensureFirebaseReady();
  const enableDevicePreview = bool.fromEnvironment(
    'ENABLE_DEVICE_PREVIEW',
    defaultValue: false,
  );

  runApp(
    enableDevicePreview && !kReleaseMode
        ? DevicePreview(
            enabled: true,
            builder: (_) => const ProviderScope(
              child: TheBitAndBondApp(enableDevicePreview: true),
            ),
          )
        : const ProviderScope(child: TheBitAndBondApp()),
  );
}
