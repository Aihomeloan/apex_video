import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Consumable credit packs. These exact IDs must exist in App Store
/// Connect (and Play Console, if you ship Android) as Consumable
/// in-app purchases before this will find anything.
class PurchaseService {
  static const productIds = <String>{
    'com.goldenapexapps.apexvideo.credits10',
    'com.goldenapexapps.apexvideo.credits25',
    'com.goldenapexapps.apexvideo.credits50',
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<List<ProductDetails>> queryProducts() async {
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      throw Exception('Store query failed: ${response.error}');
    }
    return response.productDetails;
  }

  /// Call once, early (e.g. app startup). [onCreditsGranted] fires once
  /// per completed/restored purchase; [onError] fires on failure/cancel.
  void listenForPurchases({
    required void Function(int credits) onCreditsGranted,
    required void Function(String message) onError,
  }) {
    _subscription = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.pending) continue;

        if (purchase.status == PurchaseStatus.error) {
          onError(purchase.error?.message ?? 'Purchase failed.');
        } else if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final credits = _creditsForProduct(purchase.productID);
          if (credits > 0) onCreditsGranted(credits);
        }

        // Required on iOS — an uncompleted transaction stays pending
        // forever and the user can be charged without ever "finishing."
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }, onError: (e) => onError(e.toString()));
  }

  int _creditsForProduct(String productId) {
    if (productId.endsWith('credits10')) return 10;
    if (productId.endsWith('credits25')) return 25;
    if (productId.endsWith('credits50')) return 50;
    return 0;
  }

  Future<void> buy(ProductDetails product) {
    return _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  void dispose() {
    _subscription?.cancel();
  }
}
