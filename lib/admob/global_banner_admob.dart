import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:game_timer/admob/ad_unit_id.dart';
import 'package:game_timer/main.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class GlobalBannerAdmob extends StatefulWidget {
  const GlobalBannerAdmob({super.key});

  @override
  State<StatefulWidget> createState() {
    return _GlobalBannerAdmobState();
  }
}

class _GlobalBannerAdmobState extends State<GlobalBannerAdmob> {
  // UserController userController = Get.find<UserController>();
  late BannerAd _bannerAd;
  AdUnitId adUnitId = AdUnitId();
  bool _bannerReady = false;

  @override
  void initState() {
    super.initState();
    // if (!kDebugMode) {
    initAdMob();
    // }
  }

  void initAdMob() {
    String platform = Platform.isIOS ? 'ios' : 'android';
    print('platform : ${platform}');

    _bannerAd = BannerAd(
      adUnitId: adUnitId.banner[platform]!,
      request: const AdRequest(),
      size: AdSize.fullBanner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _bannerReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          setState(() {
            _bannerReady = false;
          });
          ad.dispose();
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    super.dispose();
    _bannerAd?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // if (!kReleaseMode) return Container(height: 0);
    if (_bannerAd == null) {
      return Container(
        height: 60,
        width: double.infinity,
        color: appColor,
        child: const Text(
          'Here is AD',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return _bannerReady
        ? SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          )
        : Container(height: 0);
  }
}

// import 'package:flutter/material.dart';

// class GlobalBannerAdmob extends StatelessWidget {
//   const GlobalBannerAdmob({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Container();
//   }
// }
