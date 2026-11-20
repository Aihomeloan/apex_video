import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// What happened when we asked the server to verify a purchase.
enum VerifyOutcome {
  /// Credits added.
  credited,

  /// Already added earlier — nothing more to do.
  alreadyDone,

  /// Couldn't confirm right now (network etc.). Leave the purchase open so
  /// Apple hands it to us again on the next app launch.
  retryLater,

  /// Permanently unusable — finish it so it stops coming back.
  rejected,
}

/// Consumable credit packs. These exact IDs must exist in App Store
/// Connect (and Play Console, if you ship Android) as Consumable
/// in-app purchases before this will find anything.
class PurchaseService {
  static const credits12 = 'com.goldenapexapps.apexvideo.credits12';
  static const credits36 = 'com.goldenapexapps.apexvideo.credits36';
  static const credits72 = 'com.goldenapexapps.apexvideo.credits72';

  static const productIds = <String>{credits12, credits36, credits72};

  static const Map<String, int> creditsByProduct = {
    credits12: 12,
    credits36: 36,
    credits72: 72,
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// The product currently being bought, or null. The UI uses this to
  /// show a spinner and block double-taps.
  final ValueNotifier<String?> buying = ValueNotifier<String?>(null);

  Future<bool> isAvailable() => _iap.isAvailable();

  /// Returns the packs sorted cheapest first.
  Future<List<ProductDetails>> queryProducts() async {
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      throw Exception('Store query failed: ${response.error!.message}');
    }
    final products = [...response.productDetails];
    products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    return products;
  }

  /// Call once, early (app startup). [onVerify] asks our server to check
  /// the purchase with Apple and add the credits; the purchase is only
  /// finished with Apple once that succeeds (or can never succeed).
  void listenForPurchases({
    required Future<VerifyOutcome> Function(PurchaseDetails purchase) onVerify,
    required void Function(String message) onError,
  }) {
    _subscription?.cancel();
    _subscription = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.pending) continue;

        var finish = true;
        if (purchase.status == PurchaseStatus.error) {
          onError(purchase.error?.message ?? 'Purchase failed.');
        } else if (purchase.status == PurchaseStatus.purchased) {
          final outcome = await onVerify(purchase);
          if (outcome == VerifyOutcome.retryLater) finish = false;
        }
        // restored / canceled: consumables don't restore — nothing to add.

        if (finish && purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }

        if (buying.value == purchase.productID) buying.value = null;
      }
    }, onError: (e) {
      buying.value = null;
      onError(e.toString());
    });
  }

  Future<void> buy(ProductDetails product) async {
    if (buying.value != null) return;
    buying.value = product.id;
    try {
      final started = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) buying.value = null;
    } catch (e) {
      buying.value = null;
      rethrow;
    }
  }

  void dispose() {
    _subscription?.cancel();
    buying.dispose();
  }
}
