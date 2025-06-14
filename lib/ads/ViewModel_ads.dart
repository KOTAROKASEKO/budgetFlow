import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdViewModel extends ChangeNotifier {
  // 1. 単一の広告オブジェクトから、複数の広告を管理するためのMapに変更
  final Map<String, BannerAd?> _ads = {};
  final Map<String, bool> _adLoadStatus = {};

  // 2. adIdを指定して、特定の広告を取得するGetter
  BannerAd? getAd(String adId) => _ads[adId];

  // 3. adIdを指定して、特定の広告がロード済みか確認するGetter
  bool isAdLoaded(String adId) => _adLoadStatus[adId] ?? false;

  // 4. loadAdメソッドがadIdを受け取るように変更
  void loadAd(String adId) {
    // 既にロード中、またはロード済みの場合は何もしない
    if (_adLoadStatus.containsKey(adId)) {
      return;
    }
    // ロード中としてマーク
    _adLoadStatus[adId] = false;

    final bannerAd = BannerAd(
      // 5. ご提示のgetAdUnit()メソッドをそのまま利用
      adUnitId: getBannerAdUnitId(),
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          print('Ad for $adId loaded.');
          // 特定のadIdのロード状態を更新
          _adLoadStatus[adId] = true;
          notifyListeners();
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('Ad for $adId failed to load: $error');
          ad.dispose();
          // 失敗した場合はMapから削除
          _ads.remove(adId);
          _adLoadStatus.remove(adId);
          notifyListeners();
        },
      ),
    )..load();

    // 生成したバナー広告をMapに保存
    _ads[adId] = bannerAd;
  }

  // このメソッドは変更ありません
  String getBannerAdUnitId() {
    if (kReleaseMode) {
      // あなたのリリース用広告ユニットID
      return 'ca-app-pub-1761598891234951/7527486247';
    } else {
      // テスト用広告ユニットID
      return 'ca-app-pub-3940256099942544/6300978111';
    }
  }

  // 6. disposeメソッドを更新し、全ての広告を破棄するように変更
  @override
  void dispose() {
    for (final ad in _ads.values) {
      ad?.dispose();
    }
    super.dispose();
  }
}