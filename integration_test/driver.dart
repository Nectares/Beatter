// Driver that writes the screenshots reported by
// marketing_screenshots_test.dart to marketing/screenshots/native/.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final file = File('marketing/screenshots/native/$name.png')
          ..createSync(recursive: true);
        file.writeAsBytesSync(bytes);
        return true;
      },
    );
