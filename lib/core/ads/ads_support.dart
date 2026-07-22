import 'package:flutter/foundation.dart';

/// Whether Google Mobile Ads (AdMob) is available on the current platform.
///
/// The `google_mobile_ads` plugin only implements Android and iOS; on web —
/// and any other platform — its method channels throw
/// `MissingPluginException`. Gate every AdMob call (SDK init and banner
/// loading) behind this so unsupported platforms silently run ad-free instead
/// of crashing at startup.
bool get adsSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
