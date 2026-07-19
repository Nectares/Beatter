import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../theme/app_colors.dart';

/// A persistent banner advertisement widget that loads and displays an AdMob banner.
/// It uses test ad unit IDs when running in debug mode to comply with AdMob policy,
/// and falls back to production IDs in release builds.
class PersistentBannerAd extends StatefulWidget {
  const PersistentBannerAd({super.key});

  @override
  State<PersistentBannerAd> createState() => _PersistentBannerAdState();
}

class _PersistentBannerAdState extends State<PersistentBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // Determine the Ad Unit ID based on platform and debug mode.
    final String adUnitId;
    if (kDebugMode) {
      adUnitId = defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-3940256099942544/6300978111' // Android Test Banner ID
          : 'ca-app-pub-3940256099942544/2934735716'; // iOS Test Banner ID
    } else {
      adUnitId = defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-3795633055849274/2627829615' // Android Prod Banner ID
          : 'ca-app-pub-3795633055849274/3614176448'; // iOS Prod Banner ID
    }

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      // Don't take up any vertical space while the ad is loading or if it fails.
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          alignment: Alignment.center,
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
